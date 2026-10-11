"""Renders the clouds from a few camera positions (ground, looking up, at the cloud height, above) into one PNG.

Usage: python tools/preview/cloud_preview.py <out.png> [sun_elevation_deg] [rain] [thunder] [worldTime]
The clouds read the game's cloud texture, taken from the Minecraft resources jar ModDevGradle leaves in
build/moddev/artifacts (run a build once). The light colours are computed the way the prepare pass bakes them.
"""
import io
import math
import pathlib
import sys
import zipfile

import moderngl
import numpy as np
from PIL import Image

from glsl import expand

W, H = 640, 360
FRAG = '''
#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/tonemap.glsl"
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
#include "/lib/clouds.glsl"
uniform vec3 previewSun;
uniform float previewPitch;
uniform float previewYaw;
in vec2 uv;
out vec4 fragColor;

vec3 ambientIrradiance(vec3 sunDir) {
    vec3 sum = vec3(0.0); float weight = 0.0;
    for (int r = 0; r < 3; r++) {
        float y = (float(r) + 0.5) / 3.0; float horizontal = sqrt(1.0 - y * y);
        for (int s = 0; s < 6; s++) {
            float a = (float(s) + 0.5 * float(r)) / 6.0 * 2.0 * PI;
            sum += skyRadiance(vec3(cos(a) * horizontal, y, sin(a) * horizontal), sunDir, 6) * y; weight += y;
        }
    }
    vec3 sky = sum / weight * PI * 1.4;
    return mix(vec3(luminance(sky)), sky, 0.7);
}

void main() {
    vec2 ndc = uv * 2.0 - 1.0;
    float fov = tan(radians(35.0));
    vec3 forward = normalize(vec3(sin(previewYaw) * cos(previewPitch), sin(previewPitch), cos(previewYaw) * cos(previewPitch)));
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    vec3 dir = normalize(forward + ndc.x * fov * (16.0 / 9.0) * right + ndc.y * fov * up);

    vec3 sunDir = previewSun;
    vec3 direct = SUN_ILLUMINANCE * sunTint(directTransmittance(sunDir.y), sunDir.y) * aboveHorizon(sunDir.y)
            * (1.0 - rainStrength * 0.88) * (1.0 - thunderStrength * 0.9);
    vec3 ambient = ambientIrradiance(sunDir);
    vec3 sunDisc = SUN_ILLUMINANCE * sunTint(directTransmittance(sunDir.y), sunDir.y) * (1.0 - rainStrength) * (1.0 - thunderStrength);

    vec3 sky = skyRadiance(vec3(dir.x, max(dir.y, 0.0), dir.z), sunDir, 8);
    float a = acos(clamp(dot(dir, sunDir), -1.0, 1.0));
    vec3 color = sky + sunDisc * (0.12 * exp(-a / 0.05) + 0.02 * exp(-a / 0.3)) + sunDisc * 1.1 * step(a, 0.0375);
    float maxDist = 1e6;
    if (dir.y < 0.0 && cameraPosition.y > 64.0) {
        // Grass plain at y 64, lit like a top face, with the cloud shadows.
        float t = (64.0 - cameraPosition.y) / dir.y;
        vec3 p = dir * t;
        vec3 albedo = vec3(0.12, 0.2, 0.06);
        vec3 lit = albedo * (ambient / PI + direct / PI * max(sunDir.y, 0.0) * cloudShadow(p, sunDir));
        float fog = 1.0 - exp(-t * (0.00035 + rainStrength * 0.0045));
        color = mix(lit, sky, fog);
        maxDist = t;
    }
    vec4 c = cloudLayers(dir, maxDist, sunDir, direct, ambient, sky, 14);
    color = color * c.a + c.rgb;

    float key = (luminance(direct) * 0.6 + luminance(ambient)) / PI;
    float target = 1.75 * mix(1.0, 0.62, rainStrength) * mix(1.0, 0.75, thunderStrength) * (1.0 - 0.45 * twilightAmount(sunDir.y));
    color *= clamp(pow(target / max(key, 1e-3), 0.5), 0.9, 3.2);
    fragColor = vec4(tonemap(color), 1.0);
}
'''
VERT = 'in vec2 pos; out vec2 uv; void main() { uv = pos * 0.5 + 0.5; gl_Position = vec4(pos, 0.0, 1.0); }'

VIEWS = [  # camera height, pitch (deg), yaw (deg; 0 = +z, the sun is towards +z)
    (80.0, 12.0, 0.0),
    (80.0, 12.0, 180.0),
    (80.0, 55.0, 90.0),
    (194.0, 0.0, 60.0),
    (260.0, -20.0, 30.0),
    (80.0, 3.0, 90.0),
]


def cloud_texture():
    root = pathlib.Path(__file__).resolve().parents[2]
    jars = sorted((root / 'build' / 'moddev' / 'artifacts').glob('*minecraft-resources.jar'))
    if not jars:
        raise SystemExit('Minecraft resources jar not found in build/moddev/artifacts - run a build first')
    with zipfile.ZipFile(jars[-1]) as z:
        return Image.open(io.BytesIO(z.read('assets/minecraft/textures/environment/clouds.png'))).convert('RGBA')


def main():
    out = sys.argv[1]
    elevation = math.radians(float(sys.argv[2]) if len(sys.argv) > 2 else 35.0)
    rain = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
    thunder = float(sys.argv[4]) if len(sys.argv) > 4 else 0.0
    world_time = int(sys.argv[5]) if len(sys.argv) > 5 else 12500
    ctx = moderngl.create_standalone_context()
    prog = ctx.program(vertex_shader='#version 330 compatibility\n' + VERT,
                       fragment_shader='#version 330 compatibility\n' + expand(FRAG))
    img = cloud_texture()
    tex = ctx.texture(img.size, 4, img.tobytes())
    tex.filter = (moderngl.NEAREST, moderngl.NEAREST)
    tex.use(0)
    prog['cloudtex'].value = 0
    sun = (0.35, math.sin(elevation), math.cos(elevation))
    n = math.sqrt(sum(x * x for x in sun))
    prog['previewSun'].value = tuple(x / n for x in sun)
    # sunDirection() = gbufferModelViewInverse x sunPosition: identity matrix, sun position along the preview sun.
    if 'sunPosition' in prog:
        prog['sunPosition'].value = tuple(100.0 * x / n for x in sun)
    if 'gbufferModelViewInverse' in prog:
        prog['gbufferModelViewInverse'].value = (1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0)
    if 'worldTime' in prog:
        prog['worldTime'].value = world_time
    for name, value in (('rainStrength', rain), ('thunderStrength', thunder), ('viewWidth', W), ('viewHeight', H),
                        ('frameTimeCounter', 100.0)):
        if name in prog:
            prog[name].value = value
    quad = ctx.buffer(np.array([-1, -1, 1, -1, -1, 1, 1, 1], dtype='f4').tobytes())
    vao = ctx.vertex_array(prog, [(quad, '2f', 'pos')])
    fbo = ctx.simple_framebuffer((W, H))
    sheet = Image.new('RGB', (W * 2, H * ((len(VIEWS) + 1) // 2)))
    for i, (height, pitch, yaw) in enumerate(VIEWS):
        prog['cameraPosition'].value = (0.0, height, 0.0)
        prog['previewPitch'].value = math.radians(pitch)
        prog['previewYaw'].value = math.radians(yaw)
        fbo.use()
        fbo.clear()
        vao.render(moderngl.TRIANGLE_STRIP)
        frame = Image.frombytes('RGB', (W, H), fbo.read(components=3)).transpose(Image.FLIP_TOP_BOTTOM)
        sheet.paste(frame, ((i % 2) * W, (i // 2) * H))
    sheet.save(out)
    print('saved', out)


if __name__ == '__main__':
    main()

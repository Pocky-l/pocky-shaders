"""Renders the volumetric clouds from a few camera positions (ground, under the base, inside, above) into one PNG.

Usage: python tools/preview/cloud_preview.py <out.png> [sun_elevation_deg] [rain]
"""
import math
import sys

import moderngl
import numpy as np
from PIL import Image

from glsl import expand

W, H = 640, 360
FRAG = '''
#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/tonemap.glsl"
#define CLOUD_LOOKUP
#define CLOUD_MAP_DIRECT
uniform sampler2D colortex7;
#include "/lib/clouds.glsl"
uniform vec3 previewSun;
uniform vec3 previewDirect;
uniform vec3 previewAmbient;
uniform float previewPitch;
in vec2 uv;
out vec4 fragColor;
void main() {
    vec2 ndc = uv * 2.0 - 1.0;
    float fov = tan(radians(35.0));
    vec3 forward = normalize(vec3(0.0, sin(previewPitch), cos(previewPitch)));
    vec3 right = vec3(1.0, 0.0, 0.0);
    vec3 up = normalize(cross(forward, right));
    vec3 dir = normalize(forward + ndc.x * fov * (16.0 / 9.0) * right + ndc.y * fov * up);
    vec3 sky = skyRadiance(dir, previewSun, 8);
    if (dir.y < 0.0 && cameraPosition.y < 150.0) sky = vec3(0.05, 0.07, 0.04);
    float noise = hash12(gl_FragCoord.xy);
    vec4 c = cloudLayers(dir, 1e6, previewSun, previewDirect, previewAmbient, 14, noise);
    vec3 color = sky * c.a + c.rgb;
    fragColor = vec4(tonemap(color), 1.0);
}
'''
VERT = 'in vec2 pos; out vec2 uv; void main() { uv = pos * 0.5 + 0.5; gl_Position = vec4(pos, 0.0, 1.0); }'

VIEWS = [  # camera height, pitch (deg)
    (80.0, 12.0),
    (80.0, 45.0),
    (175.0, 10.0),
    (300.0, 0.0),
    (520.0, -25.0),
    (80.0, 3.0),
]


def main():
    out = sys.argv[1]
    elevation = math.radians(float(sys.argv[2]) if len(sys.argv) > 2 else 35.0)
    rain = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
    ctx = moderngl.create_standalone_context()
    prog = ctx.program(vertex_shader='#version 330 compatibility\n' + VERT,
                       fragment_shader='#version 330 compatibility\n' + expand(FRAG))
    sun = (0.35, math.sin(elevation), math.cos(elevation))
    n = math.sqrt(sum(x * x for x in sun))
    sun = tuple(x / n for x in sun)
    prog['previewSun'].value = sun
    prog['previewDirect'].value = (8.6, 7.3, 5.7)
    prog['previewAmbient'].value = (0.8, 1.15, 1.75)
    for name, value in (('rainStrength', rain), ('viewWidth', W), ('viewHeight', H), ('frameTimeCounter', 100.0)):
        if name in prog:
            prog[name].value = value
    quad = ctx.buffer(np.array([-1, -1, 1, -1, -1, 1, 1, 1], dtype='f4').tobytes())
    vao = ctx.vertex_array(prog, [(quad, '2f', 'pos')])
    fbo = ctx.simple_framebuffer((W, H))
    sheet = Image.new('RGB', (W * 2, H * ((len(VIEWS) + 1) // 2)))
    for i, (height, pitch) in enumerate(VIEWS):
        prog['cameraPosition'].value = (0.0, height, 0.0)
        prog['previewPitch'].value = math.radians(pitch)
        fbo.use()
        fbo.clear()
        vao.render(moderngl.TRIANGLE_STRIP)
        img = Image.frombytes('RGB', (W, H), fbo.read(components=3)).transpose(Image.FLIP_TOP_BOTTOM)
        sheet.paste(img, ((i % 2) * W, (i // 2) * H))
    sheet.save(out)
    print('saved', out)


if __name__ == '__main__':
    main()

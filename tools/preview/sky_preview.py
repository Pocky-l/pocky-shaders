"""Renders the pack's sky model for several sun elevations into one PNG (equirectangular strips, tonemapped).

Usage: python tools/preview/sky_preview.py <out.png> [rain]
"""
import math
import sys

import moderngl
import numpy as np
from PIL import Image

from glsl import expand

W, H = 720, 160
FRAG = '''
#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/tonemap.glsl"
uniform vec3 previewSun;
uniform float previewExposure;
in vec2 uv;
out vec4 fragColor;
void main() {
    float az = (uv.x - 0.5) * 2.0 * PI;
    float el = (uv.y * 1.1 - 0.1) * 0.5 * PI;
    vec3 dir = vec3(sin(az) * cos(el), sin(el), cos(az) * cos(el));
    vec3 sky = skyRadiance(dir, previewSun, SKY_STEPS);
    if (dot(dir, previewSun) > 0.9997) sky += vec3(40.0) * directTransmittance(previewSun.y);
    if (el < 0.0) sky = vec3(0.05, 0.045, 0.04) * (1.0 + 0.0 * sky);
    fragColor = vec4(tonemap(sky * previewExposure), 1.0);
}
'''
VERT = '''
in vec2 pos; out vec2 uv;
void main() { uv = pos * 0.5 + 0.5; gl_Position = vec4(pos, 0.0, 1.0); }
'''


def main():
    out = sys.argv[1]
    rain = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0
    ctx = moderngl.create_standalone_context()
    prog = ctx.program(vertex_shader='#version 330 compatibility\n' + VERT,
                       fragment_shader='#version 330 compatibility\n' + expand(FRAG))
    for name, value in (('rainStrength', rain), ('viewWidth', W), ('viewHeight', H)):
        if name in prog:
            prog[name].value = value
    quad = ctx.buffer(np.array([-1, -1, 1, -1, -1, 1, 1, 1], dtype='f4').tobytes())
    vao = ctx.vertex_array(prog, [(quad, '2f', 'pos')])
    fbo = ctx.simple_framebuffer((W, H))
    rows = []
    for deg in (-8, -3, 1, 4, 10, 25, 60):
        e = math.radians(deg)
        sun = (0.0, math.sin(e), math.cos(e))
        prog['previewSun'].value = sun
        prog['previewExposure'].value = 1.0
        fbo.use()
        fbo.clear()
        vao.render(moderngl.TRIANGLE_STRIP)
        img = Image.frombytes('RGB', (W, H), fbo.read(components=3)).transpose(Image.FLIP_TOP_BOTTOM)
        rows.append(img)
    sheet = Image.new('RGB', (W, H * len(rows)))
    for i, img in enumerate(rows):
        sheet.paste(img, (0, i * H))
    sheet.save(out)
    print('saved', out)


if __name__ == '__main__':
    main()

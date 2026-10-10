"""Prints the prepare pass' light colours (direct, ambient, zenith sky) for several sun elevations.

Usage: python tools/preview/light_values.py [rain] [thunder] [snow]
Also prints the horizon sky, and "seen" = key x the exposure composite1 applies (how bright the scene looks).
"""
import math
import sys

import moderngl
import numpy as np

from glsl import expand

FRAG = '''
#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
uniform vec3 previewSun;
out vec4 fragColor;
vec3 ambientIrradiance(vec3 sunDir) {
    vec3 sum = vec3(0.0); float weight = 0.0;
    for (int r = 0; r < 3; r++) {
        float y = (float(r) + 0.5) / 3.0; float horizontal = sqrt(1.0 - y * y);
        for (int s = 0; s < 6; s++) {
            float a = (float(s) + 0.5 * float(r)) / 6.0 * 2.0 * PI;
            vec3 dir = vec3(cos(a) * horizontal, y, sin(a) * horizontal);
            sum += skyRadiance(dir, sunDir, 6) * y; weight += y;
        }
    }
    return sum / weight * PI * 1.4;
}
void main() {
    int x = int(gl_FragCoord.x);
    vec3 v;
    if (x == 0) v = (SUN_ILLUMINANCE * adaptedTint(directTransmittance(previewSun.y)) * aboveHorizon(previewSun.y)
            + MOON_ILLUMINANCE * MOON_TINT * directTransmittance(-previewSun.y) * aboveHorizon(-previewSun.y))
            * (1.0 - rainStrength * 0.88) * (1.0 - thunderStrength * 0.9);
    else if (x == 1) { v = ambientIrradiance(previewSun); v = mix(vec3(luminance(v)), v, 0.7); }
    else if (x == 2) v = skyRadiance(vec3(0.0, 1.0, 0.0), previewSun, 12);
    else v = skyRadiance(normalize(vec3(1.0, 0.04, 0.0)), previewSun, 12);
    fragColor = vec4(v, 1.0);
}
'''
VERT = 'in vec2 pos; void main() { gl_Position = vec4(pos, 0.0, 1.0); }'


def main():
    rain = float(sys.argv[1]) if len(sys.argv) > 1 else 0.0
    thunder = float(sys.argv[2]) if len(sys.argv) > 2 else 0.0
    snow = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
    ctx = moderngl.create_standalone_context()
    prog = ctx.program(vertex_shader='#version 330 compatibility\n' + VERT,
                       fragment_shader='#version 330 compatibility\n' + expand(FRAG))
    if 'rainStrength' in prog:
        prog['rainStrength'].value = rain
    if 'thunderStrength' in prog:
        prog['thunderStrength'].value = thunder
    if 'snowWeather' in prog:
        prog['snowWeather'].value = snow
    quad = ctx.buffer(np.array([-1, -1, 1, -1, -1, 1, 1, 1], dtype='f4').tobytes())
    vao = ctx.vertex_array(prog, [(quad, '2f', 'pos')])
    tex = ctx.texture((4, 1), 4, dtype='f4')
    fbo = ctx.framebuffer([tex])
    lum = lambda c: 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
    for deg in (-30, -10, -4, 0, 3, 8, 15, 30, 60, 85):
        e = math.radians(deg)
        prog['previewSun'].value = (0.0, math.sin(e), math.cos(e))
        fbo.use()
        vao.render(moderngl.TRIANGLE_STRIP)
        d = np.frombuffer(tex.read(), dtype='f4').reshape(4, 4)
        key = (lum(d[0]) * 0.6 + lum(d[1])) / math.pi
        target = 1.75 * (1.0 - 0.38 * rain * (1.0 - 0.7 * snow)) * (1.0 - 0.5 * thunder * (1.0 - snow))
        seen = key * min(max(math.sqrt(target / max(key, 1e-3)), 0.9), 3.2)
        print(f'sun {deg:4d}: direct {np.round(d[0][:3], 3)} ambient {np.round(d[1][:3], 3)} '
              f'zenith {np.round(d[2][:3], 3)} horizon {np.round(d[3][:3], 3)} key {key:.4f} seen {seen:.3f}')


if __name__ == '__main__':
    main()

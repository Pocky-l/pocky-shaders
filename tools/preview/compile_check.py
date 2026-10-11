"""Compiles and links every program stub of the bundled pack the way Iris would see it, for each dimension and a set
of option combinations (quality presets, features off, with and without Distant Horizons).

Usage: python tools/preview/compile_check.py [path/to/glslang.exe]
With glslang (the Khronos reference compiler) every variant is also checked strictly, catching what lenient drivers
accept but others reject.
"""
import pathlib
import re
import subprocess
import sys
import tempfile

import moderngl

from glsl import SHADERS, INCLUDE

# Macros and built-ins Iris provides that a plain GL driver does not know.
IRIS_PRELUDE = '''
#define MC_VERSION 12101
#define MC_RENDER_STAGE_NONE 0
#define MC_RENDER_STAGE_SKY 1
#define MC_RENDER_STAGE_SUNSET 2
#define MC_RENDER_STAGE_CUSTOM_SKY 3
#define MC_RENDER_STAGE_SUN 4
#define MC_RENDER_STAGE_MOON 5
#define MC_RENDER_STAGE_STARS 6
#define MC_RENDER_STAGE_VOID 7
#define DH_BLOCK_UNKNOWN 0
#define DH_BLOCK_LEAVES 1
#define DH_BLOCK_STONE 2
#define DH_BLOCK_WOOD 3
#define DH_BLOCK_METAL 4
#define DH_BLOCK_DIRT 5
#define DH_BLOCK_LAVA 6
#define DH_BLOCK_DEEPSLATE 7
#define DH_BLOCK_SNOW 8
#define DH_BLOCK_SAND 9
#define DH_BLOCK_TERRACOTTA 10
#define DH_BLOCK_NETHER_STONE 11
#define DH_BLOCK_WATER 12
#define DH_BLOCK_GRASS 13
#define DH_BLOCK_AIR 14
#define DH_BLOCK_ILLUMINATED 15
'''

VARIANTS = [
    {},
    {'QUALITY': '0'},
    {'QUALITY': '2'},
    {'QUALITY': '3'},
    {'QUALITY': '3', 'DISTANT_HORIZONS': True},
    {'SHADOW_STYLE': '0'},
    {'SHADOW_STYLE': '0', 'COLORED_SHADOWS': False, 'QUALITY': '0'},
    {'COLORED_SHADOWS': False},
    {'SHADOWS': False, 'SSAO': False, 'CLOUDS': '0', 'WATER_REFLECTIONS': '0', 'BLOOM': False, 'FXAA': False,
     'LIGHT_SHAFTS': False, 'WAVING_PLANTS': False, 'WAVING_LEAVES': False, 'WET_SURFACES': False,
     'COLORED_SHADOWS': False, 'WATER_REFRACTION': False, 'VALLEY_MIST': False, 'HANDHELD_LIGHT': False,
     'FOLIAGE_TRANSLUCENCY': False, 'WATER_CAUSTICS': False, 'WATER_FOAM': False,
     'FAR_HAZE': '0.0', 'LOW_HAZE': '0.0', 'MOD_WEATHER': False, 'RAINBOWS': False, 'SNOW_SPARKLE': False,
     'WEATHER_GRADING': False},
    {'CLOUDS': '1', 'WATER_REFLECTIONS': '1', 'DISTANT_HORIZONS': True},
    {'DEBUG_VIEW': '1', 'DISTANT_HORIZONS': True},
    {'DEBUG_VIEW': '1'},
]


def settings_with(options):
    text = (SHADERS / 'settings.glsl').read_text(encoding='utf-8')
    for name, value in options.items():
        if name == 'DISTANT_HORIZONS':
            continue
        if value is False:
            text, n = re.subn(rf'^#define {name}\b', f'//#define {name}', text, flags=re.M)
        else:
            text, n = re.subn(rf'^#define {name} \S+', f'#define {name} {value}', text, flags=re.M)
        if n == 0:
            raise SystemExit(f'option {name} not found in settings.glsl')
    return text


def expand(path, settings, seen):
    out = []
    for line in path.read_text(encoding='utf-8').splitlines():
        m = INCLUDE.match(line)
        if not m:
            out.append(line)
            continue
        name = m.group(1)
        target = (SHADERS / name.lstrip('/')) if name.startswith('/') else (path.parent / name)
        target = target.resolve()
        if target in seen:
            continue
        seen.add(target)
        if target.name == 'settings.glsl':
            out.append(settings)
        else:
            out.append(expand(target, settings, seen))
    return '\n'.join(out)


def source(stub, settings, options, stage):
    text = expand(stub, settings, set())
    lines = text.split('\n')
    version, rest = lines[0], lines[1:]
    extra = IRIS_PRELUDE
    if options.get('DISTANT_HORIZONS'):
        extra += '#define DISTANT_HORIZONS\n'
    if stub.name.startswith('dh_') and stage == 'vertex':
        extra += 'const int dhMaterialId = 0;\n'
    return version + '\n' + extra + '\n'.join(rest)


def strict_errors(glslang, text, stage):
    with tempfile.TemporaryDirectory() as tmp:
        path = pathlib.Path(tmp) / ('shader.vert' if stage == 'vertex' else 'shader.frag')
        path.write_text(text, encoding='utf-8')
        result = subprocess.run([glslang, str(path)], capture_output=True, text=True)
        if result.returncode != 0:
            return result.stdout + result.stderr
    return None


def main():
    glslang = sys.argv[1] if len(sys.argv) > 1 else None
    ctx = moderngl.create_standalone_context()
    failures = 0
    checked = 0
    for folder in ('world0', 'world-1', 'world1'):
        for vsh in sorted((SHADERS / folder).glob('*.vsh')):
            fsh = vsh.with_suffix('.fsh')
            for options in VARIANTS:
                settings = settings_with(options)
                vs = source(vsh, settings, options, 'vertex')
                fs = source(fsh, settings, options, 'fragment')
                if glslang:
                    errors = strict_errors(glslang, vs, 'vertex') or strict_errors(glslang, fs, 'fragment')
                    if errors:
                        failures += 1
                        print(f'STRICT FAIL {folder}/{vsh.stem} {options}')
                        print(errors)
                        break
                try:
                    ctx.program(vertex_shader=vs, fragment_shader=fs)
                    checked += 1
                except moderngl.Error as e:
                    failures += 1
                    print(f'FAIL {folder}/{vsh.stem} {options}\n{e}\n')
                    break
    print(f'{checked} program variants compiled, {failures} failures')
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()

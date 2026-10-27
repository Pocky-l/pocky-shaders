"""Generates the per-dimension program stubs (shaders/world0, world-1, world1) of the bundled shader pack.

Each stub only sets the GLSL version, the dimension and program defines and includes the real source from
shaders/program. Run after adding or renaming a program: python tools/gen_stubs.py
"""
import pathlib
import shutil

SHADERS = pathlib.Path(__file__).resolve().parents[1] / 'shaders'
VERSION = '#version 330 compatibility'

LIT = ('gbuffers_lit.vsh', 'gbuffers_lit.fsh')
UNLIT = ('gbuffers_unlit.vsh', 'gbuffers_unlit.fsh')
FULLSCREEN = 'fullscreen.vsh'

# program name -> (vertex source, fragment source, defines, overworld only)
PROGRAMS = {
    'prepare': (FULLSCREEN, 'prepare.fsh', [], True),
    'shadow': ('shadow.vsh', 'shadow.fsh', [], True),
    'gbuffers_basic': (*UNLIT, ['PROG_BASIC'], False),
    'gbuffers_skybasic': (*UNLIT, ['PROG_SKYBASIC'], False),
    'gbuffers_skytextured': (*UNLIT, ['PROG_SKYTEXTURED'], False),
    'gbuffers_clouds': (*UNLIT, ['PROG_CLOUDS'], False),
    'gbuffers_spidereyes': (*UNLIT, ['PROG_EMISSIVE'], False),
    'gbuffers_beaconbeam': (*UNLIT, ['PROG_EMISSIVE'], False),
    'gbuffers_armor_glint': (*UNLIT, ['PROG_GLINT'], False),
    'gbuffers_damagedblock': (*UNLIT, ['PROG_DAMAGE'], False),
    'gbuffers_weather': (*UNLIT, ['PROG_WEATHER'], False),
    'gbuffers_terrain': (*LIT, ['PROG_TERRAIN'], False),
    'gbuffers_entities': (*LIT, ['PROG_ENTITIES'], False),
    'gbuffers_block': (*LIT, ['PROG_BLOCK'], False),
    'gbuffers_hand': (*LIT, ['PROG_HAND'], False),
    'gbuffers_hand_water': (*LIT, ['PROG_HAND'], False),
    'gbuffers_textured': (*LIT, ['PROG_TEXTURED'], False),
    'gbuffers_textured_lit': (*LIT, ['PROG_TEXTURED'], False),
    'gbuffers_water': ('gbuffers_water.vsh', 'gbuffers_water.fsh', [], False),
    'deferred': (FULLSCREEN, 'deferred.fsh', [], False),
    'deferred1': (FULLSCREEN, 'deferred1.fsh', [], False),
    'composite': (FULLSCREEN, 'composite.fsh', [], False),
    'composite1': (FULLSCREEN, 'composite1.fsh', [], False),
    'final': (FULLSCREEN, 'final.fsh', [], False),
    'dh_terrain': ('dh_terrain.vsh', 'dh_terrain.fsh', [], False),
    'dh_water': ('dh_terrain.vsh', 'dh_terrain.fsh', ['PROG_DH_WATER'], False),
    'dh_shadow': ('dh_shadow.vsh', 'dh_shadow.fsh', [], True),
    # Colorwheel (Flywheel instances: Create contraptions, ...); the other clrwl_gbuffers_* programs fall back to it.
    'clrwl_gbuffers': (*LIT, ['PROG_COLORWHEEL'], False),
    'clrwl_shadow': ('shadow.vsh', 'shadow.fsh', ['PROG_COLORWHEEL'], True),
}

DIMENSIONS = {'world0': 'DIM_OVERWORLD', 'world-1': 'DIM_NETHER', 'world1': 'DIM_END'}


def stub(dimension, defines, source):
    lines = [VERSION, f'#define {dimension}'] + [f'#define {d}' for d in defines]
    lines.append(f'#include "/program/{source}"')
    return '\n'.join(lines) + '\n'


def main():
    for folder, dimension in DIMENSIONS.items():
        target = SHADERS / folder
        if target.exists():
            shutil.rmtree(target)
        target.mkdir()
        for name, (vsh, fsh, defines, overworld_only) in PROGRAMS.items():
            if overworld_only and dimension != 'DIM_OVERWORLD':
                continue
            (target / f'{name}.vsh').write_text(stub(dimension, defines, vsh), encoding='utf-8', newline='\n')
            (target / f'{name}.fsh').write_text(stub(dimension, defines, fsh), encoding='utf-8', newline='\n')
    print('stubs written to', SHADERS)


if __name__ == '__main__':
    main()

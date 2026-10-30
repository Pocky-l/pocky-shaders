# Changelog

All notable changes to this shader pack are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.1.0] - 2026-10-30
### Added
- Block materials: blocks take the light by the relief of their own texture, texel by texel, so stone, dirt, wood and
  bricks look rough and grainy instead of smooth and flat. Metals (iron, gold, copper, netherite) shine and mirror the
  sky in their own colour; polished stone, quartz, concrete, glazed terracotta and gems catch the sun and reflect the
  world around them; dirt, sand, gravel, snow and wool stay fully matte. New options: Texture Relief (with depth) and
  Glossy Reflections.
- Under water, columns of sunlight come down from the waves (option Volumetric Light, with strength; off on Low).
- Under water: moving caustics on the bottom and the walls around you, the view sways gently with the water (option
  Underwater Sway), the water is a deep blue that is brighter towards the surface and darker the deeper you dive.
### Changed
- Torches, lanterns and other lights reach further, like vanilla's: in a cave a torch lit only the blocks right around
  it.
- Blocks keep their form at noon: the sunlit sides of a block are clearly darker than its top again, like in vanilla
  (they were almost as bright, which made blocks look flat and plastic). Shade stays as soft as before.
- Nights are darker and calmer: a deep blue night sky instead of a light grey one, dim moonlit clouds, and torches
  that stand out.
- The Nether has vanilla's thick haze again (with lava still glowing through it) and is no longer a near-black maze;
  the End is lit about as brightly as in vanilla.
- Shallow water keeps vanilla's blue instead of turning into a milky white pane over sand; caustics are softer and
  only under the sun.
- No haze by default: the mist banks over low land, the morning mist in the valleys, the dawn haze and the distant
  veil are off (options Morning Mist, Ground Mist and Distant Haze bring them back). Rain, snow, the Nether and the
  edge of the world keep their fog. The daytime sky is a little bluer.
### Fixed
- Blizzards, snowy-biome weather and swamp mist never switched on: the two weather values the pack reads from the
  game were written in a form Iris ignored.

## [2.0.3] - 2026-10-30
### Fixed
- Black blocks over the screen on Minecraft 26.1.2 with [Rustling Leaves](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves)
  (and any other mod that draws blocks outside the world's chunks): Iris for 26.1.2 hands such geometry an undefined
  block-centre value, which the pack now ignores.

## [2.0.2] - 2026-10-27
### Fixed
- Machines and other blocks of mods that give a little light no longer glow all over at night: a faint light glows
  faintly, and in a modded light source only the parts that outshine the rest of its texture glow (its crystal, not
  its brass). Known light blocks glow as before.

## [2.0.1] - 2026-10-27
### Fixed
- The game crashed a few seconds after entering a world on Minecraft 1.21.5 and newer (26.x included). From 1.21.5 on
  the clouds keep their vanilla look with a cloud pattern of the pack's own instead of the game's cloud texture, and
  the weather of [Petrichor](https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms),
  [Hoarfrost](https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards) and
  [Rustling Leaves](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves) is read only on the versions those
  mods exist for.

## [2.0.0] - 2026-10-27
### Changed
- Pocky Shaders is now a plain shader pack for [Iris](https://www.curseforge.com/minecraft/mc-mods/irisshaders) instead
  of a mod: put the zip into `shaderpacks` and pick it in *Video Settings > Shader Packs*. Coming from the mod, remove
  `pocky_shaders-*.jar` from `mods`; the `shaderpacks/Pocky Shaders` folder it installed can be deleted.
- The weather of [Petrichor](https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms) (1.7.0 or newer),
  [Hoarfrost](https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards) (1.4.0 or newer) and
  [Rustling Leaves](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves) (2.6.0 or newer) now comes from those
  mods themselves, so the pack shows their rain, snow and wind without any other mod. Their winds blend smoothly when
  the weather changes, whichever of them are installed.
- Leaves, flowers, saplings and crops of other mods sway like vanilla ones through the game's block tags.
- Runs on every Minecraft version from 1.20.1 to 26.3 with Iris, and with
  [Oculus](https://www.curseforge.com/minecraft/mc-mods/oculus) on Forge 1.20.1. The plants, leaves and lamps of each
  version are known by name (pale oak, eyeblossoms, dry grass, firefly bushes, copper lanterns and torches, poplars),
  so they sway and glow everywhere; where Iris or Oculus cannot read block tags, the pack leaves them out.

### Fixed
- Cave vines and pale hanging moss sway from where they hang; they did not move at all before.

### Removed
- What only a mod could do: the `F6` key and the `/shaders` command (Iris' own `K` key toggles the shaders, presets are
  on the Profile button of the shader pack settings), automatic preset selection, the performance overlay and the
  benchmark.

## [1.1.0] - 2026-10-13
### Added
- `/shaders preset auto` finds the best preset for your computer: it tries Ultra, then High, Medium and Low, a few
  seconds each, and keeps the first one that runs smoothly (the graphics card has room to spare at about 90 FPS).
  VSync and the frame rate limit are lifted while it measures and put back afterwards. `/shaders preset auto stop`
  cancels it and puts your settings back.
- [Colorwheel](https://www.curseforge.com/minecraft/mc-mods/colorwheel) support: with
  [Create](https://www.curseforge.com/minecraft/mc-mods/create) and other mods that draw through Flywheel,
  contraptions, water wheels, cogs, belts and trains get the pack's sunlight, sky light, torch light and shadows, cast
  shadows themselves and keep Flywheel's speed. Translucent parts such as train windows blend correctly.

## [1.0.0] - 2026-10-12
### Added
- A cosy, natural shader pack for [Iris](https://www.curseforge.com/minecraft/mc-mods/irisshaders), bundled in the mod:
  a physically based sky with rich sunrises and sunsets, soft coloured shadows with crisp pixel edges, colours close to
  vanilla at noon, vanilla-shaped 3D clouds with cloud shadows, light shafts, bloom and a lens flare.
- Living water: refraction, reflections, sun glitter, caustics, shore foam, foaming waterfalls, rain rings and lamp
  light glowing in the water.
- Waving grass and leaves with light shining through them; warm flickering block light and hot glowing lava.
- Weather: grey overcast rain, dark thunderstorms with lightning lighting the clouds, bright blizzards, wet ground,
  rainbows, mist in valleys and swamps, a morning haze.
- Support for [Distant Horizons](https://www.curseforge.com/minecraft/mc-mods/distant-horizons): distant land and water
  shaded, shadowed and fogged like the near world.
- The mod installs the pack into `shaderpacks` and turns it on, and adds the leaves, plants and lamps of every installed
  mod to the pack so they wave and glow.
- Live weather from [Petrichor](https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms),
  [Hoarfrost](https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards) and
  [Rustling Leaves](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves): rain types, wind, lightning, rainbows,
  blizzards and gusts.
- Quality presets Low, Medium, High and Ultra; `F6` toggles the shaders, a key and `/shaders preset` switch the preset;
  `/shaders perf` shows a performance overlay and `/shaders bench` measures what every effect costs.

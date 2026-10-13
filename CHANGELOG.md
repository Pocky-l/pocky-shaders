# Changelog

All notable changes to this mod are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - Unreleased
### Added
- `/shaders preset auto` finds the best preset for your computer: it tries Ultra, then High, Medium and Low, a few
  seconds each, and keeps the first one that runs smoothly (the graphics card has room to spare at about 90 FPS).
  VSync and the frame rate limit are lifted while it measures and put back afterwards. `/shaders preset auto stop`
  cancels it and puts your settings back.

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

<p align="center">
  <img src="src/main/resources/logo.png" alt="Pocky Shaders" width="160">
</p>

<h1 align="center">Pocky Shaders</h1>

<p align="center">
  <b>A cosy, natural shader pack that sets itself up</b> - soft shadows, living water and foliage, juicy sunrises and weather you can feel, while the game still looks like Minecraft. Quality presets and a one-key toggle.
</p>

<p align="center">
  <a href="https://www.minecraft.net"><img alt="Minecraft 1.21.1" src="https://img.shields.io/badge/Minecraft-1.21.1-62B47A"></a>
  <a href="https://neoforged.net"><img alt="NeoForge" src="https://img.shields.io/badge/Loader-NeoForge-F16436"></a>
  <a href="https://www.curseforge.com/minecraft/mc-mods/irisshaders"><img alt="Requires Iris" src="https://img.shields.io/badge/Requires-Iris-5B4FE0"></a>
  <a href="LICENSE"><img alt="License MIT" src="https://img.shields.io/badge/License-MIT-blue"></a>
</p>

<p align="center">
  <img src="docs/screenshots/lake.jpg" alt="A lake village at noon: clear water, reflections and soft haze" width="720">
</p>

## Why a mod and not a shader pack?

The pack inside is an ordinary Iris shader pack. Shipping it as a mod adds what a pack on its own cannot do:

- 📥 **Installs itself** - on launch the mod puts the pack into `shaderpacks` and turns it on (unless you already use
  another pack). Updates arrive through the CurseForge app like any mod, and a modpack can depend on it.
- 🌿 **Knows your modded blocks** - a shader pack only recognises the block IDs written into it by hand. The mod scans
  every installed block at launch and adds leaves, plants, vines and bright lamps from all your mods, so they wave and
  glow like vanilla ones.
- 🌦️ **Reads the weather of other mods** - a pack only sees vanilla rain and thunder. The mod passes the rain type,
  wind, lightning flashes and rainbows of [Petrichor](https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms),
  the blizzard strength of [Hoarfrost](https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards) and the
  gusts of [Rustling Leaves](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves) to the shaders.
- 🎮 **In-game controls** - `F6` turns the shaders on and off, a key and `/shaders preset` switch the quality, and
  `/shaders perf` and `/shaders bench` show what each effect costs on your computer.

## Looks best with my visual mods

The pack is tuned together with these mods and reads their state live:

[![Petrichor: Rain & Storms](docs/more-mods/petrichor.png)](https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms) ✅ **[Petrichor: Rain & Storms](https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms)** - drizzles, downpours and storms set the sky, light and fog; puddles stay still with pixel rain rings; its rainbows and lightning light the clouds.

[![Hoarfrost: Snow & Blizzards](docs/more-mods/hoarfrost.png)](https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards) ✅ **[Hoarfrost: Snow & Blizzards](https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards)** - blizzards stay bright, not dark: the haze closes in with the storm's visibility and gusts, and the flakes and snow cover take on the pack's light.

[![Rustling Leaves](docs/more-mods/rustling_leaves.png)](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves) ✅ **[Rustling Leaves](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves)** - grass and crowns sway with the same gust waves that blow the leaves; leaves and litter are shaded like the blocks around them.

[![Turbo for Distant Horizons](docs/more-mods/dhturbo.png)](https://www.curseforge.com/minecraft/mc-mods/turbo-for-distant-horizons) ✅ **[Turbo for Distant Horizons](https://www.curseforge.com/minecraft/mc-mods/turbo-for-distant-horizons)** - the distant land fills in fast, and the pack gives it shadows, water and haze.

## Features

- ☀️ **Natural light** - a physically based sky, a warm low sun, soft coloured shadows with crisp pixel edges, and
  colours close to vanilla at noon instead of a repainted world.
- 🌅 **Juicy sunrises and sunsets** on both sides of the sky, a pink dawn with a morning haze, a soft moonlit night.
- ☁️ **Vanilla-shaped clouds with volume** - the game's own cloud pattern as lit 3D cubes that cast shadows; size and
  height adjustable.
- 🌊 **Living water** - refraction, reflections of the world and sky, sun glitter, caustics, shore foam, foaming
  waterfalls, lamp light glowing in the water, a darker sea far from the shore.
- 🌾 **Waving grass and leaves** with light shining through them.
- ⛈️ **Weather you can feel** - a grey overcast in rain, dark thunderstorms with lightning lighting the clouds, wet
  ground with puddle patches, rainbows after rain, mist in valleys and swamps.
- 🔥 **Warm block light** - flickering torches, glowing lava that looks hot, caves that follow the game's Brightness
  setting.
- 🔭 **[Distant Horizons](https://www.curseforge.com/minecraft/mc-mods/distant-horizons) support** - distant land and
  water shaded like the near world, with shadows and haze.
- 🎚️ **Four quality presets** - Low, Medium, High, Ultra, or `/shaders preset auto` to pick the best one your
  computer runs smoothly - and every effect on its own switch in the Iris menu.

## Controls

| Action | Default |
| --- | --- |
| Shaders on/off | `F6` |
| Next quality preset | unbound (Controls > Pocky Shaders) |
| Command | `/shaders on`, `off`, `toggle`, `status`, `preset <low/medium/high/ultra/auto>`, `perf`, `bench` |

## Crafting

Nothing to craft: the mod has no items.

## Configuration

- **Shader options**: *Video Settings > Shader Packs > Pocky Shaders > Shader Pack Settings* - the quality preset and
  every effect (lighting, nature, water, sky, weather, post-processing), each on its own switch or slider.
- **Mod options** (`pocky_shaders-client.toml`, also in the in-game mod list): install the pack, turn it on after the
  first install, add the waving and glowing blocks of other mods.

## Compatibility

[![Iris](docs/compat/iris.png)](https://www.curseforge.com/minecraft/mc-mods/irisshaders) ✅ **[Iris](https://www.curseforge.com/minecraft/mc-mods/irisshaders)** (required) - the pack runs on Iris; its own options stay in the Iris shader pack menu.

[![Sodium](docs/compat/sodium.png)](https://www.curseforge.com/minecraft/mc-mods/sodium) ✅ **[Sodium](https://www.curseforge.com/minecraft/mc-mods/sodium)** - required by Iris, works.

[![Distant Horizons](docs/compat/distant-horizons.png)](https://www.curseforge.com/minecraft/mc-mods/distant-horizons) ✅ **[Distant Horizons](https://www.curseforge.com/minecraft/mc-mods/distant-horizons)** (optional) - LOD terrain and water are lit, shadowed and fogged by the pack.

[![Colorwheel](docs/compat/colorwheel.png)](https://www.curseforge.com/minecraft/mc-mods/colorwheel) ✅ **[Colorwheel](https://www.curseforge.com/minecraft/mc-mods/colorwheel)** (optional) - with [Create](https://www.curseforge.com/minecraft/mc-mods/create) and other Flywheel mods, contraptions, water wheels, cogs and trains are drawn by Colorwheel with the pack's light and shadows, so they stay fast and still look like the world around them.

## Installation

1. Install [NeoForge](https://neoforged.net) for Minecraft 1.21.1, [Sodium](https://www.curseforge.com/minecraft/mc-mods/sodium)
   and [Iris](https://www.curseforge.com/minecraft/mc-mods/irisshaders).
2. Put this mod into the `mods` folder (client only).
3. Start the game: the pack is installed into `shaderpacks/Pocky Shaders` and turned on. Press `F6` to toggle it.

## Building

```sh
./gradlew build
```

The jar is written to `build/libs/`. `python tools/preview/compile_check.py` compiles every shader program offline.

## Screenshots

![Caustics in a forest pond with Rustling Leaves](docs/screenshots/forest-pond.jpg)

*Caustics in a forest pond, with [Rustling Leaves](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves)*

![A wet meadow on a clear morning](docs/screenshots/meadow.jpg)

*A wet meadow on a clear morning*

![A thunderstorm over a river canyon with Petrichor](docs/screenshots/thunderstorm.jpg)

*A thunderstorm over a river canyon, with [Petrichor](https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms)*

![A blizzard in the snowy taiga with Hoarfrost](docs/screenshots/blizzard.jpg)

*A blizzard in the snowy taiga, with [Hoarfrost](https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards)*

![A moonlit night over the coast](docs/screenshots/night.jpg)

*A moonlit night over the coast*

## Credits

- Author: **Pocky**.
- The shader pack inside the jar is released under the same [MIT](LICENSE) license.

<!-- more-mods:start -->
## More mods by Pocky

**🌦️ Weather & nature**

<table>
  <tr>
    <td width="56"><a href="https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards"><img src="docs/more-mods/hoarfrost.png" width="48" alt="Hoarfrost: Snow & Blizzards"></a></td>
    <td><a href="https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards"><b>Hoarfrost: Snow & Blizzards</b></a> - seven kinds of snowfall, a living wind and soft snow on the land (<a href="https://github.com/Pocky-l/hoarfrost">source</a>)</td>
  </tr>
  <tr>
    <td width="56"><a href="https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms"><img src="docs/more-mods/petrichor.png" width="48" alt="Petrichor: Rain & Storms"></a></td>
    <td><a href="https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms"><b>Petrichor: Rain & Storms</b></a> - realistic rain, puddles, drips and branching lightning (<a href="https://github.com/Pocky-l/petrichor">source</a>)</td>
  </tr>
  <tr>
    <td width="56"><a href="https://www.curseforge.com/minecraft/mc-mods/rustling-leaves"><img src="docs/more-mods/rustling_leaves.png" width="48" alt="Rustling Leaves"></a></td>
    <td><a href="https://www.curseforge.com/minecraft/mc-mods/rustling-leaves"><b>Rustling Leaves</b></a> - falling leaves and leaf piles you can wade through, rake and blow away (<a href="https://github.com/Pocky-l/rustling-leaves">source</a>)</td>
  </tr>
</table>

**💡 Light**

<table>
  <tr>
    <td width="56"><a href="https://www.curseforge.com/minecraft/mc-mods/lumen-rigs"><img src="docs/more-mods/lumen_rigs.png" width="48" alt="Lumen Rigs"></a></td>
    <td><a href="https://www.curseforge.com/minecraft/mc-mods/lumen-rigs"><b>Lumen Rigs</b></a> - aimable spotlights and floodlights with colored light and visible beams (<a href="https://github.com/Pocky-l/lumen-rigs">source</a>)</td>
  </tr>
  <tr>
    <td width="56"><a href="https://www.curseforge.com/minecraft/mc-mods/neon-glowsticks"><img src="docs/more-mods/neon_glowsticks.png" width="48" alt="Neon Glowsticks"></a></td>
    <td><a href="https://www.curseforge.com/minecraft/mc-mods/neon-glowsticks"><b>Neon Glowsticks</b></a> - throwable glowsticks that bounce, roll and light up the dark (<a href="https://github.com/Pocky-l/neon-glowsticks">source</a>)</td>
  </tr>
</table>

**🎨 Graphics & performance**

<table>
  <tr>
    <td width="56"><a href="https://www.curseforge.com/minecraft/mc-mods/turbo-for-distant-horizons"><img src="docs/more-mods/dhturbo.png" width="48" alt="Turbo for Distant Horizons"></a></td>
    <td><a href="https://www.curseforge.com/minecraft/mc-mods/turbo-for-distant-horizons"><b>Turbo for Distant Horizons</b></a> - Distant Horizons terrain generated many times faster (<a href="https://github.com/Pocky-l/dhturbo">source</a>)</td>
  </tr>
</table>

**⚔️ Gear & gameplay**

<table>
  <tr>
    <td width="56"><a href="https://www.curseforge.com/minecraft/mc-mods/holy-staff"><img src="docs/more-mods/holy_staff.png" width="48" alt="Holy Staff"></a></td>
    <td><a href="https://www.curseforge.com/minecraft/mc-mods/holy-staff"><b>Holy Staff</b></a> - a healing staff with three skills and flying heal numbers (<a href="https://github.com/Pocky-l/holy-staff">source</a>)</td>
  </tr>
  <tr>
    <td width="56"><a href="https://www.curseforge.com/minecraft/mc-mods/ranchers-vacpack"><img src="docs/more-mods/vacpack.png" width="48" alt="Rancher's Vacpack"></a></td>
    <td><a href="https://www.curseforge.com/minecraft/mc-mods/ranchers-vacpack"><b>Rancher's Vacpack</b></a> - a Slime Rancher vacuum gun for items and small mobs (<a href="https://github.com/Pocky-l/ranchers-vacpack">source</a>)</td>
  </tr>
</table>

**⚡ Tech & energy**

<table>
  <tr>
    <td width="56"><a href="https://www.curseforge.com/minecraft/mc-mods/mekanism-advancedgenerators"><img src="docs/more-mods/mekanismadvancedgenerators.png" width="48" alt="Mekanism Advanced Generators"></a></td>
    <td><a href="https://www.curseforge.com/minecraft/mc-mods/mekanism-advancedgenerators"><b>Mekanism Advanced Generators</b></a> - nine tiers of solar panels, big solar generators, cubes and cables for Mekanism (<a href="https://github.com/Pocky-l/Mekanism-MoreSolarPanels">source</a>)</td>
  </tr>
</table>

**🛠️ Server tools**

<table>
  <tr>
    <td width="56"><a href="https://www.curseforge.com/minecraft/mc-mods/inventory-backups"><img src="docs/more-mods/inventorybackups.png" width="48" alt="Inventory Backups"></a></td>
    <td><a href="https://www.curseforge.com/minecraft/mc-mods/inventory-backups"><b>Inventory Backups</b></a> - inventory and ender chest backups with one-click restore for admins (<a href="https://github.com/Pocky-l/inventory-backups">source</a>)</td>
  </tr>
</table>

<!-- more-mods:end -->

## License

[MIT](LICENSE)

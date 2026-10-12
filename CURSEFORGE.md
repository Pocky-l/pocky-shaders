# Pocky Shaders

**A cosy, natural shader pack that sets itself up** - soft shadows, living water and foliage, juicy sunrises and
weather you can feel, while the game still looks like Minecraft. Quality presets and a one-key toggle.

![A lake village at noon: clear water, reflections and soft haze](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/screenshots/lake.jpg)

📦 **Requires** [NeoForge](https://neoforged.net) 1.21.1 and [Iris](https://www.curseforge.com/minecraft/mc-mods/irisshaders)
(with [Sodium](https://www.curseforge.com/minecraft/mc-mods/sodium)) · client only

## 🧩 Why a mod and not a shader pack?

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

## 💞 Looks best with my visual mods

The pack is tuned together with these mods and reads their state live:

[![Petrichor: Rain & Storms](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/petrichor.png)](https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms) ✅ **[Petrichor: Rain & Storms](https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms)** - drizzles, downpours and storms set the sky, light and fog; puddles stay still with pixel rain rings; its rainbows and lightning light the clouds.

[![Hoarfrost: Snow & Blizzards](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/hoarfrost.png)](https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards) ✅ **[Hoarfrost: Snow & Blizzards](https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards)** - blizzards stay bright, not dark: the haze closes in with the storm's visibility and gusts, and the flakes and snow cover take on the pack's light.

[![Rustling Leaves](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/rustling_leaves.png)](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves) ✅ **[Rustling Leaves](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves)** - grass and crowns sway with the same gust waves that blow the leaves; leaves and litter are shaded like the blocks around them.

[![Turbo for Distant Horizons](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/dhturbo.png)](https://www.curseforge.com/minecraft/mc-mods/turbo-for-distant-horizons) ✅ **[Turbo for Distant Horizons](https://www.curseforge.com/minecraft/mc-mods/turbo-for-distant-horizons)** - the distant land fills in fast, and the pack gives it shadows, water and haze.

## ✨ Features

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
- 🎚️ **Four quality presets** - Low, Medium, High, Ultra - and every effect on its own switch in the Iris menu.

## 🎮 Controls

| Action | Default |
| --- | --- |
| Shaders on/off | `F6` |
| Next quality preset | unbound (Controls > Pocky Shaders) |
| Command | `/shaders on`, `off`, `toggle`, `status`, `preset <low/medium/high/ultra>`, `perf`, `bench` |

## 🤝 Compatibility

[![Iris](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/compat/iris.png)](https://www.curseforge.com/minecraft/mc-mods/irisshaders) ✅ **[Iris](https://www.curseforge.com/minecraft/mc-mods/irisshaders)** (required) - the pack runs on Iris; its own options stay in the Iris shader pack menu.

[![Sodium](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/compat/sodium.png)](https://www.curseforge.com/minecraft/mc-mods/sodium) ✅ **[Sodium](https://www.curseforge.com/minecraft/mc-mods/sodium)** - required by Iris, works.

[![Distant Horizons](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/compat/distant-horizons.png)](https://www.curseforge.com/minecraft/mc-mods/distant-horizons) ✅ **[Distant Horizons](https://www.curseforge.com/minecraft/mc-mods/distant-horizons)** (optional) - LOD terrain and water are lit, shadowed and fogged by the pack.

## 📸 Screenshots

![Caustics in a forest pond with Rustling Leaves](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/screenshots/forest-pond.jpg)

*Caustics in a forest pond, with [Rustling Leaves](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves)*

![A wet meadow on a clear morning](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/screenshots/meadow.jpg)

*A wet meadow on a clear morning*

![A thunderstorm over a river canyon with Petrichor](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/screenshots/thunderstorm.jpg)

*A thunderstorm over a river canyon, with [Petrichor](https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms)*

![A blizzard in the snowy taiga with Hoarfrost](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/screenshots/blizzard.jpg)

*A blizzard in the snowy taiga, with [Hoarfrost](https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards)*

![A moonlit night over the coast](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/screenshots/night.jpg)

*A moonlit night over the coast*

## 💛 Credits

Made by **Pocky** · [source code](https://github.com/Pocky-l/pocky-shaders) · the shader pack inside is released under
the same MIT license.

<!-- more-mods:start -->
## More mods by Pocky

**🌦️ Weather & nature**

[![Hoarfrost: Snow & Blizzards](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/hoarfrost.png)](https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards) **[Hoarfrost: Snow & Blizzards](https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards)** - seven kinds of snowfall, a living wind and soft snow on the land

[![Petrichor: Rain & Storms](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/petrichor.png)](https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms) **[Petrichor: Rain & Storms](https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms)** - realistic rain, puddles, drips and branching lightning

[![Rustling Leaves](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/rustling_leaves.png)](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves) **[Rustling Leaves](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves)** - falling leaves and leaf piles you can wade through, rake and blow away

**💡 Light**

[![Lumen Rigs](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/lumen_rigs.png)](https://www.curseforge.com/minecraft/mc-mods/lumen-rigs) **[Lumen Rigs](https://www.curseforge.com/minecraft/mc-mods/lumen-rigs)** - aimable spotlights and floodlights with colored light and visible beams

[![Neon Glowsticks](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/neon_glowsticks.png)](https://www.curseforge.com/minecraft/mc-mods/neon-glowsticks) **[Neon Glowsticks](https://www.curseforge.com/minecraft/mc-mods/neon-glowsticks)** - throwable glowsticks that bounce, roll and light up the dark

**🎨 Graphics & performance**

[![Turbo for Distant Horizons](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/dhturbo.png)](https://www.curseforge.com/minecraft/mc-mods/turbo-for-distant-horizons) **[Turbo for Distant Horizons](https://www.curseforge.com/minecraft/mc-mods/turbo-for-distant-horizons)** - Distant Horizons terrain generated many times faster

**⚔️ Gear & gameplay**

[![Holy Staff](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/holy_staff.png)](https://www.curseforge.com/minecraft/mc-mods/holy-staff) **[Holy Staff](https://www.curseforge.com/minecraft/mc-mods/holy-staff)** - a healing staff with three skills and flying heal numbers

[![Rancher's Vacpack](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/vacpack.png)](https://www.curseforge.com/minecraft/mc-mods/ranchers-vacpack) **[Rancher's Vacpack](https://www.curseforge.com/minecraft/mc-mods/ranchers-vacpack)** - a Slime Rancher vacuum gun for items and small mobs

**⚡ Tech & energy**

[![Mekanism Advanced Generators](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/mekanismadvancedgenerators.png)](https://www.curseforge.com/minecraft/mc-mods/mekanism-advancedgenerators) **[Mekanism Advanced Generators](https://www.curseforge.com/minecraft/mc-mods/mekanism-advancedgenerators)** - nine tiers of solar panels, big solar generators, cubes and cables for Mekanism

**🛠️ Server tools**

[![Inventory Backups](https://raw.githubusercontent.com/Pocky-l/pocky-shaders/main/docs/more-mods/inventorybackups.png)](https://www.curseforge.com/minecraft/mc-mods/inventory-backups) **[Inventory Backups](https://www.curseforge.com/minecraft/mc-mods/inventory-backups)** - inventory and ender chest backups with one-click restore for admins

<!-- more-mods:end -->

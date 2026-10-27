# Weather data for shader packs

[Petrichor](https://www.curseforge.com/minecraft/mc-mods/petrichor-rain-storms),
[Hoarfrost](https://www.curseforge.com/minecraft/mc-mods/hoarfrost-snow-blizzards) and
[Rustling Leaves](https://www.curseforge.com/minecraft/mc-mods/rustling-leaves) simulate weather that vanilla uniforms
do not carry: rain types, sun showers, wetness, rainbows, snow kinds, blizzards, wind and gusts. While an
[Iris](https://www.curseforge.com/minecraft/mc-mods/irisshaders) shader pack is on, each of them publishes its state
every frame as a small float texture that any pack can read. Pocky Shaders is built on it (`shaders/lib/modweather.glsl`).

## Reading it from a pack

`shaders.properties`:

```properties
customTexture.petrichorData = petrichor:shader_data
customTexture.hoarfrostData = hoarfrost:shader_data
customTexture.leavesData = rustling_leaves:shader_data
```

```glsl
uniform sampler2D petrichorData;
vec4 petrichor(int i) { return texelFetch(petrichorData, ivec2(i, 0), 0); }
```

Each texture is one row of RGBA32F texels with nearest filtering and no mipmaps; read it with `texelFetch`. When the mod
is not installed (or too old), Iris binds its missing texture instead. Check texel 0 before trusting the rest:

```glsl
bool linked(vec4 t0) {
    return abs(t0.x - 0.123) < 1e-3 && abs(t0.y - 0.456) < 1e-3 && abs(t0.z - 0.789) < 1e-3 && t0.w > 0.5;
}
```

## Layout, format 1

Texels 0..2 are the same in all three textures.

| Texel | r | g | b | a |
| --- | --- | --- | --- | --- |
| 0 | 0.123 | 0.456 | 0.789 | format version (1) |
| 1 | wind direction x | wind direction z | wind speed (blocks per tick) | share of the weather this wind covers, 0..1 |
| 2 | drift x (blocks) | drift z (blocks) | 0 | 0 |

**Petrichor** (`petrichor:shader_data`, 6 texels)

| Texel | r | g | b | a |
| --- | --- | --- | --- | --- |
| 3 | rain 0..1 | rain level / 3 (0 drizzle .. 1 thunderstorm) | sunshine 0..1 (sun shower) | wetness 0..1 |
| 4 | rainbow strength 0..1 | rainbow side (1 east, -1 west) | lightning flash (0..~1.5) | sky view 0..1 |
| 5 | rain gust factor (1 = steady) | puddles tagged (1) | 0 | 0 |

Puddles are drawn as water tagged with render type 2 (`mc_Entity.y == 2`) and the pack's water id in `mc_Entity.x`.

**Hoarfrost** (`hoarfrost:shader_data`, 5 texels)

| Texel | r | g | b | a |
| --- | --- | --- | --- | --- |
| 3 | snow 0..1 | snow streaming in the wind 0..1 (blizzards) | visibility (blocks) | snow density |
| 4 | accumulation | snow gust factor (1 = steady) | 0 | 0 |

**Rustling Leaves** (`rustling_leaves:shader_data`, 4 texels)

| Texel | r | g | b | a |
| --- | --- | --- | --- | --- |
| 3 | gust wave phase (radians, wraps at 20 pi) | 0 | 0 | 0 |

The leaves' gust strength at a world position is `0.5 + 0.32 sin(s) + 0.18 sin(2.7 s + 1.1)` (squared for the leaves
themselves) with `s = phase - dot(xz, direction) * 0.05`.

## Wind shares

Each mod blows its own wind. So that a pack gets one smooth wind from any combination of the mods, the weather is split
into three shares, computed by every mod the same way from vanilla state at the camera:

- `rain = rainLevel x (1 - snowy)`, `snow = rainLevel x snowy`, `calm = 1 - rainLevel`;
- `rainLevel` = the level's rain level (0 in dimensions without an open sky), `snowy` = 1 when the biome at the camera
  snows.

Each share is covered by one mod: rain by Petrichor, snow by Hoarfrost, calm by Rustling Leaves. A share whose mod is
missing goes to the first one present in this order: rain - Petrichor, Rustling Leaves, Hoarfrost; snow - Hoarfrost,
Petrichor, Rustling Leaves; calm - Rustling Leaves, Petrichor, Hoarfrost. The shares of the linked textures therefore add
up to 1 whenever at least one of the mods is installed.

- Texel 1 `a` is the share the mod covers. Blend the winds by it:
  `direction = normalize(sum(share x dir))`, `speed = sum(share x speed)`.
- Texel 2 is the integral of `share x speed x direction` over time (game ticks, paused with the game), wrapped at
  +-100000 blocks. The sum of the linked drifts is how far the air has moved: mist and rain sheets carried with it never
  jump when the weather changes, unlike `speed x time`.

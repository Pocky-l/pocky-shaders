// Near-vanilla clouds: blocky cells of 12 x 12 blocks, 4 blocks thick, at the vanilla cloud height, drifting the
// vanilla way - but lit by the sun and sky (bright tops, shaded bottoms, sunlit sides), with translucent thin edges
// and haze in the distance. Rain closes them into a thicker, mottled deck; a thunderstorm adds a low layer of small,
// dark, fast-running scud cells under it. The main cells cast the shadows on the ground. A player can fly through.

const float CLOUD_BOTTOM = 192.0;

float cloudTop() {
    return CLOUD_BOTTOM + 4.0 + rainStrength * 4.0 + thunderStrength * 6.0;
}
const float CLOUD_CELL = 12.0;
// Vanilla clouds move 0.03 blocks per tick towards +x.
const float CLOUD_SPEED = 0.6;

float cloudCoverage() {
    return saturate(0.38 * CLOUD_COVERAGE + rainStrength * 0.4 + thunderStrength * 0.35);
}

vec2 cloudOffset() {
    return vec2(frameTimeCounter * CLOUD_SPEED, 0.0);
}

// Clouds form clumps of cells, like the vanilla cloud texture.
bool cloudCellAt(vec2 cell, float coverage, float seed) {
    vec2 p = cell * 0.11 + seed;
    float n = valueNoise(p) * 0.6 + valueNoise(p * 2.3 + 17.0) * 0.3 + hash12(cell + seed) * 0.1;
    return n > 1.0 - coverage;
}

// Storm mottling of a cell: thicker, darker cells next to thinner, lighter ones (0..1).
float cloudMottle(vec2 cell, float seed) {
    return valueNoise(cell * 0.09 + seed + 40.0) * 0.7 + hash12(cell + seed + 3.0) * 0.3;
}

// --- Cloud map (colortex7, CLOUD_MAP_SIZE^2 texels from CLOUD_MAP_ORIGIN) --------------------------------------
// The prepare pass stores, for each layer, the cells around the camera's cell (texel = cell mod size): r = main
// occupancy, g = main mottle, b = scud occupancy, a = scud mottle. Lookups farther than half the map, and windows
// too small to hold it, fall back to computing the cell.
const ivec2 CLOUD_MAP_ORIGIN = ivec2(66, 1);
const int CLOUD_MAP_SIZE = 256;

// The cell congruent to a map texel that lies nearest to the centre cell.
vec2 cloudMapCell(ivec2 texel, vec2 centre) {
    vec2 d = mod(vec2(texel) - centre, float(CLOUD_MAP_SIZE));
    d -= step(float(CLOUD_MAP_SIZE / 2), d) * float(CLOUD_MAP_SIZE);
    return centre + d;
}

#ifdef CLOUD_LOOKUP
bool cloudMapAvailable() {
    return viewWidth >= float(CLOUD_MAP_ORIGIN.x + CLOUD_MAP_SIZE) && viewHeight >= float(CLOUD_MAP_ORIGIN.y + CLOUD_MAP_SIZE);
}

// Map texel of a cell, or false when it is not in the map.
bool cloudMapTexel(vec2 cell, vec2 centre, out ivec2 texel) {
    vec2 d = cell - centre;
    texel = CLOUD_MAP_ORIGIN + ivec2(mod(cell, float(CLOUD_MAP_SIZE)));
    return cloudMapAvailable() && all(lessThan(abs(d), vec2(float(CLOUD_MAP_SIZE / 2) - 0.5)));
}
#endif

// Centre cell of a layer's map: the cell under the camera.
vec2 cloudMapCentre(vec2 offset, float cellSize) {
    return floor((cameraPosition.xz + offset) / cellSize);
}

// Occupancy (x) and mottle (y) of a cell of the main layer (scud = false) or the scud layer.
vec2 cloudCellData(vec2 cell, bool scud, float coverage, float seed, vec2 offset, float cellSize) {
#ifdef CLOUD_LOOKUP
    ivec2 texel;
    if (cloudMapTexel(cell, cloudMapCentre(offset, cellSize), texel)) {
        vec4 v = texelFetch(colortex7, texel, 0);
        return scud ? v.ba : v.rg;
    }
#endif
    return vec2(cloudCellAt(cell, coverage, seed) ? 1.0 : 0.0, cloudMottle(cell, seed));
}

bool cloudCell(vec2 cell) {
    return cloudCellData(cell, false, cloudCoverage(), 0.0, cloudOffset(), CLOUD_CELL).x > 0.5;
}

// One slab of blocky clouds.
struct CloudLayer {
    float bottom;
    float top;
    float cell;
    vec2 offset;
    float coverage;
    float seed;
    float brightness;
    bool scud;
};

CloudLayer mainCloudLayer() {
    return CloudLayer(CLOUD_BOTTOM, cloudTop(), CLOUD_CELL, cloudOffset(), cloudCoverage(), 0.0, 1.0, false);
}

vec2 scudOffset() {
    return frameTimeCounter * vec2(2.4, 0.7);
}

// Storm scud: ragged low cells racing under the deck (constant speed, so a change of weather never makes them jump;
// they appear through their coverage).
CloudLayer scudCloudLayer() {
    float coverage = saturate(thunderStrength * 0.62 + rainStrength * 0.2 - 0.15);
    return CloudLayer(150.0, 153.0, 8.0, scudOffset(), coverage, 31.7, 0.72, true);
}

// Soft occupancy at a world position (bilinear between cells), used for flat clouds.
float cloudCover(vec2 worldXZ) {
    vec2 g = (worldXZ + cloudOffset()) / CLOUD_CELL - 0.5;
    vec2 i = floor(g);
    vec2 f = smoothstep(0.25, 0.75, fract(g));
    float a = cloudCell(i) ? 1.0 : 0.0;
    float b = cloudCell(i + vec2(1.0, 0.0)) ? 1.0 : 0.0;
    float c = cloudCell(i + vec2(0.0, 1.0)) ? 1.0 : 0.0;
    float d = cloudCell(i + vec2(1.0, 1.0)) ? 1.0 : 0.0;
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Blurred occupancy for ground shadows: smooth across the whole cell, so a shadow never shows the 12-block grid.
float cloudShadowCover(vec2 worldXZ) {
    vec2 g = (worldXZ + cloudOffset()) / CLOUD_CELL - 0.5;
    vec2 i = floor(g);
    vec2 f = smoothstep(0.0, 1.0, fract(g));
    float a = cloudCell(i) ? 1.0 : 0.0;
    float b = cloudCell(i + vec2(1.0, 0.0)) ? 1.0 : 0.0;
    float c = cloudCell(i + vec2(0.0, 1.0)) ? 1.0 : 0.0;
    float d = cloudCell(i + vec2(1.0, 1.0)) ? 1.0 : 0.0;
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Share of direct sunlight that gets through the clouds above a point (playerPos relative to the camera).
float cloudShadow(vec3 playerPos, vec3 lightDir) {
#if CLOUDS > 0
    vec3 worldPos = playerPos + cameraPosition;
    if (lightDir.y < 0.05 || worldPos.y > cloudTop()) {
        return 1.0;
    }
    float h = 0.5 * (CLOUD_BOTTOM + cloudTop());
    vec2 p = worldPos.xz + lightDir.xz * ((h - worldPos.y) / lightDir.y);
    // Light scattered around a small cloud keeps its shadow soft; the shadow fades as the sun gets low.
    float strength = 0.6 * smoothstep(0.05, 0.3, lightDir.y);
    return 1.0 - strength * cloudShadowCover(p);
#else
    return 1.0;
#endif
}

// Light reflected by a cloud face with the given normal.
vec3 cloudFaceLight(vec3 n, vec3 lightDir, vec3 directColor, vec3 ambientColor) {
    float up = n.y * 0.5 + 0.5;
    // Under an overcast deck the light comes from everywhere: bases stay close to the sky's brightness (a little
    // darker, darker still in a storm) instead of turning into a black lid with bright gaps.
    float skyShare = mix(mix(0.4, 1.1, up), 0.8, rainStrength);
    vec3 sky = ambientColor / PI * skyShare;
    // Clouds are not opaque: light through the cell keeps shaded faces from going grey.
    vec3 sun = directColor / PI * (saturate(dot(n, lightDir)) * 0.75 + 0.08 + 0.12 * up);
    return (sky + sun) * (1.0 - thunderStrength * 0.25);
}

// A lightning flash lights the deck from inside, brightest around the bolt.
vec3 cloudFlash(vec3 worldPos) {
    float flash = lightningFlash();
    if (flash <= 0.0) {
        return vec3(0.0);
    }
    float d = length(worldPos.xz - (cameraPosition.xz + lightningBoltPosition.xz));
    return FLASH_TINT * flash * (0.4 + 3.0 * exp(-d / 180.0));
}

#if CLOUDS == 2
// Clouds of one layer along a world-space ray up to maxDist. rgb: cloud light, a: transmittance behind.
vec4 cloudSlab(CloudLayer layer, vec3 origin, vec3 dir, float maxDist, vec3 lightDir, vec3 directColor,
        vec3 ambientColor, int maxCells) {
    float t0;
    float t1;
    if (abs(dir.y) < 1e-5) {
        if (origin.y < layer.bottom || origin.y > layer.top) {
            return vec4(0.0, 0.0, 0.0, 1.0);
        }
        t0 = 0.0;
        t1 = 1e6;
    } else {
        float tb = (layer.bottom - origin.y) / dir.y;
        float tt = (layer.top - origin.y) / dir.y;
        t0 = max(min(tb, tt), 0.0);
        t1 = max(tb, tt);
    }
    const float RANGE = 2400.0;
    t1 = min(t1, min(maxDist, RANGE));
    if (t1 <= t0) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    // Walk the cells along the ray (2D DDA over the xz grid, inside the slab).
    vec3 pos = origin + dir * t0;
    vec2 g = (pos.xz + layer.offset) / layer.cell;
    vec2 cell = floor(g);
    vec2 stepDir = vec2(dir.x >= 0.0 ? 1.0 : -1.0, dir.z >= 0.0 ? 1.0 : -1.0);
    vec2 invDir = 1.0 / max(abs(dir.xz), vec2(1e-6));
    vec2 nextBoundary = vec2(
            stepDir.x > 0.0 ? (cell.x + 1.0) - g.x : g.x - cell.x,
            stepDir.y > 0.0 ? (cell.y + 1.0) - g.y : g.y - cell.y) * layer.cell * invDir;
    vec2 cellStep = layer.cell * invDir;
    vec3 slabFace = vec3(0.0, -sign(dir.y), 0.0);

    // Face the ray enters through: the slab plane, unless the camera is already inside.
    vec3 entryNormal = (t0 > 0.0) ? slabFace : -dir;
    float t = t0;
    vec3 light = vec3(0.0);
    float transmittance = 1.0;
    vec3 faceNormal = entryNormal;
    bool inside = false;
    for (int i = 0; i < maxCells; i++) {
        float tNext = min(t0 + min(nextBoundary.x, nextBoundary.y), t1);
        vec2 data = cloudCellData(cell, layer.scud, layer.coverage, layer.seed, layer.offset, layer.cell);
        bool occupied = data.x > 0.5;
        if (occupied && !inside) {
            faceNormal = entryNormal;
        }
        inside = occupied;
        // Far away a cell gets smaller than a pixel and the hard cell pattern turns into rings (moire): blend the
        // main deck into its smooth cell density and the plain slab-face shading.
        float lod = smoothstep(300.0, 900.0, t);
        float density = occupied ? 1.0 : 0.0;
        vec3 mid = origin + dir * (0.5 * (t + tNext));
        if (lod > 0.0 && !layer.scud) {
            density = mix(density, cloudShadowCover(mid.xz), lod);
        }
        if (density > 0.0) {
            float len = tNext - t;
            // Thin slices (grazing edges) are see-through, a full cell is nearly opaque. Rain hides distant clouds
            // in the falling water, so the deck melts into the sky towards the horizon.
            float a = (1.0 - exp(-len * 0.3)) * density * exp(-rainStrength * 0.0015 * t);
            float haze = smoothstep(RANGE * 0.45, RANGE, t);
            vec3 c = cloudFaceLight(faceNormal, lightDir, directColor, ambientColor);
            if (lod > 0.0) {
                c = mix(c, cloudFaceLight(slabFace, lightDir, directColor, ambientColor), lod);
            }
            // Rain clouds are mottled: thicker, darker cells next to thinner, lighter ones give the deck a shape.
            c *= layer.brightness * mix(1.0, 0.55 + 0.8 * data.y, rainStrength);
            c += cloudFlash(mid);
            light += c * a * transmittance * (1.0 - haze);
            transmittance *= 1.0 - a * (1.0 - haze);
            if (transmittance < 0.02) {
                break;
            }
        }
        if (tNext >= t1) {
            break;
        }
        // Step into the next cell and remember which side face we cross.
        if (nextBoundary.x < nextBoundary.y) {
            cell.x += stepDir.x;
            nextBoundary.x += cellStep.x;
            entryNormal = vec3(-stepDir.x, 0.0, 0.0);
        } else {
            cell.y += stepDir.y;
            nextBoundary.y += cellStep.y;
            entryNormal = vec3(0.0, 0.0, -stepDir.y);
        }
        t = tNext;
    }
    return vec4(light, transmittance);
}
#endif

// Clouds along a world-space ray from origin up to maxDist. rgb: cloud light, a: transmittance behind.
vec4 cloudLayersFrom(vec3 origin, vec3 dir, float maxDist, vec3 lightDir, vec3 directColor, vec3 ambientColor, int steps) {
#if CLOUDS == 1
    // Flat: one plane at the cloud base, like vanilla "Fast" clouds.
    const float RANGE = 2400.0;
    if (abs(dir.y) < 1e-5) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    float t0 = (CLOUD_BOTTOM - origin.y) / dir.y;
    if (t0 <= 0.0 || t0 > min(maxDist, RANGE)) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    vec2 p = origin.xz + dir.xz * t0;
    float cover = cloudCover(p);
    vec3 col = cloudFaceLight(vec3(0.0, -sign(dir.y), 0.0), lightDir, directColor, ambientColor)
            + cloudFlash(vec3(p.x, 0.0, p.y));
    float a = cover * 0.85 * (1.0 - smoothstep(RANGE * 0.5, RANGE, t0)) * exp(-rainStrength * 0.0015 * t0);
    return vec4(col * a, 1.0 - a);
#elif CLOUDS == 2
    vec4 deck = cloudSlab(mainCloudLayer(), origin, dir, maxDist, lightDir, directColor, ambientColor, steps * 5);
    CloudLayer scud = scudCloudLayer();
    if (scud.coverage <= 0.0) {
        return deck;
    }
    vec4 low = cloudSlab(scud, origin, dir, maxDist, lightDir, directColor, ambientColor, steps * 3);
    // The layer nearer to the eye goes in front.
    vec4 front = origin.y < scud.top ? low : deck;
    vec4 back = origin.y < scud.top ? deck : low;
    return vec4(front.rgb + back.rgb * front.a, front.a * back.a);
#else
    return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

// Clouds seen in a reflection: the deck base as a flat plane (one smooth lookup instead of walking the cells; the
// rippled water hides the difference).
vec4 cloudReflection(vec3 origin, vec3 dir, vec3 lightDir, vec3 directColor, vec3 ambientColor) {
#if CLOUDS > 0
    if (dir.y < 1e-3 || origin.y > CLOUD_BOTTOM) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    float t = (CLOUD_BOTTOM - origin.y) / dir.y;
    const float RANGE = 2400.0;
    if (t > RANGE) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    vec2 p = origin.xz + dir.xz * t;
    float cover = cloudShadowCover(p);
    vec3 col = cloudFaceLight(vec3(0.0, -1.0, 0.0), lightDir, directColor, ambientColor) * mix(1.0, 0.85, rainStrength)
            + cloudFlash(vec3(p.x, 0.0, p.y));
    float a = cover * 0.9 * (1.0 - smoothstep(RANGE * 0.45, RANGE, t)) * exp(-rainStrength * 0.0015 * t);
    return vec4(col * a, 1.0 - a);
#else
    return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 cloudLayers(vec3 dir, float maxDist, vec3 lightDir, vec3 directColor, vec3 ambientColor, int steps, float noise) {
    return cloudLayersFrom(cameraPosition, dir, maxDist, lightDir, directColor, ambientColor, steps);
}

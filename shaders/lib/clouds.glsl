// Clouds close to vanilla Fancy clouds: the game's own cloud texture (a resource pack that changes it changes these
// too), one texel = a 12 x 12 block cell, 4 blocks thick at the vanilla cloud height (both x CLOUD_SIZE: bigger,
// more solid-looking cubes in the same shapes; the thickness also x CLOUD_HEIGHT: taller cubes), drifting the
// vanilla way. What
// the pack adds is light: the faces are lit by the sun and the sky (bright tops, softer sides, darker bases, sides
// glowing towards a low sun), distance blends them into the sky, and they shade the ground. Rain keeps the same
// shapes: some more cells join in and the clouds turn grey, as vanilla's do. A player can fly through them.

uniform sampler2D cloudtex;

// Vanilla: cloud height 192, the geometry sits 0.33 above it.
const float CLOUD_BOTTOM = 192.33;
const float CLOUD_THICKNESS = 4.0 * CLOUD_SIZE * CLOUD_HEIGHT;
const float CLOUD_CELL = 12.0 * CLOUD_SIZE;
// Over the whole visible world, Distant Horizons terrain included: far clouds have melted into the sky colour long
// before the fade at the end of the range (cloudClarity), so there is no edge.
const float CLOUD_RANGE = 8192.0;
// Opacity per block: about vanilla's 0.8 through the 4 blocks of a vanilla-sized cloud, thicker clouds a little more
// solid, while thin slices at the edges stay see-through.
const float CLOUD_DENSITY = 0.4 / sqrt(CLOUD_SIZE);
// Vanilla clouds drift 0.6 blocks per second. frameTimeCounter wraps every hour, so the speed is chosen to move the
// pattern by exactly one texture repeat (256 cells) per hour: the wrap never shows. Bigger cells drift faster in
// blocks, at the same pace in cells.
const float CLOUD_SPEED = 256.0 * CLOUD_CELL / 3600.0;
// Where the extra rain and thunder cells are read from: other parts of the same texture, so they keep its shapes.
const vec2 CLOUD_RAIN_SHIFT = vec2(97.0, 53.0);
const vec2 CLOUD_STORM_SHIFT = vec2(-71.0, 163.0);

float cloudTop() {
    return CLOUD_BOTTOM + CLOUD_THICKNESS;
}

vec2 cloudOffset() {
    return vec2(frameTimeCounter * CLOUD_SPEED, CLOUD_CELL * 0.33);
}

// Cloud texture at a cell. Vanilla maps the texture to 256 x 256 cells whatever its resolution.
bool cloudTexel(vec2 cell) {
    ivec2 size = textureSize(cloudtex, 0);
    vec2 uv = mod(cell, 256.0) / 256.0;
    return texelFetch(cloudtex, ivec2(uv * vec2(size)), 0).a > 0.5;
}

// Share of the sky where rain adds cells (and where a lower coverage option takes some away). It grows over broad,
// slowly changing regions, so clouds thicken patch by patch as the rain sets in instead of flickering cell by cell.
float cloudRegion(vec2 cell) {
    return valueNoise(cell / 7.0) * 0.75 + valueNoise(cell / 2.5 + 31.0) * 0.25;
}

bool cloudCell(vec2 cell) {
    float region = cloudRegion(cell);
    float fewer = saturate(1.0 - CLOUD_COVERAGE) * 1.6;
    if (cloudTexel(cell)) {
        // Lower coverage keeps only the cells that are clouds in both parts of the texture there.
        return region >= fewer || cloudTexel(cell + CLOUD_RAIN_SHIFT);
    }
    float extra = saturate(CLOUD_COVERAGE - 1.0) * 0.8 + overcast() * 0.8 + thunderStrength * 0.2;
    if (region < extra && cloudTexel(cell + CLOUD_RAIN_SHIFT)) {
        return true;
    }
    // A thunderstorm closes the gaps further.
    return region < thunderStrength * 0.9 && cloudTexel(cell + CLOUD_STORM_SHIFT);
}

float cloudCellValue(vec2 cell) {
    return cloudCell(cell) ? 1.0 : 0.0;
}

// Occupancy between cell centres at a world position. sharpness 1 keeps the cell edges (blurred over half a cell),
// 0 blends smoothly across the whole cell.
float cloudCover(vec2 worldXZ, float sharpness) {
    vec2 g = (worldXZ + cloudOffset()) / CLOUD_CELL - 0.5;
    vec2 i = floor(g);
    float edge = 0.5 * sharpness * 0.5;
    vec2 f = smoothstep(edge, 1.0 - edge, fract(g));
    float a = cloudCellValue(i);
    float b = cloudCellValue(i + vec2(1.0, 0.0));
    float c = cloudCellValue(i + vec2(0.0, 1.0));
    float d = cloudCellValue(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Share of direct sunlight that gets through the clouds above a point (playerPos relative to the camera).
float cloudShadow(vec3 playerPos, vec3 lightDir) {
#if CLOUDS > 0
    vec3 worldPos = playerPos + cameraPosition;
    if (lightDir.y < 0.05 || worldPos.y > cloudTop()) {
        return 1.0;
    }
    float h = CLOUD_BOTTOM + CLOUD_THICKNESS * 0.5;
    vec2 p = worldPos.xz + lightDir.xz * ((h - worldPos.y) / lightDir.y);
    // Light scattered around a small cloud keeps its shadow soft; the shadow fades as the sun gets low.
    float strength = 0.6 * smoothstep(0.05, 0.3, lightDir.y);
    return 1.0 - strength * cloudCover(p, 0.0);
#else
    return 1.0;
#endif
}

// Light of a cloud face with the given normal (a zero normal: seen from inside a cloud).
vec3 cloudFaceLight(vec3 n, vec3 lightDir, vec3 directColor, vec3 ambientColor) {
    // Vanilla face shading (top 1, east/west 0.9, north/south 0.8, bottom 0.7) keeps the blocky look readable.
    float face = n.y > 0.5 ? 1.0 : (n.y < -0.5 ? 0.7 : (abs(n.x) > 0.5 ? 0.9 : 0.8));
    // Faces the sun shines on get all of it (warm sides at sunset); light scattered through the cloud reaches the
    // others too.
    float sun = 0.35 + 0.65 * saturate(dot(n, lightDir));
    vec3 clear = (ambientColor * 1.05 + directColor * sun) / PI * face;
    // High up the clouds still catch the low sun when the land is already in its shadow: at sunset and through the
    // twilight they glow orange and pink.
    vec3 sunDir = sunDirection();
    float twilight = smoothstep(-0.12, -0.02, sunDir.y) * (1.0 - smoothstep(0.04, 0.25, sunDir.y));
    if (twilight > 0.0) {
        // Saturated, so the glow stays orange and pink instead of washing out to cream; rose at sunrise.
        vec3 hue = lowSunHue(sunDir.y + 0.03);
        hue = mix(hue * hue, vec3(1.0, 0.62, 0.68), 0.35 * morning());
        // A third of the saturation taken out: the full colour painted every cloud flat bubblegum pink.
        hue = mix(vec3(luminance(hue)), hue, 0.65);
        vec3 glow = hue * SUN_ILLUMINANCE * 0.08 * twilight;
        clear += glow * (0.35 + 0.65 * saturate(dot(n, sunDir))) / PI * face;
    }
    // Under rain only the grey sky lights them, and they must stay darker than it from below - lighter clouds on a
    // darker sky read as holes in it. Grey like vanilla's rain clouds, darker still in a thunderstorm. The overcast
    // ambient / pi is about 1.15 x the zenith radiance of the sky.
    float rainFace = n.y > 0.5 ? 1.1 : (n.y < -0.5 ? 0.5 : 0.66);
    vec3 grey = vec3(luminance(ambientColor)) / (PI * 1.15) * rainFace * mix(1.0, 0.7, stormDarkness());
    return mix(clear, grey, overcast());
}

// A lightning flash lights the clouds from inside, brightest around the bolt.
vec3 cloudFlash(vec3 worldPos) {
    float flash = lightningFlash();
    if (flash <= 0.0) {
        return vec3(0.0);
    }
    float d = length(worldPos.xz - (cameraPosition.xz + lightningBoltPosition.xz));
    return FLASH_TINT * flash * (0.4 + 3.0 * exp(-d / 180.0));
}

// Air between the eye and a cloud t blocks away: far clouds take on the colour of the sky behind them, and rain
// hides them sooner. Returns how much of the cloud is left (1 = all).
float cloudClarity(float t) {
    return exp(-t * (1.0 / 1800.0 + rainStrength / 1100.0));
}

// Fades the clouds out before the end of their range.
float cloudRangeFade(float t) {
    return 1.0 - smoothstep(CLOUD_RANGE * 0.6, CLOUD_RANGE, t);
}

#if CLOUDS == 2
// Blocky clouds along a world-space ray up to maxDist (2D walk over the cells inside the slab).
// rgb: cloud light (already blended into skyColor with distance), a: transmittance behind.
vec4 cloudSlab(vec3 origin, vec3 dir, float maxDist, vec3 lightDir, vec3 directColor, vec3 ambientColor,
        vec3 skyColor, int maxCells) {
    float bottom = CLOUD_BOTTOM;
    float top = cloudTop();
    float t0;
    float t1;
    if (abs(dir.y) < 1e-5) {
        if (origin.y < bottom || origin.y > top) {
            return vec4(0.0, 0.0, 0.0, 1.0);
        }
        t0 = 0.0;
        t1 = 1e6;
    } else {
        float tb = (bottom - origin.y) / dir.y;
        float tt = (top - origin.y) / dir.y;
        t0 = max(min(tb, tt), 0.0);
        t1 = max(tb, tt);
    }
    t1 = min(t1, min(maxDist, CLOUD_RANGE));
    if (t1 <= t0) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    vec2 offset = cloudOffset();
    vec3 pos = origin + dir * t0;
    vec2 g = (pos.xz + offset) / CLOUD_CELL;
    vec2 cell = floor(g);
    vec2 stepDir = vec2(dir.x >= 0.0 ? 1.0 : -1.0, dir.z >= 0.0 ? 1.0 : -1.0);
    vec2 invDir = 1.0 / max(abs(dir.xz), vec2(1e-6));
    vec2 nextBoundary = vec2(
            stepDir.x > 0.0 ? (cell.x + 1.0) - g.x : g.x - cell.x,
            stepDir.y > 0.0 ? (cell.y + 1.0) - g.y : g.y - cell.y) * CLOUD_CELL * invDir;
    vec2 cellStep = CLOUD_CELL * invDir;
    vec3 slabFace = vec3(0.0, -sign(dir.y), 0.0);
    // Size of a screen pixel on the cloud layer, in cells (stretched where the layer is seen edge-on). Once a cell
    // gets smaller than a pixel the hard pattern would turn into rings: it becomes a smooth cover instead.
    float pixelAngle = 1.4 / viewHeight;
    float slant = max(abs(dir.y), 0.03);

    // Face the ray enters through: the slab plane, or none when the camera is already inside.
    vec3 entryNormal = t0 > 0.0 ? slabFace : vec3(0.0);
    float t = t0;
    vec3 light = vec3(0.0);
    float transmittance = 1.0;
    vec3 faceNormal = entryNormal;
    bool inside = false;
    for (int i = 0; i < maxCells; i++) {
        float tNext = min(t0 + min(nextBoundary.x, nextBoundary.y), t1);
        bool occupied = cloudCell(cell);
        if (occupied && !inside) {
            faceNormal = entryNormal;
        }
        inside = occupied;
        float density = occupied ? 1.0 : 0.0;
        vec3 mid = origin + dir * (0.5 * (t + tNext));
        float lod = smoothstep(0.35, 1.0, t * pixelAngle / slant / CLOUD_CELL);
        if (lod > 0.0) {
            density = mix(density, cloudCover(mid.xz, 0.0), lod);
        }
        if (density > 0.0) {
            // Rain clouds are denser.
            float a = (1.0 - exp(-(tNext - t) * CLOUD_DENSITY * (1.0 + 0.5 * rainStrength))) * density
                    * cloudRangeFade(t);
            vec3 c = cloudFaceLight(lod > 0.0 ? mix(faceNormal, slabFace, lod) : faceNormal, lightDir, directColor,
                    ambientColor);
            c += cloudFlash(mid);
            c = mix(skyColor, c, cloudClarity(t));
            light += c * a * transmittance;
            transmittance *= 1.0 - a;
            if (transmittance < 0.02) {
                break;
            }
        }
        if (tNext >= t1) {
            break;
        }
        // Step into the next cell and remember which side face is crossed.
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

// A flat layer of clouds at the given height, seen along a ray (vanilla Fast clouds, and reflections).
vec4 cloudPlane(float height, vec3 origin, vec3 dir, float maxDist, vec3 lightDir, vec3 directColor,
        vec3 ambientColor, vec3 skyColor, float opacity) {
    if (abs(dir.y) < 1e-5) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    float t = (height - origin.y) / dir.y;
    if (t <= 0.0 || t > min(maxDist, CLOUD_RANGE)) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    vec2 p = origin.xz + dir.xz * t;
    float sharpness = 1.0 - smoothstep(0.35, 1.0, t * (1.4 / viewHeight) / max(abs(dir.y), 0.03) / CLOUD_CELL);
    float a = cloudCover(p, sharpness) * opacity * cloudRangeFade(t);
    vec3 c = cloudFaceLight(vec3(0.0, -sign(dir.y), 0.0), lightDir, directColor, ambientColor)
            + cloudFlash(vec3(p.x, height, p.y));
    c = mix(skyColor, c, cloudClarity(t));
    return vec4(c * a, 1.0 - a);
}

// Clouds along a world-space ray from origin up to maxDist. rgb: cloud light, a: transmittance behind.
vec4 cloudLayersFrom(vec3 origin, vec3 dir, float maxDist, vec3 lightDir, vec3 directColor, vec3 ambientColor,
        vec3 skyColor, int steps) {
#if CLOUDS == 1
    return cloudPlane(CLOUD_BOTTOM, origin, dir, maxDist, lightDir, directColor, ambientColor, skyColor, 0.8);
#elif CLOUDS == 2
    return cloudSlab(origin, dir, maxDist, lightDir, directColor, ambientColor, skyColor, steps * 5);
#else
    return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

vec4 cloudLayers(vec3 dir, float maxDist, vec3 lightDir, vec3 directColor, vec3 ambientColor, vec3 skyColor,
        int steps) {
    return cloudLayersFrom(cameraPosition, dir, maxDist, lightDir, directColor, ambientColor, skyColor, steps);
}

// Clouds seen in a reflection: the bases as a flat layer (the rippled water hides the difference).
vec4 cloudReflection(vec3 origin, vec3 dir, vec3 lightDir, vec3 directColor, vec3 ambientColor, vec3 skyColor) {
#if CLOUDS > 0
    if (dir.y < 1e-3 || origin.y > CLOUD_BOTTOM) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    return cloudPlane(CLOUD_BOTTOM, origin, dir, 1e6, lightDir, directColor, ambientColor, skyColor, 0.85);
#else
    return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

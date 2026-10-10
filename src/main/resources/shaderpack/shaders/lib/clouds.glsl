// Volumetric cumulus clouds in a slab of the sky, plus thin cirrus streaks high above (a flat layer).
//
// The cloud shape is a 2D map of column heights: each column is a puffy dome with a flat base, eroded by 3D noise.
// The prepare pass bakes the map for the area around the camera into colortex7 (one fetch per march step instead of
// a full noise stack); the deferred pass marches through the slab.

// Base at the vanilla cloud height, so a player can fly into them.
const float CLOUD_BOTTOM = 192.0;
const float CLOUD_TOP = 430.0;
const float CLOUD_HIGH_ALTITUDE = 900.0;

// Cloud map in colortex7, next to the sky table: 256 x 256 texels covering CLOUD_MAP_SPAN blocks around the camera.
const ivec2 CLOUD_MAP_ORIGIN = ivec2(66, 1);
const int CLOUD_MAP_SIZE = 256;
const float CLOUD_MAP_SPAN = 4096.0;
const float CLOUD_MAP_TEXEL = CLOUD_MAP_SPAN / float(CLOUD_MAP_SIZE);

float cloudFbm(vec2 p, int octaves) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(0.8, -0.6, 0.6, 0.8);
    for (int i = 0; i < octaves; i++) {
        v += valueNoise(p) * a;
        p = rot * p * 2.03 + 11.7;
        a *= 0.5;
    }
    return v;
}

float cloudCoverage() {
    return saturate(0.4 * CLOUD_COVERAGE + rainStrength * 0.4 + thunderStrength * 0.2);
}

vec2 cloudDrift() {
    return vec2(frameTimeCounter * 2.0, frameTimeCounter * 0.7);
}

// World xz of the map's centre, snapped to whole texels so the baked shapes do not swim as the camera moves.
vec2 cloudMapCenter() {
    return floor(cameraPosition.xz / CLOUD_MAP_TEXEL) * CLOUD_MAP_TEXEL;
}

// Column height of the clouds at world xz (0 = no cloud, 1 = up to the slab top). Used by the prepare pass.
float cloudColumn(vec2 worldXZ) {
    vec2 p = (worldXZ + cloudDrift()) * 0.0032;
    float shape = cloudFbm(p, 5);
    float coverage = cloudCoverage();
    float c = saturate((shape - (1.0 - coverage)) / max(coverage, 0.05) * 2.4);
    // Some cells grow into tall towers, most stay low and puffy.
    float growth = valueNoise(p * 0.31 + 3.1);
    return c * (0.3 + 0.7 * growth * growth);
}

float cloudNoise3(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * (3.0 - 2.0 * f);
    float n = i.x + i.y * 57.0 + i.z * 113.0;
    vec4 a = vec4(n, n + 1.0, n + 57.0, n + 58.0);
    vec4 h0 = fract(sin(a) * 43758.5453);
    vec4 h1 = fract(sin(a + 113.0) * 43758.5453);
    vec4 h = mix(h0, h1, u.z);
    return mix(mix(h.x, h.y, u.x), mix(h.z, h.w, u.x), u.y);
}

#ifdef CLOUD_LOOKUP

float sampleCloudColumn(vec2 worldXZ) {
#ifdef CLOUD_MAP_DIRECT
    return cloudColumn(worldXZ);
#endif
    vec2 local = (worldXZ - cloudMapCenter()) / CLOUD_MAP_SPAN + 0.5;
    if (any(lessThan(local, vec2(0.0))) || any(greaterThan(local, vec2(1.0)))) {
        return 0.0;
    }
    vec2 texel = vec2(CLOUD_MAP_ORIGIN) + 0.5 + local * float(CLOUD_MAP_SIZE - 1);
    return texture(colortex7, texel / vec2(viewWidth, viewHeight)).r;
}

// Cloud density at a world position; detail adds the 3D erosion that makes edges billow.
float cloudDensity(vec3 worldPos, bool detail) {
    float h = (worldPos.y - CLOUD_BOTTOM) / (CLOUD_TOP - CLOUD_BOTTOM);
    if (h < 0.0 || h > 1.0) {
        return 0.0;
    }
    float column = sampleCloudColumn(worldPos.xz);
    if (column <= 0.0) {
        return 0.0;
    }
    // Flat base, rounded dome towards the column top.
    float d = saturate((column - h) * 3.5) * smoothstep(0.0, 0.05, h);
    if (detail && d > 0.0) {
        vec3 q = (worldPos + vec3(cloudDrift().x, 0.0, cloudDrift().y)) * 0.028;
        float erosion = cloudNoise3(q) * 0.6 + cloudNoise3(q * 2.9 + 7.0) * 0.4;
        d = saturate(d * 1.4 - erosion * 0.75);
    }
    return d;
}

// Share of direct sunlight that gets through the clouds above a point (playerPos relative to the camera).
float cloudShadow(vec3 playerPos, vec3 lightDir) {
#if CLOUDS > 0
    if (lightDir.y < 0.05) {
        return 1.0;
    }
    vec3 worldPos = playerPos + cameraPosition;
    if (worldPos.y > CLOUD_TOP) {
        return 1.0;
    }
    float h0 = max(CLOUD_BOTTOM + 30.0, worldPos.y);
    float h1 = max(CLOUD_BOTTOM + 110.0, worldPos.y);
    vec2 p0 = worldPos.xz + lightDir.xz * ((h0 - worldPos.y) / lightDir.y);
    vec2 p1 = worldPos.xz + lightDir.xz * ((h1 - worldPos.y) / lightDir.y);
    float column = sampleCloudColumn(p0) + sampleCloudColumn(p1) * 0.7;
    // Thick clouds still let some diffuse light through.
    return mix(0.12, 1.0, exp(-column * 3.5));
#else
    return 1.0;
#endif
}

float cloudPhase(float mu) {
    // Strong forward lobe (silver lining) plus a soft backward one.
    return mix(miePhase(mu, -0.15), miePhase(mu, 0.7), 0.6) * 4.0 * PI;
}

// Volumetric clouds along a world-space ray from the camera, up to maxDist.
// rgb: in-scattered light, a: transmittance of what is behind.
vec4 volumetricClouds(vec3 dir, float maxDist, vec3 lightDir, vec3 directColor, vec3 ambientColor, int steps, float noise) {
    vec3 origin = cameraPosition;
    if (abs(dir.y) < 1e-4) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    float tb = (CLOUD_BOTTOM - origin.y) / dir.y;
    float tt = (CLOUD_TOP - origin.y) / dir.y;
    float t0 = max(min(tb, tt), 0.0);
    float t1 = min(max(tb, tt), min(maxDist, 6000.0));
    if (t1 <= t0) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    // Grazing rays cross much more cloud: more steps towards the horizon, and no further than the haze lets see.
    t1 = min(t1, t0 + 3000.0);
    int count = steps * 3 / 2;
    float stepLen = (t1 - t0) / float(count);
    float mu = dot(dir, lightDir);
    float phase = cloudPhase(mu);
    vec3 overcast = mix(vec3(1.0), vec3(0.5), rainStrength);
    vec3 sunLight = directColor / PI * phase;
    vec3 skyLight = ambientColor / PI;

    vec3 scattered = vec3(0.0);
    float transmittance = 1.0;
    float t = t0 + stepLen * noise;
    for (int i = 0; i < count; i++) {
        vec3 p = origin + dir * t;
        float d = cloudDensity(p, true);
        if (d > 0.01) {
            float sigma = d * 0.06;
            // Optical depth towards the light, a few samples further and further out.
            float od = 0.0;
            float prev = 0.0;
            for (int j = 1; j <= 4; j++) {
                float s = float(j * j) * 7.0;
                od += cloudDensity(p + lightDir * s, false) * (s - prev);
                prev = s;
            }
            od *= 0.06;
            // Beer with a softened tail standing in for multiple scattering; powder darkens the inside of thick parts.
            float beer = max(exp(-od), exp(-od * 0.3) * 0.35);
            float powder = 1.0 - exp(-d * 4.0 - od * 0.5);
            float h = (p.y - CLOUD_BOTTOM) / (CLOUD_TOP - CLOUD_BOTTOM);
            vec3 light = sunLight * beer * mix(0.45, 1.0, powder) + skyLight * (0.12 + 0.88 * h * h);
            float stepTransmittance = exp(-sigma * stepLen);
            scattered += light * overcast * transmittance * (1.0 - stepTransmittance);
            transmittance *= stepTransmittance;
            if (transmittance < 0.03) {
                break;
            }
        }
        t += stepLen;
    }
    // Far clouds sink into the haze.
    float fade = exp(-t0 * 0.00035);
    return vec4(scattered * fade, mix(1.0, transmittance, fade));
}

// Thin, high cirrus streaks.
vec4 cirrusClouds(vec3 dir, vec3 lightDir, vec3 directColor, vec3 ambientColor) {
    if (dir.y <= 0.0) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    float t = (CLOUD_HIGH_ALTITUDE - cameraPosition.y) / dir.y;
    vec2 p = cameraPosition.xz + dir.xz * t;
    float streak = cloudFbm(vec2((p.x + frameTimeCounter * 3.0) * 0.0006, p.y * 0.0025), 4);
    float a = saturate((streak - 0.52) * 2.2) * 0.25 * (1.0 - rainStrength * 0.6) * smoothstep(0.0, 0.12, dir.y);
    float forward = 1.0 + 2.5 * pow(saturate(dot(dir, lightDir)), 10.0);
    vec3 lit = directColor * 0.08 * forward + ambientColor * 0.35;
    return vec4(lit * a * mix(vec3(1.0), vec3(0.55), rainStrength), 1.0 - a);
}

// All cloud layers in front of a surface at maxDist (use a large value for the sky).
vec4 cloudLayers(vec3 dir, float maxDist, vec3 lightDir, vec3 directColor, vec3 ambientColor, int steps, float noise) {
    vec3 result = vec3(0.0);
    float transmittance = 1.0;
#if CLOUDS > 0
#if CLOUDS > 1
    if (maxDist > 5000.0 && cameraPosition.y < CLOUD_HIGH_ALTITUDE) {
        vec4 cirrus = cirrusClouds(dir, lightDir, directColor, ambientColor);
        result = cirrus.rgb;
        transmittance = cirrus.a;
    }
#endif
    vec4 cumulus = volumetricClouds(dir, maxDist, lightDir, directColor, ambientColor, steps, noise);
    // Cumulus are below the cirrus: they cover them.
    result = result * cumulus.a + cumulus.rgb;
    transmittance *= cumulus.a;
#endif
    return vec4(result, transmittance);
}

#endif

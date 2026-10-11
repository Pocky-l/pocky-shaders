// Atmospheric haze, valley mist, rain and cave fog, applied over the finished scene.
// Needs common, atmosphere and sky.

// Optical depth of the air over a distance: clear haze, plus rain that starts a little away from the player (the
// air right around you stays clear, the curtain builds up beyond it). rainSheets scales the rain part.
float fogOpticalDepth(float dist, float rainSheets) {
    // Falling snow hides the distance more than rain, a blizzard turns it into a white-out.
    float snow = 1.0 + snowWeather * (0.4 + 1.4 * thunderStrength);
    // Plain rain only veils the distance (islands a few hundred blocks out stay visible); a thunderstorm closes in.
    float rain = mix(0.0024, 0.0045, thunderStrength);
    return FOG_DENSITY * (0.00035 * dist + rainStrength * rain * snow * rainSheets * max(dist - 16.0, 0.0));
}

// Heavier and lighter sheets of rain sweeping across the land with the wind: rain density along a view ray, read
// where the ray is 30..140 blocks out (so the sheets stand in the world rather than sticking to the screen).
float rainSheets(vec3 dir, float dist) {
    if (rainStrength <= 0.0) {
        return 1.0;
    }
    vec2 p = cameraPosition.xz + dir.xz * clamp(dist, 30.0, 140.0);
    vec2 drift = frameTimeCounter * vec2(3.5, 1.2);
    float n = valueNoise((p - drift) / 90.0) * 0.65 + valueNoise((p - drift * 1.4) / 35.0 + 9.0) * 0.35;
    float strength = 0.6 + 0.6 * thunderStrength;
    return mix(1.0, 0.45 + 1.3 * n, strength);
}

#ifdef DIM_OVERWORLD
// Ground mist: banks of low cloud come down onto the land - a layer from below sea level up to 6..18 blocks above it
// that fills the water, rivers, swamps and low land while hills rise out of it. Broad banks with clear gaps between
// them, a soft lumpy top and finer wisps, drifting slowly with the wind.
const float MIST_BOTTOM = 52.0;
const float MIST_BASE = 62.0;
const float MIST_THICKNESS = 16.0;
const float MIST_RANGE = 1024.0;

float mistDensity(vec3 worldPos) {
    vec2 p = worldPos.xz + frameTimeCounter * vec2(0.35, 0.12);
    float banks = valueNoise(p / 170.0) * 0.65 + valueNoise(p / 61.0 + 17.0) * 0.35;
    float wisps = valueNoise(p / 19.0 + 41.0);
    // Swamps and rivers (mistBiome) are covered almost everywhere.
    float cover = smoothstep(0.4 - 0.3 * mistBiome, 0.72 - 0.2 * mistBiome, banks);
    float top = MIST_BASE + MIST_THICKNESS * (0.25 + 0.75 * banks) + (wisps - 0.5) * 4.0;
    return cover * smoothstep(top, top - 6.0, worldPos.y) * (0.65 + 0.35 * wisps);
}

// Optical depth of the ground mist along a view ray: a few samples over the part of the ray inside the mist layer,
// closer together near the camera. It starts some way out, so it lies in the distance rather than on the screen.
float groundMist(vec3 dir, float dist) {
    const float top = MIST_BASE + MIST_THICKNESS + 2.0;
    float tNear = 0.0;
    float tFar = min(dist, MIST_RANGE);
    if (abs(dir.y) > 1e-4) {
        float t1 = (MIST_BOTTOM - cameraPosition.y) / dir.y;
        float t2 = (top - cameraPosition.y) / dir.y;
        tNear = max(tNear, min(t1, t2));
        tFar = min(tFar, max(t1, t2));
    } else if (cameraPosition.y < MIST_BOTTOM || cameraPosition.y > top) {
        return 0.0;
    }
    if (tFar <= tNear) {
        return 0.0;
    }
    float depth = 0.0;
    float prev = tNear;
    for (int i = 1; i <= MIST_STEPS; i++) {
        float f = float(i) / float(MIST_STEPS);
        float t = mix(tNear, tFar, f * f);
        float mid = (prev + t) * 0.5;
        depth += mistDensity(cameraPosition + dir * mid) * (t - prev) * smoothstep(16.0, 80.0, mid);
        prev = t;
    }
    return depth * 0.012;
}
#endif

// Fog for a surface at playerPos (relative to the camera). Returns the scene colour with fog applied.
vec3 applyFog(vec3 color, vec3 playerPos, float renderDistance) {
    float dist = length(playerPos);
    vec3 dir = playerPos / max(dist, 1e-4);

#ifdef DIM_OVERWORLD
    vec3 sunDir = sunDirection();
    vec3 fogDir = normalize(vec3(dir.x, max(dir.y, 0.04), dir.z));
    // Hazy air spreads the glow around a low sun over a wide span: the fog takes the sky colour over a broad fan of
    // directions, so the land under a setting sun does not get a bright wedge like a reflection.
    const float FAN = 0.6;
    vec3 fanLeft = vec3(fogDir.x * cos(FAN) - fogDir.z * sin(FAN), fogDir.y, fogDir.x * sin(FAN) + fogDir.z * cos(FAN));
    vec3 fanRight = vec3(fogDir.x * cos(FAN) + fogDir.z * sin(FAN), fogDir.y, -fogDir.x * sin(FAN) + fogDir.z * cos(FAN));
    vec3 fogCol = sampleSkyLut(fogDir, sunDir) * 0.6 + (sampleSkyLut(fanLeft, sunDir) + sampleSkyLut(fanRight, sunDir)) * 0.2;
    // The sky right around a low sun is many times brighter and deep gold (forward scattering); fog in that colour
    // turned all land towards the sun into a lemon-yellow or milky wall. The air over the land takes at most a little
    // more than the sky to the sides, and the excess loses its colour.
    vec3 sideLeft = vec3(-fogDir.z, fogDir.y, fogDir.x);
    vec3 sideRight = vec3(fogDir.z, fogDir.y, -fogDir.x);
    vec3 sideCol = (sampleSkyLut(sideLeft, sunDir) + sampleSkyLut(sideRight, sunDir)) * 0.5;
    float fogLum = luminance(fogCol);
    float fogCap = luminance(sideCol) * 1.7;
    if (fogLum > fogCap) {
        float excess = 1.0 - fogCap / fogLum;
        fogCol = mix(fogCol, vec3(fogLum), 0.3 * excess) * (fogCap / fogLum);
    }

    // Indoors and underground the sky colour should not leak in.
    float eyeSky = float(eyeBrightnessSmooth.y) / 240.0;
    vec3 caveCol = vec3(0.006, 0.007, 0.009);
    fogCol = mix(caveCol, fogCol, smoothstep(0.05, 0.6, eyeSky));

    // Thinner air higher up: integrate the exponential height profile along the view ray.
    float y0 = cameraPosition.y - 63.0;
    float falloff = 0.012;
    float dy = playerPos.y * falloff;
    float heightTerm = exp(-max(y0, -40.0) * falloff) * (abs(dy) > 1e-3 ? (1.0 - exp(-dy)) / dy : 1.0);
    float amount = 1.0 - exp(-fogOpticalDepth(dist, rainSheets(dir, dist)) * clamp(heightTerm, 0.02, 4.0));

    // Ground mist (see groundMist) and a thin veil of air lying on the land and water, both gone in rain (rain fog
    // takes over: the layers would only stack into milk).
    float hazeAmount = 0.0;
    float mistAmount = 0.0;
    if (LOW_HAZE > 0.0) {
        vec2 mid = cameraPosition.xz + playerPos.xz * 0.5;
        float banks = 0.7 + 0.6 * valueNoise(mid / 220.0 + frameTimeCounter * vec2(0.004, 0.002));
        float weather = LOW_HAZE * (1.0 - rainStrength);
        float sheltered = smoothstep(0.05, 0.6, eyeSky);
        // Surface haze: a ray crosses about SURFACE_LAYER / |dir.y| blocks of it before reaching the surface, so it
        // gathers on far ground and water seen at a shallow angle and stays thin right around the player and looking
        // down from high up - the hills stand out against it.
        const float SURFACE_LAYER = 12.0;
        float layerPath = min(dist, SURFACE_LAYER / max(abs(dir.y), 0.01));
        float surfaceHaze = layerPath * 0.0008 * weather * banks * smoothstep(16.0, 160.0, dist);
        hazeAmount = (1.0 - exp(-surfaceHaze)) * sheltered;
        // Thickest in the cool morning and evening air, thinnest around noon; swamps and rivers are always misty.
        float humidity = mix(1.3, 0.55, smoothstep(0.15, 0.6, sunDir.y)) * (1.0 + 0.8 * mistBiome) * (1.0 - 0.6 * snowWeather);
        float mistDepth = groundMist(dir, dist) * weather * humidity;
        // Never a solid wall: the land shows through even the thickest bank.
        mistAmount = (1.0 - exp(-mistDepth)) * 0.8 * sheltered;
    }

#ifdef VALLEY_MIST
    // Low morning mist in valleys and over water (rain fog replaces it in rain).
    float mistTime = smoothstep(0.35, 0.05, sunDir.y) * smoothstep(-0.12, 0.02, sunDir.y) * morning();
    float mistStrength = mistTime * 0.9 * (1.0 - rainStrength) * FOG_DENSITY;
    if (mistStrength > 0.0) {
        float mistFalloff = 0.09;
        float mdy = playerPos.y * mistFalloff;
        float mistHeight = exp(-max(cameraPosition.y - 60.0, -10.0) * mistFalloff)
                * (abs(mdy) > 1e-3 ? (1.0 - exp(-mdy)) / mdy : 1.0);
        float mist = 1.0 - exp(-dist * 0.006 * mistStrength * clamp(mistHeight, 0.0, 3.0));
        amount = 1.0 - (1.0 - amount) * (1.0 - mist);
    }
#endif

    // Aerial perspective over the far (LOD) range: a light veil of sky colour that lowers the contrast of distant
    // land, so coarse LODs read as far away instead of as a flat model.
    float aerial = 0.3 * FAR_HAZE * smoothstep(far, far * 6.0, dist) * (1.0 - smoothstep(0.0, 0.6, playerPos.y / max(dist, 1.0)));
    amount = 1.0 - (1.0 - amount) * (1.0 - aerial);

    // Dawn haze: for about an hour around sunrise a soft haze lies over the whole world - thicker in the low land, but
    // reaching up over the hills too - and glows gold towards the rising sun (see the colour below).
    float dawn = dawnHaze() * smoothstep(0.05, 0.6, eyeSky);
    float dawnAmount = 0.0;
    if (dawn > 0.0) {
        const float DAWN_FALLOFF = 0.02;
        float ddy = playerPos.y * DAWN_FALLOFF;
        float dawnHeight = exp(-max(cameraPosition.y - 62.0, -20.0) * DAWN_FALLOFF)
                * (abs(ddy) > 1e-3 ? (1.0 - exp(-ddy)) / ddy : 1.0);
        // A veil, not a wall: about a quarter of the way at 300 blocks over low land.
        dawnAmount = 1.0 - exp(-dist * dawn * FOG_DENSITY * (0.00015 + 0.0006 * clamp(dawnHeight, 0.0, 3.0)));
    }

    // Hide the edge of the loaded world.
    float border = smoothstep(renderDistance * 0.72, renderDistance, dist);
    amount = max(amount, border);
    if (mistAmount > 0.0) {
        // Lit like a cloud: the whole sky and the sun, glowing where the sun shines through it (orange and pink at
        // sunset, silver under the moon).
        float mu = dot(dir, lightDirection());
        vec3 sunLight = directLightColor();
        sunLight = mix(vec3(luminance(sunLight)), sunLight, 0.7);
        vec3 mistCol = (ambientLightColor() * 0.9 + sunLight * (0.3 + miePhase(mu, 0.55))) / PI * 0.75;
        color = mix(color, mistCol, mistAmount * (1.0 - saturate(amount)));
    }
    if (hazeAmount > 0.0) {
        float mu = dot(dir, lightDirection());
        vec3 hazeLight = directLightColor();
        hazeLight = mix(vec3(luminance(hazeLight)), hazeLight, 0.5);
        vec3 hazeCol = fogCol + hazeLight * miePhase(mu, 0.6) * 0.025 * (1.0 - rainStrength);
        color = mix(color, hazeCol, hazeAmount * (1.0 - saturate(amount)));
    }
    if (dawnAmount > 0.0) {
        // Soft peach and rose, glowing a little towards the sun - a bright, saturated glow turned the whole land
        // lemon yellow.
        float mu = dot(dir, sunDir);
        vec3 sunGlow = mix(vec3(luminance(sunDiscColor())), sunDiscColor(), 0.4) * vec3(1.0, 0.88, 0.86);
        // Its brightness comes from the sky to the sides, not from the blinding sky right around the rising sun.
        vec3 dawnCol = mix(fogCol, vec3(luminance(sideCol)) * vec3(1.06, 0.95, 0.97), 0.6)
                + sunGlow * miePhase(mu, 0.6) * 0.01;
        color = mix(color, dawnCol, dawnAmount * (1.0 - saturate(amount)));
    }
    color = mix(color, fogCol, saturate(amount));
#else
    float amount = smoothstep(renderDistance * 0.2, renderDistance, dist);
    color = mix(color, srgbToLinear(fogColor) * 0.6, amount);
#endif
    return color;
}

vec3 applyBlindnessFog(vec3 color, float dist) {
    float b = max(blindness, darknessFactor);
    if (b > 0.0) {
        color *= mix(1.0, exp(-dist * 0.25), b);
    }
    return color;
}

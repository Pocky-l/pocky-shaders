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

    // Low haze: moist air settling over water and in low land. Its density falls off quickly above sea level, so it
    // fills the sea and the valleys between hills while peaks rise out of it, and it builds up with distance (the
    // optical depth along the ray is integrated exactly, like the height fog above). Slow, broad banks keep it from
    // looking like a flat overlay; it is lit like the air around it, glowing towards the sun.
    float hazeAmount = 0.0;
    if (LOW_HAZE > 0.0) {
        const float HAZE_BASE = 62.0;
        const float HAZE_FALLOFF = 0.045;
        float hy0 = cameraPosition.y - HAZE_BASE;
        float hdy = playerPos.y * HAZE_FALLOFF;
        float hazeHeight = exp(-max(hy0, -16.0) * HAZE_FALLOFF) * (abs(hdy) > 1e-3 ? (1.0 - exp(-hdy)) / hdy : 1.0);
        vec2 mid = cameraPosition.xz + playerPos.xz * 0.5;
        float banks = 0.7 + 0.6 * valueNoise(mid / 220.0 + frameTimeCounter * vec2(0.004, 0.002));
        // A touch thicker in the cool morning and evening air, thinner around noon.
        float humidity = mix(1.25, 0.85, smoothstep(0.15, 0.6, sunDir.y));
        // Rain fog takes over in rain: the layers would only stack into milk.
        float weather = LOW_HAZE * banks * humidity * (1.0 - rainStrength);
        float seaHaze = dist * 0.0018 * weather * clamp(hazeHeight, 0.0, 6.0);
        // Surface haze: a thin layer of air lying on the land and water wherever they are (hills included). A ray
        // crosses about SURFACE_LAYER / |dir.y| blocks of it before reaching the surface, so it gathers on far
        // ground and water seen at a shallow angle, and stays thin right around the player and looking down from
        // high up - land and sea fade into a soft veil with distance, the hills stand out against it.
        const float SURFACE_LAYER = 12.0;
        float layerPath = min(dist, SURFACE_LAYER / max(abs(dir.y), 0.01));
        float surfaceHaze = layerPath * 0.0012 * weather * smoothstep(16.0, 160.0, dist);
        hazeAmount = (1.0 - exp(-(seaHaze + surfaceHaze))) * smoothstep(0.05, 0.6, eyeSky);
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

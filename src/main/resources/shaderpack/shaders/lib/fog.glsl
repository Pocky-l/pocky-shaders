// Atmospheric haze, valley mist, rain and cave fog, applied over the finished scene.
// Needs common, atmosphere and sky.

float fogDensity() {
    return FOG_DENSITY * (0.00035 + rainStrength * 0.0045);
}

// Fog for a surface at playerPos (relative to the camera). Returns the scene colour with fog applied.
vec3 applyFog(vec3 color, vec3 playerPos, float renderDistance) {
    float dist = length(playerPos);
    vec3 dir = playerPos / max(dist, 1e-4);

#ifdef DIM_OVERWORLD
    vec3 sunDir = sunDirection();
    vec3 fogDir = normalize(vec3(dir.x, max(dir.y, 0.04), dir.z));
    vec3 fogCol = sampleSkyLut(fogDir, sunDir);

    // Indoors and underground the sky colour should not leak in.
    float eyeSky = float(eyeBrightnessSmooth.y) / 240.0;
    vec3 caveCol = vec3(0.006, 0.007, 0.009);
    fogCol = mix(caveCol, fogCol, smoothstep(0.05, 0.6, eyeSky));

    float density = fogDensity();
    // Thinner air higher up: integrate the exponential height profile along the view ray.
    float y0 = cameraPosition.y - 63.0;
    float falloff = 0.012;
    float dy = playerPos.y * falloff;
    float heightTerm = exp(-max(y0, -40.0) * falloff) * (abs(dy) > 1e-3 ? (1.0 - exp(-dy)) / dy : 1.0);
    float amount = 1.0 - exp(-dist * density * clamp(heightTerm, 0.02, 4.0));

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
        float hazeDensity = 0.0016 * LOW_HAZE * banks * humidity;
        hazeAmount = (1.0 - exp(-dist * hazeDensity * clamp(hazeHeight, 0.0, 6.0))) * smoothstep(0.05, 0.6, eyeSky);
    }

#ifdef VALLEY_MIST
    // Low morning mist in valleys and over water; also in rain.
    float morning = smoothstep(0.35, 0.05, sunDir.y) * smoothstep(-0.12, 0.02, sunDir.y);
    float mistStrength = (morning * 0.9 + rainStrength * 0.5) * FOG_DENSITY;
    if (mistStrength > 0.0) {
        float mistFalloff = 0.09;
        float mdy = playerPos.y * mistFalloff;
        float mistHeight = exp(-max(cameraPosition.y - 60.0, -10.0) * mistFalloff)
                * (abs(mdy) > 1e-3 ? (1.0 - exp(-mdy)) / mdy : 1.0);
        float mist = 1.0 - exp(-dist * 0.012 * mistStrength * clamp(mistHeight, 0.0, 3.0));
        amount = 1.0 - (1.0 - amount) * (1.0 - mist);
    }
#endif

    // Aerial perspective over the far (LOD) range: a light veil of sky colour that lowers the contrast of distant
    // land, so coarse LODs read as far away instead of as a flat model.
    float aerial = 0.3 * FAR_HAZE * smoothstep(far, far * 6.0, dist) * (1.0 - smoothstep(0.0, 0.6, playerPos.y / max(dist, 1.0)));
    amount = 1.0 - (1.0 - amount) * (1.0 - aerial);

    // Hide the edge of the loaded world.
    float border = smoothstep(renderDistance * 0.72, renderDistance, dist);
    amount = max(amount, border);
    if (hazeAmount > 0.0) {
        float mu = dot(dir, lightDirection());
        vec3 hazeCol = fogCol + directLightColor() * miePhase(mu, 0.6) * 0.04 * (1.0 - rainStrength);
        color = mix(color, hazeCol, hazeAmount * (1.0 - saturate(amount)));
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

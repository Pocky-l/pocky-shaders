// Atmospheric haze, valley mist, rain and cave fog, applied over the finished scene.
// Needs common, atmosphere and sky.

float fogDensity() {
    return FOG_DENSITY * (0.0009 + rainStrength * 0.0045);
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

    // Hide the edge of the loaded world.
    float border = smoothstep(renderDistance * 0.72, renderDistance, dist);
    amount = max(amount, border);
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

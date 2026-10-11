// How bright the eye/camera adapts the scene: day, night, storms, twilight and caves. Applied in composite1; the
// lighting also reads it, so light of a fixed brightness (torches) is not amplified by the adaptation.
// Needs common and atmosphere; sky in the overworld.
#ifndef EXPOSURE_GLSL
#define EXPOSURE_GLSL

float sceneExposure() {
    float eyeSky = smoothstep(0.0, 0.7, float(eyeBrightnessSmooth.y) / 240.0);
#ifdef DIM_OVERWORLD
    // Scene brightness key of an average lit surface; 1.75 is a clear midday. A lightning flash is left out, so the
    // eye does not adapt to it and the flash shows. Rain and storms aim lower: they should feel gloomy, not like a
    // grey day brightened up to noon.
    float flash = luminance(flashSkyRadiance()) * OVERCAST_IRRADIANCE;
    float key = (luminance(directLightColor()) * 0.6 + max(luminance(ambientLightColor()) - flash, 0.0)) / PI;
    // Snow keeps the world bright (white ground and air); a thunderstorm in rain is properly dark.
    float target = 1.75 * mix(1.0, 0.62, rainStrength * (1.0 - 0.7 * snowWeather)) * mix(1.0, 0.36, stormDarkness());
    // At sunrise and sunset the eye keeps the bright sky from washing out: deep colours over darker land.
    target *= 1.0 - 0.45 * twilightAmount(sunDirection().y);
    float outdoor = clamp(pow(target / max(key, 1e-3), 0.5), 0.9, 3.2);
#else
    float outdoor = 1.0;
#endif
    // Away from the sky (caves, deep inside buildings) the eye adapts to the dark as well; the Brightness option sets
    // how far.
    // Not too far: lit rock next to a torch or lava stayed washed out, the dark had no depth.
    float cave = mix(1.2, 2.2, screenBrightness);
    return EXPOSURE * mix(cave, outdoor, eyeSky);
}

#endif

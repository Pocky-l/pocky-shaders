// Two flat cloud layers: soft cumulus at low altitude and thin cirrus streaks high above.

const float CLOUD_LOW_ALTITUDE = 250.0;
const float CLOUD_HIGH_ALTITUDE = 900.0;

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
    return saturate(0.42 * CLOUD_COVERAGE + rainStrength * 0.4);
}

float lowCloudDensity(vec2 p, int octaves) {
    vec2 drift = vec2(frameTimeCounter * 1.2, frameTimeCounter * 0.4);
    float shape = cloudFbm((p + drift) * 0.0024, octaves);
    float coverage = cloudCoverage();
    return saturate((shape - (1.0 - coverage)) / max(coverage, 0.05) * 1.6);
}

// rgb: cloud light, a: transmittance of the sky behind them.
vec4 cloudLayers(vec3 dir, vec3 sunDir, vec3 lightDir, vec3 directColor, vec3 ambientColor) {
    vec3 result = vec3(0.0);
    float transmittance = 1.0;
#if CLOUDS > 0
    if (dir.y <= 0.0) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }
    float mu = dot(dir, lightDir);
    float forward = 1.0 + 2.5 * pow(saturate(mu), 10.0);
    vec3 overcast = mix(vec3(1.0), vec3(0.55), rainStrength);

#if CLOUDS > 1
    {
        float t = (CLOUD_HIGH_ALTITUDE - cameraPosition.y) / dir.y;
        vec2 p = cameraPosition.xz + dir.xz * t;
        vec2 drift = vec2(frameTimeCounter * 3.0, 0.0);
        float streak = cloudFbm(vec2((p.x + drift.x) * 0.0006, p.y * 0.0025), 4);
        float d = saturate((streak - 0.52) * 2.2) * 0.45 * (1.0 - rainStrength * 0.6);
        float fade = smoothstep(0.0, 0.12, dir.y);
        float a = d * fade;
        vec3 lit = directColor * 0.08 * forward + ambientColor * 0.35;
        result += lit * a * overcast;
        transmittance *= 1.0 - a;
    }
#endif

    {
        float t = (CLOUD_LOW_ALTITUDE - cameraPosition.y) / dir.y;
        if (t > 0.0) {
            vec2 p = cameraPosition.xz + dir.xz * t;
            int octaves = QUALITY >= 2 ? 6 : 5;
            float d = lowCloudDensity(p, octaves);
            if (d > 0.0) {
                // Light reaching this point from the sun, sampled a little towards it.
                vec2 towards = lightDir.xz / max(lightDir.y, 0.15) * 25.0;
                float d1 = lowCloudDensity(p + towards, 4);
                float d2 = lowCloudDensity(p + towards * 2.5, 3);
                float lightPath = d1 * 1.4 + d2 * 0.9;
                float beer = exp(-lightPath * 2.2);
                float powder = 1.0 - exp(-d * 4.0);
                vec3 sunLit = directColor * beer * powder * forward * 0.22;
                vec3 skyLit = ambientColor * (0.42 - 0.18 * d);
                float fade = smoothstep(0.0, 0.08, dir.y) * exp(-t * 0.00012);
                float a = saturate(d * 1.5) * fade;
                result = mix(result, (sunLit + skyLit) * overcast, a);
                transmittance *= 1.0 - a;
            }
        }
    }
#endif
    return vec4(result, transmittance);
}

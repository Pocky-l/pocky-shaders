// Shadow map: distortion shared by the shadow pass and the lookups, and soft filtered sampling.

const float SHADOW_DISTORTION = 0.85;
const float SHADOW_DEPTH_SCALE = 0.25;

float shadowDistortFactor(vec2 shadowClipXY) {
    return length(shadowClipXY) * SHADOW_DISTORTION + (1.0 - SHADOW_DISTORTION);
}

// Spends more shadow map texels near the player, where the detail is seen.
vec3 distortShadowClip(vec3 shadowClip) {
    return vec3(shadowClip.xy / shadowDistortFactor(shadowClip.xy), shadowClip.z * SHADOW_DEPTH_SCALE);
}

#ifdef SHADOW_LOOKUP

const bool shadowHardwareFiltering = true;
uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;
uniform sampler2D shadowcolor0;

vec2 vogelDisk(int index, int count, float phi) {
    float r = sqrt((float(index) + 0.5) / float(count));
    float theta = float(index) * 2.39996323 + phi;
    return r * vec2(cos(theta), sin(theta));
}

// Sun/moon visibility (rgb: tinted by stained glass and water above). playerPos is relative to the camera.
vec3 shadowVisibility(vec3 playerPos, vec3 worldNormal, float noise, bool foliage) {
    vec3 clip = projectAndDivide(shadowProjection, (shadowModelView * vec4(playerPos, 1.0)).xyz);
    float distort = shadowDistortFactor(clip.xy);
    float texelBlocks = 2.0 * shadowDistance / float(shadowMapResolution);

    // Normal offset, about two shadow texels at this distance; foliage has no reliable normal.
    vec3 offset = foliage ? lightDirection() * 0.12 : worldNormal * (2.0 * texelBlocks * distort + 0.01);
    clip = projectAndDivide(shadowProjection, (shadowModelView * vec4(playerPos + offset, 1.0)).xyz);
    distort = shadowDistortFactor(clip.xy);
    vec3 coord = distortShadowClip(clip) * 0.5 + 0.5;
    if (any(greaterThan(abs(coord.xy - 0.5), vec2(0.5)))) {
        return vec3(1.0);
    }
    coord.z -= 0.00004 * distort;

    float softness = (0.045 * SHADOW_SOFTNESS + 0.5 * texelBlocks) / (2.0 * shadowDistance) / distort;
    float phi = noise * 2.0 * PI;
    float solid = 0.0;
    float total = 0.0;
    int samples = length(playerPos) > DETAIL_DISTANCE ? max(SHADOW_SAMPLES / 2, 2) : SHADOW_SAMPLES;
    for (int i = 0; i < samples; i++) {
        vec3 p = vec3(coord.xy + vogelDisk(i, samples, phi) * softness, coord.z);
        solid += texture(shadowtex1, p);
#ifdef COLORED_SHADOWS
        total += texture(shadowtex0, p);
#endif
    }
    solid /= float(samples);
#ifdef COLORED_SHADOWS
    total /= float(samples);
    if (solid - total > 0.01) {
        // Light passing through translucent blocks: shadowcolor0 holds their tint (already 1 where nothing is).
        vec4 tint = texture(shadowcolor0, coord.xy);
        return mix(vec3(total), tint.rgb * solid, saturate((solid - total) / max(solid, 1e-3)));
    }
    return vec3(total);
#else
    return vec3(solid);
#endif
}

#endif

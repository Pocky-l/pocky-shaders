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

// Tint of the light at a shadow map position from sample totals: solid = share past opaque casters (shadowtex1),
// total = share past every caster (shadowtex0, translucent ones too).
vec3 shadowTint(vec2 coord, float solid, float total) {
#ifdef COLORED_SHADOWS
    if (solid - total > 0.01) {
        // Light passing through translucent blocks: shadowcolor0 holds their tint (already 1 where nothing is).
        vec4 tint = texture(shadowcolor0, coord);
        return mix(vec3(total), tint.rgb * solid, saturate((solid - total) / max(solid, 1e-3)));
    }
    return vec3(total);
#else
    return vec3(solid);
#endif
}

// Whether the sun reaches a point in the air or water (opaque casters only, one hardware-filtered lookup, no normal
// offset): for the light scattered along view rays. 1 outside the shadow map.
float opaqueShadowAt(vec3 playerPos) {
    vec3 clip = projectAndDivide(shadowProjection, (shadowModelView * vec4(playerPos, 1.0)).xyz);
    vec3 coord = distortShadowClip(clip) * 0.5 + 0.5;
    if (any(greaterThan(abs(coord.xy - 0.5), vec2(0.5)))) {
        return 1.0;
    }
    return texture(shadowtex1, vec3(coord.xy, coord.z - 0.0001));
}

// Sun/moon visibility (rgb: tinted by stained glass and water above). playerPos is relative to the camera.
// pixelLock: playerPos is the centre of a texture texel (pixel shadows on terrain, see texelCentre in gbuffers_lit).
vec3 shadowVisibility(vec3 playerPos, vec3 worldNormal, float noise, bool foliage, bool pixelLock) {
    float dist = length(playerPos);
    vec3 clip = projectAndDivide(shadowProjection, (shadowModelView * vec4(playerPos, 1.0)).xyz);
    float distort = shadowDistortFactor(clip.xy);
    float texelBlocks = 2.0 * shadowDistance / float(shadowMapResolution);

    // Normal offset, about two shadow texels at this distance; foliage has no reliable normal and waves: offset
    // towards the light far enough that a swaying plant does not keep shadowing itself (that made grass blink).
    vec3 offset = foliage ? lightDirection() * 0.3 : worldNormal * (2.0 * texelBlocks * distort + 0.01);
    clip = projectAndDivide(shadowProjection, (shadowModelView * vec4(playerPos + offset, 1.0)).xyz);
    distort = shadowDistortFactor(clip.xy);
    vec3 coord = distortShadowClip(clip) * 0.5 + 0.5;
    if (any(greaterThan(abs(coord.xy - 0.5), vec2(0.5)))) {
        return vec3(1.0);
    }
    coord.z -= 0.00004 * distort;
    float edge = smoothstep(0.65, 0.95, max(abs(clip.x), abs(clip.y)));

#if SHADOW_STYLE == 1
    // Crisp edges from four hardware-filtered lookups: up close half a shadow texel apart, sharpened into a cartoon
    // edge (a single lookup flickered while walking, as the map slides under the world); further out a texel and a
    // half apart, so the coarser shadow texels do not show as stairs. Opaque casters are tested first and the
    // translucent pass is read only where they let light through.
    bool near = dist < 48.0 && pixelLock;
    float radius = (near ? 0.5 : 0.75) / float(shadowMapResolution);
    float solid = 0.0;
    for (int i = 0; i < 4; i++) {
        vec2 o = vec2((i & 1) == 0 ? -radius : radius, (i & 2) == 0 ? -radius : radius);
        solid += texture(shadowtex1, vec3(coord.xy + o, coord.z));
    }
    solid *= 0.25;
    if (solid <= 0.0) {
        return vec3(edge);
    }
    float total = solid;
#ifdef COLORED_SHADOWS
    total = 0.0;
    for (int i = 0; i < 4; i++) {
        vec2 o = vec2((i & 1) == 0 ? -radius : radius, (i & 2) == 0 ? -radius : radius);
        total += texture(shadowtex0, vec3(coord.xy + o, coord.z));
    }
    total *= 0.25;
#endif
    if (near) {
        solid = smoothstep(0.15, 0.85, solid);
        total = smoothstep(0.15, 0.85, total);
    }
    return mix(shadowTint(coord.xy, solid, total), vec3(1.0), edge);
#else
    float softness = (0.045 * SHADOW_SOFTNESS + 0.5 * texelBlocks) / (2.0 * shadowDistance) / distort;
    softness *= sunDirection().y < 0.0 ? 2.2 : 1.0;
    // A fixed sample pattern: per-pixel random rotation looked like grain without temporal filtering.
    float phi = 0.0;
    int samples = dist > DETAIL_DISTANCE ? max(SHADOW_SAMPLES / 2, 2) : SHADOW_SAMPLES;
    float solid = 0.0;
    for (int i = 0; i < samples; i++) {
        solid += texture(shadowtex1, vec3(coord.xy + vogelDisk(i, samples, phi) * softness, coord.z));
    }
    solid /= float(samples);
    if (solid <= 0.0) {
        // Fully behind opaque casters: the translucent pass cannot add anything.
        return vec3(edge);
    }
    float total = solid;
#ifdef COLORED_SHADOWS
    total = 0.0;
    for (int i = 0; i < samples; i++) {
        total += texture(shadowtex0, vec3(coord.xy + vogelDisk(i, samples, phi) * softness, coord.z));
    }
    total /= float(samples);
#endif
    return mix(shadowTint(coord.xy, solid, total), vec3(1.0), edge);
#endif
}

#endif

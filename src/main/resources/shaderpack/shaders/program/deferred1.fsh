// Applies ambient occlusion and far (screen-space) shadows to the opaque scene, draws the sky behind it and
// volumetric clouds over both.

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#ifdef DIM_OVERWORLD
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
#define CLOUD_LOOKUP
#include "/lib/clouds.glsl"
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform mat4 dhProjectionInverse;
#endif

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outColor;

float blurredAo(float depth) {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    float center = linearizeDepth(depth);
    float sum = 0.0;
    float weight = 0.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 uv = texcoord + vec2(x, y) * px * 1.5;
            float d = linearizeDepth(texture(depthtex0, uv).r);
            float w = exp(-abs(d - center) / max(center * 0.03, 0.05));
            sum += texture(colortex6, uv).r * w;
            weight += w;
        }
    }
    return sum / max(weight, 1e-4);
}

// View-space depth (negative z) of the nearest opaque surface, vanilla or DH; very far when there is none.
float sceneViewZ(vec2 uv) {
    float d = texture(depthtex0, uv).r;
    if (d < 1.0) {
        return screenToView(vec3(uv, d)).z;
    }
#ifdef DISTANT_HORIZONS
    float dh = texture(dhDepthTex0, uv).r;
    if (dh < 1.0) {
        return projectAndDivide(dhProjectionInverse, vec3(uv, dh) * 2.0 - 1.0).z;
    }
#endif
    return -1e6;
}

#if defined SHADOWS && defined DIM_OVERWORLD
// Simplified shadows beyond the shadow map: march towards the light through the depth buffer.
// Catches hills, trees and buildings on screen, which is what makes distant land look solid.
float screenSpaceShadow(vec3 viewPos, vec3 viewLight, float noise) {
    // World-space steps (not scaled by the distance to the camera), so the shadows stay put when the camera moves.
    float stepLen = 0.6;
    vec3 p = viewPos + viewLight * stepLen * noise;
    // Fewer, longer steps on lower presets; the growth keeps the reach at about 200 blocks.
    const int STEPS = SS_SHADOW_STEPS;
    for (int i = 0; i < STEPS; i++) {
        p += viewLight * stepLen;
        stepLen *= SS_SHADOW_GROWTH;
        if (p.z > -near) {
            break;
        }
        vec4 clip = gbufferProjection * vec4(p, 1.0);
        vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
        if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
            break;
        }
        float sceneZ = sceneViewZ(uv);
        float diff = sceneZ - p.z;
        // Something is in front of the ray point, and not so far in front that it is a separate object.
        if (diff > 0.05 * stepLen && diff < stepLen * 3.0 + 1.5) {
            vec2 edge = smoothstep(vec2(0.0), vec2(0.05), uv) * smoothstep(vec2(1.0), vec2(0.95), uv);
            return edge.x * edge.y;
        }
    }
    return 0.0;
}
#endif

void main() {
    vec4 scene = texture(colortex0, texcoord);
    float depth = texture(depthtex0, texcoord).r;
    bool sky = depth >= 1.0;
#ifdef DISTANT_HORIZONS
    float dhDepth = texture(dhDepthTex0, texcoord).r;
    sky = sky && dhDepth >= 1.0;
#endif

    vec3 viewPos = screenToView(vec3(texcoord, sky ? 1.0 : depth));
#ifdef DISTANT_HORIZONS
    if (!sky && depth >= 1.0) {
        viewPos = projectAndDivide(dhProjectionInverse, vec3(texcoord, dhDepth) * 2.0 - 1.0);
    }
#endif

    vec3 color = scene.rgb;
    if (!sky) {
        vec4 data = texture(colortex1, texcoord);
        float encoded = data.z * 65535.0;
        int material = int(floor(encoded / 256.0 + 1e-3));
#ifdef SSAO
        if (depth < 1.0 && material != MAT_HAND) {
            // Under an overcast sky shapes come only from occlusion: a bit more of it in rain.
            color *= pow(blurredAo(depth), 1.0 + 0.5 * rainStrength);
        }
#endif
#if defined SHADOWS && defined DIM_OVERWORLD
        // Beyond the shadow map, darken the share of the colour that comes from direct light.
        vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
        vec3 shadowClip = projectAndDivide(shadowProjection, (shadowModelView * vec4(playerPos, 1.0)).xyz);
        float farWeight = smoothstep(0.65, 0.95, max(abs(shadowClip.x), abs(shadowClip.y)));
        vec3 viewLight = normalize(shadowLightPosition);
        if (farWeight > 0.0 && material != MAT_HAND) {
            float occluded = screenSpaceShadow(viewPos, viewLight, 0.5);
            if (occluded > 0.0) {
                vec3 n = decodeNormal(data.xy);
                float skyLight = mod(encoded, 256.0) / 255.0;
                float ambient = luminance(ambientLightColor()) * skyLight * skyLight * 0.85 + AMBIENT_MIN;
                float direct = luminance(directLightColor()) * saturate(dot(n, viewLight)) * smoothstep(0.1, 0.45, skyLight);
                float ambientShare = ambient / max(ambient + direct, 1e-4);
                color *= mix(1.0, ambientShare, occluded * farWeight);
            }
        }
#endif
    }

#ifdef DIM_OVERWORLD
    vec3 dir = normalize(mat3(gbufferModelViewInverse) * viewPos);
    float sceneDist = sky ? 1e6 : length(viewPos);
    vec3 sunDir = sunDirection();

    if (sky) {
        // Atmosphere behind the vanilla sun, moon and stars (drawn additively into colortex0).
        color = sampleSkyLut(dir, sunDir) + scene.rgb * (1.0 - rainStrength);
    }

#if CLOUDS > 0
    if (sky || cameraPosition.y > CLOUD_BOTTOM - 40.0 || dir.y > 0.0) {
        vec4 clouds = cloudLayers(dir, sceneDist, lightDirection(), directLightColor(), ambientLightColor(), CLOUD_STEPS,
                dither(gl_FragCoord.xy));

        color = color * clouds.a + clouds.rgb;
    }
#endif
#endif
    outColor = vec4(color, 1.0);
}

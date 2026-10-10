// Water (refraction, absorption, reflections), translucent blocks, fog, underwater view and light shafts.

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#include "/lib/tonemap.glsl"
#ifdef DIM_OVERWORLD
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
#define CLOUD_LOOKUP
#include "/lib/clouds.glsl"
#endif
#include "/lib/lighting.glsl"
#include "/lib/fog.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform sampler2D dhDepthTex1;
uniform mat4 dhProjectionInverse;
uniform int dhRenderDistance;
#endif

in vec2 texcoord;

/* RENDERTARGETS: 0,5 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outBloom;

// View position of the nearest surface (opaque only when opaqueOnly); DH terrain fills in beyond vanilla chunks.
vec3 viewPosition(vec2 uv, bool opaqueOnly) {
    float depth = opaqueOnly ? texture(depthtex1, uv).r : texture(depthtex0, uv).r;
#ifdef DISTANT_HORIZONS
    if (depth >= 1.0) {
        float d = opaqueOnly ? texture(dhDepthTex1, uv).r : texture(dhDepthTex0, uv).r;
        if (d < 1.0) {
            return projectAndDivide(dhProjectionInverse, vec3(uv, d) * 2.0 - 1.0);
        }
    }
#endif
    return screenToView(vec3(uv, depth));
}

bool isSkyAt(vec2 uv) {
    bool sky = texture(depthtex0, uv).r >= 1.0;
#ifdef DISTANT_HORIZONS
    sky = sky && texture(dhDepthTex0, uv).r >= 1.0;
#endif
    return sky;
}

bool isOpaqueSkyAt(vec2 uv) {
    bool sky = texture(depthtex1, uv).r >= 1.0;
#ifdef DISTANT_HORIZONS
    sky = sky && texture(dhDepthTex1, uv).r >= 1.0;
#endif
    return sky;
}

vec4 unpackWater(float encoded) {
    float v = floor(encoded * 65535.0 + 0.5);
    vec4 q = vec4(floor(v / 4096.0), mod(floor(v / 256.0), 16.0), mod(floor(v / 16.0), 16.0), mod(v, 16.0));
    return q / 15.0;
}

#if WATER_REFLECTIONS == 2 && SSR_STEPS > 0
// Screen-space reflection against the opaque depth; returns rgb + hit confidence.
vec4 screenReflection(vec3 viewPos, vec3 viewDir, float noise) {
    vec3 rayStep = viewDir * (0.6 + 0.04 * length(viewPos));
    vec3 pos = viewPos + rayStep * noise;
    for (int i = 0; i < SSR_STEPS; i++) {
        pos += rayStep;
        rayStep *= 1.12;
        vec3 screen = viewToScreen(pos);
        if (any(lessThan(screen.xy, vec2(0.0))) || any(greaterThan(screen.xy, vec2(1.0))) || pos.z > -near) {
            break;
        }
        float sceneDepth = texture(depthtex1, screen.xy).r;
        if (sceneDepth >= 1.0) {
            continue;
        }
        float sceneZ = screenToView(vec3(screen.xy, sceneDepth)).z;
        float diff = sceneZ - pos.z;
        if (diff > 0.0 && diff < length(rayStep) * 2.5) {
            // Refine between the last two steps.
            vec3 a = pos - rayStep;
            vec3 b = pos;
            for (int j = 0; j < 4; j++) {
                vec3 m = (a + b) * 0.5;
                vec3 ms = viewToScreen(m);
                float mz = screenToView(vec3(ms.xy, texture(depthtex1, ms.xy).r)).z;
                if (mz > m.z) {
                    b = m;
                } else {
                    a = m;
                }
            }
            vec2 uv = viewToScreen(b).xy;
            vec2 edge = smoothstep(vec2(0.0), vec2(0.08), uv) * smoothstep(vec2(1.0), vec2(0.92), uv);
            return vec4(texture(colortex0, uv).rgb, edge.x * edge.y);
        }
    }
    return vec4(0.0);
}
#endif

vec3 shadeWater(vec3 color, vec3 surfaceView, vec4 waterData, vec2 uv, float noise) {
    vec3 worldNormal = decodeNormal(waterData.xy);
    vec4 tintSky = unpackWater(waterData.z);
    vec3 tint = tintSky.rgb;
    float sky = tintSky.a;
    vec3 viewNormal = mat3(gbufferModelView) * worldNormal;
    vec3 viewDir = normalize(surfaceView);
    vec3 surfacePlayer = mat3(gbufferModelViewInverse) * surfaceView;

    // Refraction: look up the scene below with an offset from the waves, unless that lands in front of the water.
    vec2 refractUv = uv;
#ifdef WATER_REFRACTION
    if (isEyeInWater == 0) {
        float behind = length(viewPosition(uv, true) - surfaceView);
        vec3 flatNormal = mat3(gbufferModelView) * vec3(0.0, 1.0, 0.0);
        vec2 offset = (viewNormal.xy - flatNormal.xy) * 0.06 * saturate(behind * 0.25);
        vec2 candidate = uv + offset / max(1.0, -surfaceView.z * 0.08);
        if (texture(depthtex1, candidate).r > texture(depthtex0, uv).r) {
            refractUv = candidate;
        }
    }
#endif
    vec3 below = texture(colortex0, refractUv).rgb;
    vec3 floorView = viewPosition(refractUv, true);
    float waterDist = isOpaqueSkyAt(refractUv) && isEyeInWater == 0 ? 64.0 : length(floorView - surfaceView);
#ifdef DISTANT_HORIZONS
    // DH water: LOD sea floors are coarse and its depth is unreliable; never let it look shallower than a few blocks.
    if (texture(depthtex0, uv).r >= 1.0) {
        waterDist = max(waterDist, 4.0);
    }
#endif

    vec3 result;
    if (isEyeInWater == 1) {
        // Seen from below: the world above, dimmed by the surface.
        result = below * 0.9;
    } else {
        // Absorption (reds go first) and in-scattered light colour the water with depth.
        vec3 absorb = (vec3(0.38, 0.09, 0.07) + (1.0 - tint) * 0.12) / WATER_CLARITY;
        vec3 transmit = exp(-absorb * waterDist);
#ifdef DIM_OVERWORLD
        vec3 light = (ambientLightColor() * 0.6 + directLightColor() * 0.15) / PI * sky * sky;
#else
        vec3 light = vec3(0.04);
#endif
        light += blockLightColor() * 0.02;
        vec3 scatterColor = light * mix(vec3(0.05, 0.22, 0.26), tint * vec3(0.3, 0.5, 0.55), 0.5);
        result = below * transmit + scatterColor * (1.0 - exp(-waterDist * 0.4 / WATER_CLARITY));
        result *= mix(0.7, 1.0, smoothstep(0.1, 0.8, waterDist));
    }

#if WATER_REFLECTIONS > 0
    if (isEyeInWater == 0) {
        vec3 reflectView = reflect(viewDir, viewNormal);
        // A thin water film on dark ground reads mostly as reflection: shallow water gets a stronger sheen.
        float shallow = 1.0 - smoothstep(0.1, 0.8, waterDist);
        float fresnel = fresnelSchlick(dot(-viewDir, viewNormal), mix(0.02, 0.05, shallow));
        // Grazing views of far water would turn it into a white mirror of the sky; keep its colour like near water.
        fresnel *= mix(1.0, 0.5, smoothstep(80.0, 400.0, length(surfaceView)));
        vec3 reflection = vec3(0.0);
#ifdef DIM_OVERWORLD
        vec3 reflectWorld = mat3(gbufferModelViewInverse) * reflectView;
        reflectWorld.y = abs(reflectWorld.y);
        vec3 skyRefl = sampleSkyLut(reflectWorld, sunDirection());
#if CLOUDS > 0 && QUALITY > 0
        vec4 clouds = cloudLayersFrom(surfacePlayer + cameraPosition, reflectWorld, 1e6, lightDirection(), directLightColor(),
                ambientLightColor(), CLOUD_STEPS);
        skyRefl = skyRefl * clouds.a + clouds.rgb;
#endif
        // An overcast night sky still glows a little in reflections.
        skyRefl = max(skyRefl, ambientLightColor() / PI * 0.5);
        reflection = skyRefl * smoothstep(0.3, 0.85, sky);
#endif
#if WATER_REFLECTIONS == 2 && SSR_STEPS > 0
        vec4 ssr = screenReflection(surfaceView, reflectView, noise);
        reflection = mix(reflection, ssr.rgb, ssr.a);
#endif
        result = mix(result, reflection, fresnel);
#ifdef DIM_OVERWORLD
        // Sun glitter.
        vec3 l = lightDirection();
        float spec = ggxSpecular(worldNormal, -normalize(surfacePlayer), l, 0.06);
        result += directLightColor() * spec * smoothstep(0.5, 0.9, sky) * cloudShadow(surfacePlayer, l);
#endif
    }
#endif
    return result;
}

vec3 lightShafts(vec2 uv, float noise) {
#if defined LIGHT_SHAFTS && defined DIM_OVERWORLD
    if (shadowLightPosition.z >= 0.0 || isEyeInWater != 0) {
        return vec3(0.0);
    }
    vec2 lightUv = viewToScreen(shadowLightPosition).xy;
    vec3 viewDir = normalize(screenToView(vec3(uv, 1.0)));
    float facing = pow(saturate(dot(viewDir, normalize(shadowLightPosition))), 4.0);
    if (facing < 0.002) {
        return vec3(0.0);
    }
    const int STEPS = 16;
    vec2 delta = (lightUv - uv) / float(STEPS);
    vec2 p = uv + delta * noise;
    float lit = 0.0;
    for (int i = 0; i < STEPS; i++) {
        if (all(greaterThanEqual(p, vec2(0.0))) && all(lessThanEqual(p, vec2(1.0))) && isSkyAt(p)) {
            lit += saturate(luminance(texture(colortex0, p).rgb) * 0.8);
        }
        p += delta;
    }
    lit /= float(STEPS);
    float eyeSky = float(eyeBrightnessSmooth.y) / 240.0;
    return directLightColor() * lit * facing * 0.035 * LIGHT_SHAFT_STRENGTH * eyeSky * (1.0 - rainStrength * 0.8);
#else
    return vec3(0.0);
#endif
}

void main() {
    vec3 color = texture(colortex0, texcoord).rgb;
    float noise = dither(gl_FragCoord.xy);

    vec3 surfaceView = viewPosition(texcoord, false);
    bool sky = isSkyAt(texcoord);

    vec4 waterData = texture(colortex4, texcoord);
    if (waterData.w > 0.5) {
        color = shadeWater(color, surfaceView, waterData, texcoord, noise);
    }

    vec4 translucent = texture(colortex3, texcoord);
    color = color * (1.0 - translucent.a) + translucent.rgb;

    vec3 playerPos = mat3(gbufferModelViewInverse) * surfaceView;
    float dist = length(playerPos);
    if (isEyeInWater == 1) {
        // Underwater: light fades with distance, blue-green.
        float d = sky ? 48.0 : min(dist, 48.0);
#ifdef DIM_OVERWORLD
        vec3 light = (ambientLightColor() * 0.6 + directLightColor() * 0.15) / PI * (float(eyeBrightnessSmooth.y) / 240.0);
#else
        vec3 light = vec3(0.04);
#endif
        vec3 fogCol = light * vec3(0.05, 0.22, 0.26) + vec3(0.002, 0.006, 0.008);
        color = color * exp(-vec3(0.38, 0.09, 0.07) / WATER_CLARITY * d) + fogCol * (1.0 - exp(-d * 0.12 / WATER_CLARITY));
    } else if (isEyeInWater == 2) {
        color = mix(color, vec3(1.0, 0.3, 0.05) * 2.0, 1.0 - exp(-dist * 0.9));
    } else if (isEyeInWater == 3) {
        color = mix(color, vec3(0.75, 0.82, 0.9), 1.0 - exp(-dist * 0.7));
    } else if (!sky) {
#ifdef DISTANT_HORIZONS
        float renderDistance = max(far, float(dhRenderDistance));
#else
        float renderDistance = far;
#endif
        color = applyFog(color, playerPos, renderDistance);
    }
    color = applyBlindnessFog(color, sky ? 1000.0 : dist);
    color += lightShafts(texcoord, noise);

    outColor = vec4(color, 1.0);
    outBloom = vec4(color, 1.0);
}

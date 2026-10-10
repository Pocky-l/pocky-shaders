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
#include "/lib/water.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex2;
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

// normalSpread: screen-space change of the water normal per pixel (taken outside any branch).
vec3 shadeWater(vec3 color, vec3 surfaceView, vec4 waterData, vec2 uv, float normalSpread) {
    vec3 worldNormal = decodeWaterNormal(waterData.xy);
    float runningFoam = decodeWaterFoam(waterData.xy);
    vec4 tintSky = unpackWater(waterData.z);
    vec3 tint = tintSky.rgb;
    float sky = tintSky.a;
    vec3 viewNormal = mat3(gbufferModelView) * worldNormal;
    vec3 viewDir = normalize(surfaceView);
    vec3 surfacePlayer = mat3(gbufferModelViewInverse) * surfaceView;
    // Rain puddles (Petrichor draws them as water a hair above the ground; real water is at least 0.89 blocks deep):
    // still water with rings from the drops instead of waves, no caustics or foam.
    bool puddle = false;
    if (isEyeInWater == 0 && !isOpaqueSkyAt(uv)) {
        vec3 groundBelow = mat3(gbufferModelViewInverse) * viewPosition(uv, true);
        puddle = surfacePlayer.y - groundBelow.y < 0.25;
    }
    if (puddle) {
        worldNormal = puddleNormal((surfacePlayer + cameraPosition).xz, length(surfacePlayer), sky);
        viewNormal = mat3(gbufferModelView) * worldNormal;
    }

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
    bool floorIsSky = isOpaqueSkyAt(refractUv);
    float waterDist = floorIsSky && isEyeInWater == 0 ? 64.0 : length(floorView - surfaceView);
    float surfaceDist = length(surfaceView);
    vec3 floorPlayer = mat3(gbufferModelViewInverse) * floorView;
    // Vertical water depth under this pixel (caustics, foam).
    float depthBelow = floorIsSky ? 64.0 : surfacePlayer.y - floorPlayer.y;
#ifdef DISTANT_HORIZONS
    // DH water: LOD sea floors are coarse and its depth is unreliable; never let it look shallower than a few blocks.
    // Vanilla water eases into the same floor towards the border, so the switch to LODs does not show as a line.
    float minDepth = texture(depthtex0, uv).r >= 1.0 ? 4.0 : 4.0 * smoothstep(far * 0.7, far, surfaceDist);
    waterDist = max(waterDist, minDepth);
#endif

#if defined WATER_CAUSTICS && defined DIM_OVERWORLD
    // Sunlight focused by the waves draws moving bright veins on a shallow, sunlit bottom.
    if (isEyeInWater == 0 && !floorIsSky && !puddle) {
        float fade = smoothstep(0.2, 0.7, depthBelow) * (1.0 - smoothstep(3.0, 9.0, depthBelow))
                * (1.0 - smoothstep(32.0, 96.0, length(floorPlayer)));
        if (fade > 0.0) {
            vec3 l = lightDirection();
            // The pattern belongs to the surface the light came through.
            vec2 p = (floorPlayer + cameraPosition).xz + l.xz / max(l.y, 0.25) * depthBelow;
            float caustics = waterCaustics(p) * fade * smoothstep(0.1, 0.35, l.y) * (1.0 - rainStrength)
                    * smoothstep(0.5, 0.9, sky) * cloudShadow(surfacePlayer, l);
            below *= 1.0 + caustics * 1.5;
        }
    }
#endif

    vec3 result;
    if (isEyeInWater == 1) {
        // Seen from below: the world above, dimmed by the surface.
        result = below * 0.9;
    } else {
        // Absorption (reds go first) and in-scattered light colour the water with depth.
        vec3 absorb = (vec3(0.40, 0.11, 0.08) + (1.0 - tint) * 0.12) / WATER_CLARITY;
        vec3 transmit = exp(-absorb * waterDist);
#ifdef DIM_OVERWORLD
        vec3 light = (ambientLightColor() * 0.6 + directLightColor() * 0.15) / PI * sky * sky;
#else
        vec3 light = vec3(0.04);
#endif
        light += blockLightColor() * 0.02;
        // Shallows glow turquoise over the bottom, open deep water turns a darker, richer blue.
        vec3 shallowScatter = mix(vec3(0.05, 0.22, 0.26), tint * vec3(0.3, 0.5, 0.55), 0.5);
        vec3 deepScatter = mix(vec3(0.02, 0.10, 0.22), tint * vec3(0.15, 0.3, 0.5), 0.5);
        vec3 scatterColor = light * mix(shallowScatter, deepScatter, smoothstep(3.0, 18.0, waterDist));
        // Churned storm water turns slate grey-green.
        scatterColor = mix(scatterColor, vec3(luminance(scatterColor)) * vec3(0.8, 1.0, 1.0), 0.5 * thunderStrength);
        result = below * transmit + scatterColor * (1.0 - exp(-waterDist * 0.4 / WATER_CLARITY));
        result *= mix(0.7, 1.0, smoothstep(0.1, 0.8, waterDist));
    }

#if WATER_REFLECTIONS > 0
    if (isEyeInWater == 0) {
        vec3 reflectView = reflect(viewDir, viewNormal);
        // A thin water film on dark ground reads mostly as reflection: shallow water gets a stronger sheen.
        float shallow = 1.0 - smoothstep(0.1, 0.8, waterDist);
        float fresnel = 0.07 + 0.55 * fresnelSchlick(dot(-viewDir, viewNormal), mix(0.02, 0.05, shallow));
        // Grazing views of far water would turn it into a white mirror of the sky; keep its colour like near water.
        fresnel *= mix(1.0, 0.7, smoothstep(80.0, 400.0, surfaceDist));
        vec3 reflection = vec3(0.0);
#ifdef DIM_OVERWORLD
        vec3 reflectWorld = mat3(gbufferModelViewInverse) * reflectView;
        reflectWorld.y = abs(reflectWorld.y);
        vec3 skyRefl = sampleSkyLut(reflectWorld, sunDirection());
#if CLOUDS > 0 && QUALITY > 0
        vec4 clouds = cloudReflection(surfacePlayer + cameraPosition, reflectWorld, lightDirection(), directLightColor(),
                ambientLightColor(), skyRefl);
        skyRefl = skyRefl * clouds.a + clouds.rgb;
#endif
        // An overcast night sky still glows a little in reflections.
        skyRefl = max(skyRefl, ambientLightColor() / PI * 0.5);
        reflection = skyRefl * smoothstep(0.3, 0.85, sky);
#endif
#if WATER_REFLECTIONS == 2 && SSR_STEPS > 0
        // Fixed ray offset: a per-pixel one only sparkles without temporal filtering.
        vec4 ssr = screenReflection(surfaceView, reflectView, 0.5);
        reflection = mix(reflection, ssr.rgb, ssr.a);
#endif
        result = mix(result, reflection, fresnel);
#ifdef DIM_OVERWORLD
        // Sun glitter. Waves finer than a pixel and distant water widen the highlight instead of breaking it into
        // single sparkling pixels; the peak is capped for the same reason.
        vec3 l = lightDirection();
        float roughness = 0.06 + min(normalSpread * 1.5, 0.2) + 0.06 * smoothstep(48.0, 400.0, surfaceDist);
        float spec = min(ggxSpecular(worldNormal, -normalize(surfacePlayer), l, roughness), 6.0);
        result += directLightColor() * spec * smoothstep(0.5, 0.9, sky) * cloudShadow(surfacePlayer, l);
#endif
    }
#endif

    if (runningFoam > 0.0 && isEyeInWater == 0) {
        // Streams and waterfalls: white, broken water lit by the sky and the sun.
#ifdef DIM_OVERWORLD
        vec3 foamLight = (ambientLightColor() + directLightColor() * saturate(dot(worldNormal, lightDirection()))) / PI * sky;
#else
        vec3 foamLight = vec3(0.05);
#endif
        foamLight += blockLightColor() * 0.02;
        result = mix(result, foamLight * 0.85, runningFoam * 0.75);
    }

#ifdef WATER_FOAM
    // Broken foam where the water is barely a block deep (puddle films stay clear), whitecaps on open water in a storm.
    if (isEyeInWater == 0 && worldNormal.y > 0.5 && !puddle) {
        float amount = smoothstep(0.12, 0.3, depthBelow) * (1.0 - smoothstep(0.6, 1.4, depthBelow))
                * (1.0 - smoothstep(48.0, 96.0, surfaceDist));
        float whitecaps = depthBelow > 2.0 ? waterWhitecaps((surfacePlayer + cameraPosition).xz) * 0.55
                * (1.0 - smoothstep(160.0, 320.0, surfaceDist)) : 0.0;
        if (amount > 0.0 || whitecaps > 0.0) {
#ifdef DIM_OVERWORLD
            vec3 foamLight = (ambientLightColor() + directLightColor() * saturate(lightDirection().y)) / PI * sky;
#else
            vec3 foamLight = vec3(0.05);
#endif
            float foam = max(waterFoam((surfacePlayer + cameraPosition).xz) * amount * 0.35, whitecaps);
            result = mix(result, foamLight * 0.8, foam);
        }
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
    const int STEPS = LIGHT_SHAFT_STEPS;
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

    // colortex0 already holds the clouds deferred1 drew in front of the opaque scene. Water, glass and fog belong to
    // the part of the pixel the clouds let through (seen from above, the sea and the land are below the clouds).
    float cloudTransmittance = texture(colortex2, texcoord).r;
    vec3 withClouds = color;

    vec4 waterData = texture(colortex4, texcoord);
    float normalSpread = length(fwidth(decodeWaterNormal(waterData.xy)));
    if (waterData.w > 0.5) {
        color = shadeWater(color, surfaceView, waterData, texcoord, normalSpread);
    }

    vec4 translucent = texture(colortex3, texcoord);
    color = color * (1.0 - translucent.a) + translucent.rgb;
    color = mix(withClouds, color, cloudTransmittance);

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
        color = mix(color, applyFog(color, playerPos, renderDistance), cloudTransmittance);
    }
    color = applyBlindnessFog(color, sky ? 1000.0 : dist);
    color += lightShafts(texcoord, noise);

#if DEBUG_VIEW == 1
    // Who drew each pixel: red = vanilla chunks, blue = Distant Horizons LODs, green = water shaded here.
    // Vanilla land red, vanilla water yellow, DH land blue, DH water cyan; magenta / white = vanilla and DH overlap.
    float fromVanilla = texture(depthtex0, texcoord).r < 1.0 ? 1.0 : 0.0;
    float fromDh = 0.0;
#ifdef DISTANT_HORIZONS
    fromDh = texture(dhDepthTex0, texcoord).r < 1.0 || texture(dhDepthTex1, texcoord).r < 1.0 ? 1.0 : 0.0;
#endif
    float isWater = waterData.w > 0.5 ? 1.0 : 0.0;
    color = vec3(luminance(color) * 0.3) + vec3(fromVanilla, isWater, fromDh) * 0.5;
#endif

    outColor = vec4(color, 1.0);
    outBloom = vec4(color, 1.0);
}

// Forward shading used by all lit gbuffers programs. Needs common, atmosphere, sky and (in the overworld) shadow.

#include "/lib/exposure.glsl"

struct Surface {
    vec3 albedo;        // linear
    vec3 playerPos;     // relative to the camera, world axes
    vec3 shadowPos;     // where the shadow is looked up: the centre of the texture texel (pixel shadows), else playerPos
    vec3 normal;        // world space, with the texture's relief (generated normals)
    vec3 faceNormal;    // world space normal of the face itself (shadow offsets)
    vec2 lightmap;      // x: block light, y: sky light, both 0..1
    float ao;           // vanilla ambient occlusion
    int material;
    float roughness;    // see blockFinish(): 0 mirror .. 1 chalk
    float f0;           // reflectance at normal incidence (a metal: of its own colour)
    float metal;        // 1 for metals
};

// The finish of a surface (see blockFinish), set on a Surface.
void setFinish(inout Surface s, vec3 finish) {
    s.roughness = finish.x;
    s.f0 = finish.y;
    s.metal = finish.z;
}

struct Lights {
    vec3 direct;        // sun/moon colour, 0 when it is below the horizon
    vec3 ambient;       // sky irradiance
};

Lights frameLights() {
    Lights l;
#ifdef DIM_OVERWORLD
    l.direct = directLightColor();
    l.ambient = ambientLightColor();
#else
    l.direct = vec3(0.0);
    l.ambient = vec3(0.0);
#endif
    return l;
}

// Exposure that block light is shown at, whatever the eye is adapted to (about a dark-adapted cave's).
const float BLOCK_LIGHT_EXPOSURE = 1.3;

// Firelight: warm amber (torches, lava and lanterns all burn warm in the game).
vec3 blockLightColor() {
    return mix(vec3(1.0, 0.86, 0.72), vec3(1.0, 0.55, 0.22), 0.7 * BLOCK_LIGHT_WARMTH);
}

// Firelight is never quite steady: a slow, gentle waver that drifts across the walls (a few blocks across, so
// neighbouring torches do not pulse in step).
float blockLightFlicker(vec3 worldPos) {
    float t = frameTimeCounter;
    return 1.0 + 0.07 * (valueNoise(worldPos.xz * 0.3 + worldPos.y * 0.17 + vec2(t * 2.3, -t * 1.7)) - 0.5);
}

// Torches and lamps light the blocks next to them about as brightly as vanilla does (2.2 here, with the dark-adapted
// exposure in caves, made every torch a floodlight). A cube fell off too fast: in a cave a torch lit only the blocks
// right around it, a bright dot in the dark; with 2.4 its light reaches across a room like vanilla's.
float blockLightCurve(float level) {
    return pow(level, 2.4) * 0.8 + level * 0.04;
}

float fresnelSchlick(float cosTheta, float f0) {
    return f0 + (1.0 - f0) * pow(1.0 - saturate(cosTheta), 5.0);
}

float ggxSpecular(vec3 n, vec3 v, vec3 l, float roughness) {
    vec3 h = normalize(v + l);
    float nh = saturate(dot(n, h));
    float nl = saturate(dot(n, l));
    float a2 = sqr(roughness * roughness);
    float d = a2 / (PI * sqr(nh * nh * (a2 - 1.0) + 1.0));
    return d * nl * 0.25;
}

// Diffuse light of a rough, matte surface (Burley): a little brighter with the sun behind the viewer, a little flatter
// under grazing light, where plain Lambert makes every block look like smooth plastic. Half of it is blended with
// Lambert, so the brightness of the whole scene stays where it was calibrated.
float roughDiffuse(float nl, float nv, float lh, float roughness) {
    float f90 = 0.5 + 2.0 * roughness * lh * lh;
    float light = 1.0 + (f90 - 1.0) * pow(1.0 - nl, 5.0);
    float view = 1.0 + (f90 - 1.0) * pow(1.0 - nv, 5.0);
    return mix(1.0, light * view, 0.5);
}

// Reflectance of a surface for light arriving along l, seen from v: a dielectric mirrors white light (F0 0.02..0.07),
// a metal mirrors in its own colour.
vec3 surfaceFresnel(Surface s, float cosTheta) {
    vec3 f0 = vec3(s.f0);
    if (s.metal > 0.5) {
        f0 = s.albedo / max(max(s.albedo.r, max(s.albedo.g, s.albedo.b)), 0.05) * s.f0;
    }
    return f0 + (1.0 - f0) * pow(1.0 - saturate(cosTheta), 5.0);
}

// The sun mirrored by the surface itself, by its finish (blockFinish): rough matte blocks show no highlight from
// above, only a faint glare when looking towards a low sun; dirt, sand and wool none at all (a glare on the ground
// made it look like plastic); polished stone and glazed blocks a small bright spot; metals a broad glint in their own
// colour. With the texture's relief the highlight breaks up texel by texel like the pixels of the texture.
vec3 sunHighlight(Surface s, vec3 v, vec3 l) {
    if (s.f0 <= 0.0) {
        return vec3(0.0);
    }
    vec3 h = normalize(v + l);
    return ggxSpecular(s.normal, v, l, s.roughness) * surfaceFresnel(s, dot(v, h));
}

// The game's look: light fills up like vanilla's light map, the full sun brings a surface to about its texture colour
// and no further, while dim light (night, shade, caves) stays nearly as it is. Physically the noon sun is ten times
// the sky and it painted grass lime and stone white; compressed, textures keep their colours and shade stays light.
vec3 vanillaLightResponse(vec3 light) {
    return light / (1.0 + luminance(light) * LIGHT_RESPONSE);
}

// Snow glitters in the sun: here and there a single texel of a snow surface catches the light, and which ones do
// changes as the viewer moves, like the facets of real snow crystals. Near-white, colourless top faces in snowy land
// only (vanilla snow and Hoarfrost's cover alike); gone beyond a few chunks, where a texel is smaller than a pixel.
float snowSparkle(Surface s, vec3 viewDir) {
#ifdef SNOW_SPARKLE
    float dist = length(s.playerPos);
    if (snowWeather <= 0.0 || s.normal.y < 0.7 || dist > 28.0) {
        return 0.0;
    }
    float m = max(s.albedo.r, max(s.albedo.g, s.albedo.b));
    float colour = m - min(s.albedo.r, min(s.albedo.g, s.albedo.b));
    float white = smoothstep(0.55, 0.75, m) * (1.0 - smoothstep(0.06, 0.15, colour));
    if (white <= 0.0) {
        return 0.0;
    }
    vec3 texel = floor((s.playerPos + cameraPosition) * 16.0 + s.normal * 0.01);
    vec2 facet = floor(viewDir.xz * 7.0);
    float glint = step(0.986, hash13(texel + vec3(facet.x * 17.0, facet.y * 29.0, 0.0)));
    return glint * white * snowWeather * (1.0 - smoothstep(14.0, 28.0, dist)) * 0.3;
#else
    return 0.0;
#endif
}

// Light reaching the surface from the light held in hand.
float handLight(vec3 playerPos) {
#ifdef HANDHELD_LIGHT
    float level = float(max(heldBlockLightValue, heldBlockLightValue2));
    if (level <= 0.0) {
        return 0.0;
    }
    float d = length(playerPos);
    return blockLightCurve(saturate((level - d) / 15.0));
#else
    return 0.0;
#endif
}

vec3 shade(Surface s, Lights lights, float noise) {
    vec3 viewDir = -normalize(s.playerPos);
    float sky = s.lightmap.y;
    bool foliage = s.material == MAT_PLANT || s.material == MAT_LEAVES;

#ifdef DIM_OVERWORLD
    vec3 l = lightDirection();
#else
    vec3 l = vec3(0.0, 1.0, 0.0);
#endif

    // Sky ambient: brighter on top faces, fading in towards shelter.
    float skyFalloff = sky * sky;
    float up = foliage ? 0.85 : 0.72 + 0.28 * s.normal.y;
    // The sky is brighter around the sun: side faces turned towards it get a little more of its light.
    vec2 sunSide = l.xz / max(length(l.xz), 1e-4);
    float side = foliage ? 0.0 : dot(s.normal.xz, sunSide) * (1.0 - overcast());
    // Lambertian: radiance = albedo * irradiance / pi.
    vec3 ambient = lights.ambient / PI * skyFalloff * up * (1.0 + 0.15 * side);

    // Sunlight bounced off the ground (albedo about 0.15, a little green-brown) lights faces turned away from the sun
    // from below: without it shaded walls look cut out of the scene.
    float groundView = foliage ? 0.35 : 0.5 - 0.5 * s.normal.y;
    ambient += lights.direct * saturate(l.y) * 0.15 * vec3(0.95, 1.0, 0.85) * groundView / PI * skyFalloff;

    ambient += vec3(AMBIENT_MIN) * vec3(0.8, 0.9, 1.1) * brightnessLift() + nightVision * vec3(0.25);
#if defined DIM_NETHER
    // The Nether is never as dark as a cave: the glow of its lava seas hangs in the air, a dull warm light everywhere
    // (vanilla lifts its light map there as well). Without it netherrack and the forests were a near-black mass.
    ambient += vec3(1.0, 0.8, 0.68) * 0.04 * brightnessLift();
#elif defined DIM_END
    // The End is lit by a pale light without a source (vanilla brightens its whole light map there); without it the
    // end stone was a dark olive, three times darker than the game's.
    ambient += vec3(0.98, 1.0, 1.02) * 0.052 * brightnessLift();
#else
    // Deep in caves a faint cool fill keeps the shapes of the rock readable in the dark (vanilla's dark is never
    // pitch black either); the warm firelight stands out against it.
    ambient += vec3(0.55, 0.7, 1.0) * 0.02 * brightnessLift() * (1.0 - smoothstep(0.0, 0.5, sky));
#endif

    // The Brightness option also lifts weak block light the way vanilla's gamma does, so torches reach farther into
    // the dark at higher settings (1 - (1 - x)^3 at most halfway).
    float blockLevel = mix(s.lightmap.x, 1.0 - pow(1.0 - s.lightmap.x, 3.0), 0.5 * screenBrightness);
    vec3 block = blockLightColor() * (blockLightCurve(blockLevel) + handLight(s.playerPos))
            * blockLightFlicker(s.playerPos + cameraPosition);
    // Torches and lamps look the same by day, at night and in a cave: the eye's adaptation to the dark (up to 3x at
    // night) is taken back out of their light - amplified, every lantern lit its surroundings like a floodlight.
    block *= BLOCK_LIGHT_EXPOSURE / sceneExposure();

    vec3 direct = vec3(0.0);
    vec3 sheen = vec3(0.0);
    // How much of the sun reaches the surface (shadow, cloud shadow, sky gate), 0..1.
    float sunLit = 0.0;
#ifdef DIM_OVERWORLD
    // The texture's relief shades a face texel by texel, but never lights a face turned away from the light.
    float faceNl = dot(s.faceNormal, l);
    float nl = faceNl > 0.0 ? dot(s.normal, l) : faceNl;
    float diffuse;
    if (s.material == MAT_PLANT || s.material == MAT_PARTICLE) {
        diffuse = 0.55 + 0.25 * abs(nl);
    } else if (s.material == MAT_LEAVES) {
        diffuse = saturate(nl) * 0.5 + 0.35;
    } else {
        // Wrapped: side faces keep part of the light even with the sun overhead, close to vanilla's face shading
        // (sides about 0.6..0.8 of the top) instead of turning dark at noon.
        float wrapped = saturate((nl + 0.6) / 1.6);
        diffuse = wrapped * roughDiffuse(saturate(nl), saturate(dot(s.normal, viewDir)),
                saturate(dot(l, normalize(l + viewDir))), 0.8);
    }
    // Direct light only reaches places the sky light reaches: no sun through cave walls beyond the shadow map.
    float skyGate = smoothstep(0.1, 0.45, sky);
    if (diffuse > 0.0 && skyGate > 0.0 && dot(lights.direct, vec3(1.0)) > 1e-4) {
        vec3 visibility = vec3(1.0);
#ifdef SHADOWS
#ifdef SHADOW_LOOKUP
        bool pixelLock = s.material != MAT_ENTITY && s.material != MAT_HAND && s.material != MAT_PARTICLE;
        visibility = shadowVisibility(s.shadowPos, s.faceNormal, noise, foliage, pixelLock);
#endif
#endif
        // Shade is never black: a little of the sun reaches it, like the soft, light shade of the vanilla look.
        visibility = mix(vec3(SHADOW_LIGHT), vec3(1.0), visibility);
#if defined CLOUD_LOOKUP && CLOUDS > 0
        visibility *= cloudShadow(s.playerPos, l);
#endif
        direct = lights.direct / PI * diffuse * visibility * skyGate;
        sunLit = luminance(visibility) * skyGate;
#ifdef SURFACE_SHEEN
        if (s.material != MAT_PLANT && s.material != MAT_PARTICLE && dot(s.faceNormal, l) > 0.0) {
            sheen = lights.direct * sunHighlight(s, viewDir, l) * visibility * skyGate * discClarity();
            // Bright, but never a blinding blob: a shiny metal face in line with the sun was 30x its own diffuse light.
            sheen /= 1.0 + luminance(sheen) * 0.15;
        }
#endif
        if (!foliage) {
            sheen += lights.direct * snowSparkle(s, viewDir) * visibility * skyGate * discClarity();
        }
#ifdef FOLIAGE_TRANSLUCENCY
        if (foliage) {
            // Light shining through thin leaves when looking towards the sun.
            float through = pow(saturate(dot(-viewDir, l)), 6.0) * 0.6 + 0.12;
            direct += lights.direct / PI * s.albedo * through * visibility * skyGate * 1.4;
        }
#endif
    }
    // A lightning bolt lights its surroundings from the side (the sky flash itself comes with the ambient light).
    float flash = lightningFlash();
    if (flash > 0.0 && skyGate > 0.0) {
        // The channel's brightest part is some way up.
        vec3 toBolt = lightningBoltPosition.xyz + vec3(0.0, 24.0, 0.0) - s.playerPos;
        float d = length(toBolt);
        float facing = foliage ? 0.7 : saturate(dot(s.normal, toBolt / d)) * 0.8 + 0.2;
        direct += FLASH_TINT * flash * 25.0 / (1.0 + sqr(d / 48.0)) / PI * facing * skyGate;
    }
#endif

    // The light is compressed towards vanilla's light map (vanillaLightResponse), but mostly by how much light this
    // spot gets as a whole - its sky light, block light and whether the sun reaches it - and only partly by the angle
    // of the face: compressing each face by its own light made the sunlit sides of a block nearly as bright as its
    // top (0.85 of it, vanilla shades them 0.6..0.8), so blocks lost their form and looked flat and plastic at noon.
    // Shade keeps its soft, light look: there the reference is the shade itself.
    vec3 total = (ambient + block) * s.ao + direct;
    vec3 reference = (ambient + block) * s.ao + lights.direct / PI * sunLit;
    vec3 response = total / (1.0 + (0.35 * luminance(total) + 0.65 * luminance(reference)) * LIGHT_RESPONSE);
    // The sheen is reflected light: white, not tinted by the albedo. A metal's colour is mostly what it reflects
    // (added in the composite pass, see composite.fsh glossyReflection), its diffuse part is weaker - kept at three
    // quarters: vanilla's metal textures already paint the shine in.
    vec3 color = s.albedo * response * (1.0 - 0.25 * s.metal) + sheen;

#if defined WET_SURFACES && defined DIM_OVERWORLD
    // Rain darkens exposed surfaces; water stays as a glossy film only in the hollows.
    // Falling snow leaves nothing wet.
    float wet = wetness * (1.0 - snowWeather) * smoothstep(0.75, 0.95, sky) * saturate(s.normal.y * 0.7 + 0.3);
    if (wet > 0.01 && s.material != MAT_ENTITY && s.material != MAT_HAND) {
        // Water fills the pores: darker, and colours deepen instead of washing out.
        float lum = luminance(color);
        color = mix(color, max(mix(vec3(lum), color, 1.25), 0.0), wet) * (1.0 - wet * (foliage ? 0.3 : 0.42));
        // Soaked dirt, stone and wood stay matte: a gloss over the whole surface (it mirrored the sky everywhere) made
        // the ground look like plastic. Water lies in patches on top faces, texel by texel like the textures' own
        // pixels, and in the darker texels (the cracks and hollows of a texture); on walls only a few wet texels.
        vec3 worldPos = s.playerPos + cameraPosition;
        float pore = hash13(floor(worldPos * 16.0 + s.normal * 0.01));
        float hollow = 1.0 - smoothstep(0.15, 0.6, luminance(s.albedo));
        float pool = valueNoise(floor(worldPos.xz * 16.0) / 16.0 * 0.45 + 5.0);
        float gather = saturate(s.normal.y) * pool * 0.8 + hollow * 0.22 + pore * 0.1;
        float film = foliage ? 0.0 : smoothstep(0.62, 0.8, gather) * smoothstep(0.3, 0.8, wet);
        if (film > 0.0) {
            vec3 r = reflect(-viewDir, s.normal);
            r.y = abs(r.y);
            float f = fresnelSchlick(dot(viewDir, s.normal), 0.02) * film * 0.5;
            color += vanillaLightResponse(sampleSkyLut(r, sunDirection())) * f;
            // The sun on wet ground is a broad, calm glare on the wet patches, like on a wet road - never one smooth
            // glowing ball (a sharp highlight bloomed into one) and never a field of flickering pixels (a mirror per
            // texel made the ground ripple as you moved). The glare saturates instead of peaking, so its centre is
            // only a little brighter than a white block in the sun. A rare wet texel close by catches the sun a
            // little more, fading in and out slowly. Only where the sun really shines.
            float sun = film * sunLit * discClarity() * step(0.0, dot(s.normal, l));
            if (sun > 0.0) {
                float glare = (1.0 - exp(-ggxSpecular(s.normal, viewDir, l, 0.45))) * 0.12;
                vec3 texel = floor(worldPos * 16.0 + s.normal * 0.01);
                float glint = 0.0;
                if (hash13(texel + 61.7) < 0.04) {
                    vec3 tilt = vec3(hash13(texel + 11.3), hash13(texel + 27.1), hash13(texel + 43.7)) - 0.5;
                    vec3 facet = normalize(s.normal + tilt * 0.2);
                    glint = smoothstep(0.93, 0.99, dot(reflect(-viewDir, facet), l))
                            * (1.0 - smoothstep(8.0, 20.0, length(s.playerPos))) * 0.08;
                }
                color += lights.direct * sun * (glare + glint);
            }
        }
    }
#endif
    return color;
}

// Glow of light-emitting blocks. Known light blocks glow over most of their texture; any other light source (a modded
// one, a furnace) only in texels that are bright AND stand out from the rest of their texture (`standOut` = the texel
// over its texture's average, 1 for known blocks), so the stone of a lit furnace does not glow with its fire and a
// modded machine's light metal does not glow with its crystal.
// The glow keeps a deeper, richer colour than the texture (lava a glowing orange, not a pale salmon once it is bright).
vec3 emission(vec3 albedo, float strength, bool wholeBlock, float standOut) {
    float m = max(albedo.r, max(albedo.g, albedo.b));
    float mask = wholeBlock ? smoothstep(0.08, 0.7, m) : smoothstep(0.4, 0.85, m) * smoothstep(1.15, 1.6, standOut);
    vec3 rich = pow(albedo / max(m, 1e-4), vec3(1.5)) * m;
    return rich * mask * strength;
}

// Glow of lava, by the heat of each texel like glowing metal: the dark crust a deep, dim red, the veins orange, the
// brightest spots yellow and much brighter - the contrast is what makes it look hot (one strength for every texel
// clipped the whole pool to one flat salmon). Slow waves of heat roll across the surface.
vec3 lavaGlow(vec3 albedo, vec3 worldPos) {
    vec2 p = worldPos.xz * 0.35;
    float wave = valueNoise(p + frameTimeCounter * vec2(0.08, 0.05)) * 0.65
            + valueNoise(p * 2.3 - frameTimeCounter * vec2(0.04, 0.11)) * 0.35;
    float heat = saturate(smoothstep(0.03, 0.6, albedo.g) + (wave - 0.5) * 0.24);
    vec3 color = mix(vec3(1.0, 0.07, 0.0), vec3(1.0, 0.36, 0.03), smoothstep(0.0, 0.45, heat));
    color = mix(color, vec3(1.0, 0.75, 0.22), smoothstep(0.5, 1.0, heat));
    return color * (0.3 + 0.6 * heat + 3.2 * heat * heat);
}

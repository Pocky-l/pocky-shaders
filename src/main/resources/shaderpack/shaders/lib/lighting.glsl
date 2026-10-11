// Forward shading used by all lit gbuffers programs. Needs common, atmosphere, sky and (in the overworld) shadow.

struct Surface {
    vec3 albedo;        // linear
    vec3 playerPos;     // relative to the camera, world axes
    vec3 normal;        // world space
    vec2 lightmap;      // x: block light, y: sky light, both 0..1
    float ao;           // vanilla ambient occlusion
    int material;
};

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

vec3 blockLightColor() {
    return mix(vec3(1.0, 0.86, 0.72), vec3(1.0, 0.58, 0.26), 0.55 * BLOCK_LIGHT_WARMTH);
}

// Torches and lamps light the blocks next to them about as brightly as vanilla does (2.2 here, with the dark-adapted
// exposure in caves, made every torch a floodlight).
float blockLightCurve(float level) {
    return level * level * level * 0.8 + level * 0.04;
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

// Roughness of the sun's reflection on a material (no reflection on plants: their quads have no real surface normal).
// Dirt, stone, wood and wool are very rough: anything glossier made the world look like plastic toy cubes.
float sheenRoughness(int material) {
    if (material == MAT_LEAVES) {
        return 0.75;
    }
    if (material == MAT_ENTITY || material == MAT_HAND) {
        return 0.8;
    }
    return 0.9;
}

// The sun mirrored by the surface itself. Rough matte surfaces show no highlight from above, only a soft glare at
// grazing angles when looking towards a low sun (the Fresnel rise; F0 0.02 keeps the rest invisible).
float sunSheen(vec3 n, vec3 v, vec3 l, float roughness) {
    vec3 h = normalize(v + l);
    return ggxSpecular(n, v, l, roughness) * fresnelSchlick(dot(v, h), 0.02);
}

// Near-white materials (snow - vanilla's and modded snow covers alike -, ice, white wool, quartz, calcite) lit by the
// full sun ran into the top of the tonemap as flat white sheets. Judged by the block's average colour (a coarse mip
// of its texture, x the vertex tint), they are darkened as a whole and their texture's contrast is raised, so they
// keep grain and shape. Only under a strong sun: in overcast light or a blizzard snow stays bright white. Darker
// materials are untouched.
vec3 tameBrightAlbedo(vec3 albedo, vec3 average, vec3 directLight) {
    float averageLum = luminance(average);
    float bright = smoothstep(0.45, 0.75, averageLum) * smoothstep(1.0, 5.0, luminance(directLight));
    if (bright <= 0.0) {
        return albedo;
    }
    // Under the full sun a surface at albedo ~0.4 already sits high on the tonemap curve (where it still has slope).
    float scale = (0.38 + (averageLum - 0.5) * 0.1) / averageLum;
    vec3 detail = pow(max(albedo, 1e-4) / max(average, vec3(1e-4)), vec3(2.2));
    return mix(albedo, average * scale * detail, bright);
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
    float side = foliage ? 0.0 : dot(s.normal.xz, sunSide) * (1.0 - rainStrength);
    // Lambertian: radiance = albedo * irradiance / pi.
    vec3 ambient = lights.ambient / PI * skyFalloff * up * (1.0 + 0.15 * side);

    // Sunlight bounced off the ground (albedo about 0.15, a little green-brown) lights faces turned away from the sun
    // from below: without it shaded walls look cut out of the scene.
    float groundView = foliage ? 0.35 : 0.5 - 0.5 * s.normal.y;
    ambient += lights.direct * saturate(l.y) * 0.15 * vec3(0.95, 1.0, 0.85) * groundView / PI * skyFalloff;

    ambient += vec3(AMBIENT_MIN) * vec3(0.8, 0.9, 1.1) * brightnessLift() + nightVision * vec3(0.25);

    // The Brightness option also lifts weak block light the way vanilla's gamma does, so torches reach farther into
    // the dark at higher settings (1 - (1 - x)^3 at most halfway).
    float blockLevel = mix(s.lightmap.x, 1.0 - pow(1.0 - s.lightmap.x, 3.0), 0.5 * screenBrightness);
    vec3 block = blockLightColor() * (blockLightCurve(blockLevel) + handLight(s.playerPos));

    vec3 direct = vec3(0.0);
    vec3 sheen = vec3(0.0);
#ifdef DIM_OVERWORLD
    float nl = dot(s.normal, l);
    float diffuse;
    if (s.material == MAT_PLANT || s.material == MAT_PARTICLE) {
        diffuse = 0.55 + 0.25 * abs(nl);
    } else if (s.material == MAT_LEAVES) {
        diffuse = saturate(nl) * 0.5 + 0.35;
    } else {
        diffuse = saturate(nl) * roughDiffuse(saturate(nl), saturate(dot(s.normal, viewDir)),
                saturate(dot(l, normalize(l + viewDir))), 0.8);
    }
    // Direct light only reaches places the sky light reaches: no sun through cave walls beyond the shadow map.
    float skyGate = smoothstep(0.1, 0.45, sky);
    if (diffuse > 0.0 && skyGate > 0.0 && dot(lights.direct, vec3(1.0)) > 1e-4) {
        vec3 visibility = vec3(1.0);
#ifdef SHADOWS
#ifdef SHADOW_LOOKUP
        bool pixelLock = !foliage && s.material != MAT_ENTITY && s.material != MAT_HAND && s.material != MAT_PARTICLE;
        visibility = shadowVisibility(s.playerPos, s.normal, noise, foliage, pixelLock);
#endif
#endif
        // Shade is never black: a little of the sun reaches it, like the soft, light shade of the vanilla look.
        visibility = mix(vec3(SHADOW_LIGHT), vec3(1.0), visibility);
#if defined CLOUD_LOOKUP && CLOUDS > 0
        visibility *= cloudShadow(s.playerPos, l);
#endif
        direct = lights.direct / PI * diffuse * visibility * skyGate;
#ifdef SURFACE_SHEEN
        if (s.material != MAT_PLANT && s.material != MAT_PARTICLE && nl > 0.0) {
            sheen = lights.direct * sunSheen(s.normal, viewDir, l, sheenRoughness(s.material)) * visibility * skyGate
                    * discClarity();
        }
#endif
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

    // The sheen is reflected light: white, not tinted by the albedo.
    vec3 color = s.albedo * ((ambient + block) * s.ao + direct) + sheen;

#if defined WET_SURFACES && defined DIM_OVERWORLD
    // Rain darkens exposed surfaces and gives them a soft sky sheen.
    // Falling snow leaves nothing wet.
    float wet = wetness * (1.0 - snowWeather) * smoothstep(0.75, 0.95, sky) * saturate(s.normal.y * 0.7 + 0.3);
    if (wet > 0.01 && s.material != MAT_ENTITY && s.material != MAT_HAND) {
        // Water fills the pores: darker, and colours deepen instead of washing out.
        float lum = luminance(color);
        color = mix(color, max(mix(vec3(lum), color, 1.25), 0.0), wet) * (1.0 - wet * (foliage ? 0.3 : 0.42));
        vec3 r = reflect(-viewDir, s.normal);
        r.y = abs(r.y);
        // A film of water on top faces mirrors the sky a little, plants get only their own leaf sheen.
        float film = foliage ? 0.5 : mix(0.8, 2.2, saturate(s.normal.y));
        float f = fresnelSchlick(dot(viewDir, s.normal), 0.03) * wet * film;
        color += sampleSkyLut(r, sunDirection()) * f;
        color += lights.direct * ggxSpecular(s.normal, viewDir, l, 0.25) * wet * 0.5 * discClarity()
                * (dot(direct, vec3(1.0)) > 0.0 ? 1.0 : 0.0);
    }
#endif
    return color;
}

// Glow of light-emitting blocks. Known light blocks glow over most of their texture; any other light source (a modded
// one, a furnace) only in its brightest texels, so the stone of a lit furnace does not glow with its fire.
vec3 emission(vec3 albedo, float strength, bool wholeBlock) {
    float m = max(albedo.r, max(albedo.g, albedo.b));
    float mask = wholeBlock ? smoothstep(0.08, 0.7, m) : smoothstep(0.4, 0.85, m);
    return albedo * mask * strength;
}

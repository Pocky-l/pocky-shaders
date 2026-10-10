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

float blockLightCurve(float level) {
    return level * level * level * 2.2 + level * 0.06;
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

    // Sky ambient: brighter on top faces, fading in towards shelter.
    float skyFalloff = sky * sky;
    float up = foliage ? 0.85 : 0.72 + 0.28 * s.normal.y;
    // Lambertian: radiance = albedo * irradiance / pi.
    vec3 ambient = lights.ambient / PI * skyFalloff * up;

    // Some sun light bounced off the ground fills in shadows.
    ambient += lights.direct / PI * 0.035 * skyFalloff * (0.6 - 0.4 * s.normal.y);

    ambient += vec3(AMBIENT_MIN) * vec3(0.8, 0.9, 1.1) + nightVision * vec3(0.25);

    vec3 block = blockLightColor() * (blockLightCurve(s.lightmap.x) + handLight(s.playerPos));

    vec3 direct = vec3(0.0);
#ifdef DIM_OVERWORLD
    vec3 l = lightDirection();
    float nl = dot(s.normal, l);
    float diffuse;
    if (s.material == MAT_PLANT || s.material == MAT_PARTICLE) {
        diffuse = 0.55 + 0.25 * abs(nl);
    } else if (s.material == MAT_LEAVES) {
        diffuse = saturate(nl) * 0.5 + 0.35;
    } else {
        diffuse = saturate(nl);
    }
    // Direct light only reaches places the sky light reaches: no sun through cave walls beyond the shadow map.
    float skyGate = smoothstep(0.1, 0.45, sky);
    if (diffuse > 0.0 && skyGate > 0.0 && dot(lights.direct, vec3(1.0)) > 1e-4) {
        vec3 visibility = vec3(1.0);
#ifdef SHADOWS
#ifdef SHADOW_LOOKUP
        visibility = shadowVisibility(s.playerPos, s.normal, noise, foliage);
#endif
#endif
#if defined CLOUD_LOOKUP && CLOUDS > 0
        visibility *= cloudShadow(s.playerPos, l);
#endif
        direct = lights.direct / PI * diffuse * visibility * skyGate;
#ifdef FOLIAGE_TRANSLUCENCY
        if (foliage) {
            // Light shining through thin leaves when looking towards the sun.
            float through = pow(saturate(dot(-viewDir, l)), 6.0) * 0.6 + 0.12;
            direct += lights.direct / PI * s.albedo * through * visibility * skyGate * 1.4;
        }
#endif
    }
#endif

    vec3 color = s.albedo * ((ambient + block) * s.ao + direct);

#if defined WET_SURFACES && defined DIM_OVERWORLD
    // Rain darkens exposed surfaces and gives them a soft sky sheen.
    float wet = wetness * smoothstep(0.75, 0.95, sky) * saturate(s.normal.y * 0.7 + 0.3);
    if (wet > 0.01 && s.material != MAT_ENTITY && s.material != MAT_HAND) {
        color *= 1.0 - wet * 0.35;
        vec3 r = reflect(-viewDir, s.normal);
        float f = fresnelSchlick(dot(viewDir, s.normal), 0.03) * wet;
        color += sampleSkyLut(r, sunDirection()) * f * 0.8;
        color += lights.direct * ggxSpecular(s.normal, viewDir, l, 0.25) * wet * 0.5 * (dot(direct, vec3(1.0)) > 0.0 ? 1.0 : 0.0);
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

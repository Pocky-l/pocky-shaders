// Water only leaves its surface normal, biome tint and sky light in colortex4: the composite pass draws it with
// refraction, absorption and reflections. Other translucent blocks are shaded here and blended into colortex3.

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#ifdef DIM_OVERWORLD
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
#define CLOUD_LOOKUP
#include "/lib/clouds.glsl"
#define SHADOW_LOOKUP
#include "/lib/shadow.glsl"
#endif
#include "/lib/lighting.glsl"
#include "/lib/water.glsl"

uniform sampler2D gtexture;

in vec2 texcoord;
in vec2 lightmap;
in vec4 vertexColor;
in vec3 playerPos;
in vec3 worldNormal;
flat in int blockId;

/* RENDERTARGETS: 3,4 */
layout(location = 0) out vec4 outTranslucent;
layout(location = 1) out vec4 outWater;

void main() {
    vec3 n = normalize(worldNormal);
    if (!gl_FrontFacing) {
        n = -n;
    }

    if (blockId == ID_WATER || blockId == ID_FLOWING_WATER) {
        vec3 worldPos = playerPos + cameraPosition;
        vec3 wn = n;
        float dist = length(playerPos);
        float waveFade = mix(0.35, 1.0, 1.0 - smoothstep(ANIMATION_DISTANCE * 1.5, ANIMATION_DISTANCE * 2.5, dist));
        bool side = abs(n.y) <= 0.5;
        bool running = blockId == ID_FLOWING_WATER || side;
        if (!side && waveFade > 0.0) {
            // Top (or, seen from below, bottom) of the water: waves, calmer in sheltered water.
            wn = waterNormal(worldPos.xz, (0.4 + 0.6 * lightmap.y) * waveFade, waterDetail(dist));
            wn.y *= sign(n.y);
        }
        float foam = 0.0;
        if (running) {
            // Running water is not a clear pane: the game's flowing water texture already moves along the current
            // (down a waterfall, downstream on a river), its bright streaks become broken, foamy water and bend the
            // surface. Waterfalls churn the most.
            float lum = luminance(texture(gtexture, texcoord).rgb);
            float streak = smoothstep(0.645, 0.78, lum);
            float near = 1.0 - smoothstep(24.0, 64.0, dist);
            vec3 dpdx = dFdx(playerPos);
            vec3 dpdy = dFdy(playerPos);
            float h = streak * 0.06 * near;
            vec3 r1 = cross(dpdy, n);
            vec3 r2 = cross(n, dpdx);
            float det = dot(dpdx, r1);
            if (abs(det) > 1e-8) {
                vec3 grad = (dFdx(h) * r1 + dFdy(h) * r2) / det;
                wn = normalize(wn - grad);
            }
            foam = side ? 0.3 + 0.55 * streak : 0.08 + 0.45 * streak;
        }
        outTranslucent = vec4(0.0);
        outWater = vec4(encodeWaterNormal(wn, foam), packWater(vertexColor.rgb, lightmap.y), 1.0);
        return;
    }

    vec4 color = texture(gtexture, texcoord) * vertexColor;
    if (color.a < 0.004) {
        discard;
    }
    Surface s;
    s.albedo = srgbToLinear(color.rgb);
    s.playerPos = playerPos;
    s.shadowPos = playerPos;
    s.normal = n;
    s.lightmap = lightmap;
    s.ao = 1.0;
    s.material = MAT_GLASS;
    vec3 lit = shade(s, frameLights(), dither(gl_FragCoord.xy));

#ifdef DIM_OVERWORLD
    // A faint sky reflection on glass and ice.
    vec3 v = -normalize(playerPos);
    float f = fresnelSchlick(dot(v, n), 0.04);
    lit += sampleSkyLut(reflect(-v, n), sunDirection()) * f * smoothstep(0.3, 0.9, lightmap.y) * 0.5;
    color.a = mix(color.a, 1.0, f * 0.5);
#endif
    outTranslucent = vec4(lit, color.a);
    outWater = vec4(0.0);
}

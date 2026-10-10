// Applies ambient occlusion to the opaque scene, draws the sky behind it and volumetric clouds over both.

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
uniform sampler2D colortex8;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 previousCameraPosition;

/*
const int colortex8Format = RGBA16F;
const bool colortex8Clear = false;
*/
uniform sampler2D depthtex0;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
uniform mat4 dhProjectionInverse;
#endif

in vec2 texcoord;

/* RENDERTARGETS: 0,8 */
layout(location = 0) out vec4 outColor;
layout(location = 1) out vec4 outClouds;

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

void main() {
    vec4 scene = texture(colortex0, texcoord);
    float depth = texture(depthtex0, texcoord).r;
    bool sky = depth >= 1.0;
#ifdef DISTANT_HORIZONS
    float dhDepth = texture(dhDepthTex0, texcoord).r;
    sky = sky && dhDepth >= 1.0;
#endif

    vec3 color = scene.rgb;
    if (!sky) {
#ifdef SSAO
        if (depth < 1.0) {
            float encoded = texture(colortex1, texcoord).z * 65535.0;
            int material = int(floor(encoded / 256.0 + 1e-3));
            float ao = blurredAo(depth);
            color *= material == MAT_HAND ? 1.0 : ao;
        }
#endif
    }

#ifdef DIM_OVERWORLD
    vec3 viewPos = screenToView(vec3(texcoord, sky ? 1.0 : depth));
#ifdef DISTANT_HORIZONS
    if (!sky && depth >= 1.0) {
        viewPos = projectAndDivide(dhProjectionInverse, vec3(texcoord, dhDepth) * 2.0 - 1.0);
    }
#endif
    vec3 dir = normalize(mat3(gbufferModelViewInverse) * viewPos);
    float sceneDist = sky ? 1e6 : length(viewPos);
    vec3 sunDir = sunDirection();

    if (sky) {
        // Atmosphere behind the vanilla sun, moon and stars (drawn additively into colortex0).
        color = sampleSkyLut(dir, sunDir) + scene.rgb * (1.0 - rainStrength);
    }

    vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
#if CLOUDS > 0
    if (sky || cameraPosition.y > CLOUD_BOTTOM - 40.0 || dir.y > 0.0) {
        clouds = cloudLayers(dir, sceneDist, lightDirection(), directLightColor(), ambientLightColor(), CLOUD_STEPS,
                dither(gl_FragCoord.xy));

        // Where was this bit of cloud last frame? (Clouds are far: a point a typical cloud distance along the ray.)
        float cloudDist = min(sceneDist, dir.y > 0.05 ? (0.5 * (CLOUD_BOTTOM + CLOUD_TOP) - cameraPosition.y) / dir.y : 2000.0);
        vec3 prevRel = cameraPosition + dir * max(cloudDist, 50.0) - previousCameraPosition;
        vec4 prevClip = gbufferPreviousProjection * (gbufferPreviousModelView * vec4(prevRel, 1.0));
        vec2 prevUv = prevClip.xy / prevClip.w * 0.5 + 0.5;
        if (prevClip.w > 0.0 && all(greaterThanEqual(prevUv, vec2(0.0))) && all(lessThanEqual(prevUv, vec2(1.0)))) {
            vec4 history = texture(colortex8, prevUv);
            float moved = length(cameraPosition - previousCameraPosition);
            float keep = mix(0.88, 0.4, saturate(moved / 3.0));
            clouds = mix(clouds, history, keep);
        }
        color = color * clouds.a + clouds.rgb;
    }
#endif
    outClouds = clouds;
#else
    outClouds = vec4(0.0, 0.0, 0.0, 1.0);
#endif
    outColor = vec4(color, 1.0);
}

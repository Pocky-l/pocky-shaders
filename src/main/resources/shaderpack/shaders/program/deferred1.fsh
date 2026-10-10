// Applies ambient occlusion to the opaque scene and draws the sky (atmosphere, sun, clouds, stars) behind it.

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
#ifdef DIM_OVERWORLD
uniform sampler2D colortex7;
#include "/lib/sky.glsl"
#include "/lib/clouds.glsl"
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
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

void main() {
    vec4 scene = texture(colortex0, texcoord);
    float depth = texture(depthtex0, texcoord).r;
    bool sky = depth >= 1.0;
#ifdef DISTANT_HORIZONS
    sky = sky && texture(dhDepthTex0, texcoord).r >= 1.0;
#endif

    if (!sky) {
#ifdef SSAO
        if (depth < 1.0) {
            float encoded = texture(colortex1, texcoord).z * 65535.0;
            int material = int(floor(encoded / 256.0 + 1e-3));
            float ao = blurredAo(depth);
            scene.rgb *= material == MAT_HAND ? 1.0 : ao;
        }
#endif
        outColor = vec4(scene.rgb, 1.0);
        return;
    }

#ifdef DIM_OVERWORLD
    vec3 viewDir = normalize(screenToView(vec3(texcoord, 1.0)));
    vec3 dir = normalize(mat3(gbufferModelViewInverse) * viewDir);
    vec3 sunDir = sunDirection();
    vec3 color = sampleSkyLut(dir, sunDir);

    // Sun disc with a soft limb.
    float cosSun = dot(dir, sunDir);
    float disc = smoothstep(0.99985, 0.99993, cosSun);
    color += sunDiscColor() * disc * 6.0;

    // Stars and the moon from the vanilla sky programs, faded by the bright day sky.
    color += scene.rgb * (1.0 - rainStrength);

#if CLOUDS > 0
    vec4 clouds = cloudLayers(dir, sunDir, lightDirection(), directLightColor(), ambientLightColor());
    color = color * clouds.a + clouds.rgb;
#endif
    outColor = vec4(color, 1.0);
#else
    outColor = vec4(scene.rgb, 1.0);
#endif
}

// Screen-space ambient occlusion of the opaque scene into colortex6.

#include "/lib/common.glsl"

/*
const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA16;
const int colortex2Format = R8;
const int colortex3Format = RGBA16F;
const int colortex4Format = RGBA16;
const int colortex5Format = RGBA16F;
const int colortex6Format = R8;
const vec4 colortex0ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex1ClearColor = vec4(0.5, 0.5, 0.0, 0.0);
const vec4 colortex3ClearColor = vec4(0.0, 0.0, 0.0, 0.0);
const vec4 colortex4ClearColor = vec4(0.5, 0.5, 0.0, 0.0);
*/

uniform sampler2D colortex1;
uniform sampler2D depthtex0;

in vec2 texcoord;

/* RENDERTARGETS: 6 */
layout(location = 0) out vec4 outAo;

void main() {
    float depth = texture(depthtex0, texcoord).r;
#ifdef SSAO
    if (depth >= 1.0 || depth < 0.56) {
        outAo = vec4(1.0);
        return;
    }
    vec3 viewPos = screenToView(vec3(texcoord, depth));
    float fade = 1.0 - smoothstep(DETAIL_DISTANCE * 0.5, DETAIL_DISTANCE * 1.5, -viewPos.z);
    if (fade <= 0.0) {
        outAo = vec4(1.0);
        return;
    }
    vec4 data = texture(colortex1, texcoord);
    vec3 normal = decodeNormal(data.xy);

    float noise = dither(gl_FragCoord.xy);
    float radius = 0.6;
    float occlusion = 0.0;
    for (int i = 0; i < SSAO_SAMPLES; i++) {
        // Points in a normal-oriented hemisphere, denser towards the centre.
        float fi = float(i) + noise;
        float r = sqrt(fi / float(SSAO_SAMPLES));
        float theta = fi * 2.39996323 + noise * 6.2831853;
        vec3 dir = vec3(cos(theta) * r, sin(theta) * r, sqrt(max(1.0 - r * r, 0.0)));
        vec3 t = normalize(abs(normal.y) < 0.99 ? cross(normal, vec3(0.0, 1.0, 0.0)) : cross(normal, vec3(1.0, 0.0, 0.0)));
        vec3 b = cross(normal, t);
        vec3 sampleView = viewPos + (t * dir.x + b * dir.y + normal * dir.z) * radius * mix(0.25, 1.0, fract(fi * 0.618));

        vec3 sampleScreen = viewToScreen(sampleView);
        if (any(lessThan(sampleScreen.xy, vec2(0.0))) || any(greaterThan(sampleScreen.xy, vec2(1.0)))) {
            continue;
        }
        float sceneDepth = texture(depthtex0, sampleScreen.xy).r;
        float sceneZ = screenToView(vec3(sampleScreen.xy, sceneDepth)).z;
        float rangeCheck = smoothstep(0.0, 1.0, radius / abs(viewPos.z - sceneZ));
        occlusion += (sceneZ >= sampleView.z + 0.03 ? 1.0 : 0.0) * rangeCheck;
    }
    float ao = 1.0 - occlusion / float(SSAO_SAMPLES);
    float encoded = data.z * 65535.0;
    int material = int(floor(encoded / 256.0 + 1e-3));
    float strength = (material == MAT_LEAVES || material == MAT_PLANT) ? 0.4 : 1.0;
    outAo = vec4(mix(1.0, pow(ao, 1.1 * SSAO_STRENGTH), fade * strength), 0.0, 0.0, 1.0);
#else
    outAo = vec4(1.0);
#endif
}

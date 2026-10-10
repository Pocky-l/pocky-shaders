// Edge anti-aliasing (a small FXAA-style filter on display colours), a light vignette and dithering against banding.

#include "/lib/common.glsl"

uniform sampler2D colortex0;

in vec2 texcoord;

layout(location = 0) out vec4 outColor;

float lumaAt(vec2 uv) {
    return dot(texture(colortex0, uv).rgb, vec3(0.299, 0.587, 0.114));
}

vec3 antiAlias(vec2 uv) {
    vec2 px = 1.0 / vec2(viewWidth, viewHeight);
    vec3 center = texture(colortex0, uv).rgb;
#ifdef FXAA
    float lc = dot(center, vec3(0.299, 0.587, 0.114));
    float ln = lumaAt(uv + vec2(0.0, px.y));
    float ls = lumaAt(uv - vec2(0.0, px.y));
    float le = lumaAt(uv + vec2(px.x, 0.0));
    float lw = lumaAt(uv - vec2(px.x, 0.0));
    float lo = min(lc, min(min(ln, ls), min(le, lw)));
    float hi = max(lc, max(max(ln, ls), max(le, lw)));
    float range = hi - lo;
    if (range < max(0.04, hi * 0.12)) {
        return center;
    }
    float lne = lumaAt(uv + px);
    float lnw = lumaAt(uv + vec2(-px.x, px.y));
    float lse = lumaAt(uv + vec2(px.x, -px.y));
    float lsw = lumaAt(uv - px);

    // Blend across the edge: along the gradient direction, by how much the centre differs from its neighbourhood.
    vec2 dir = vec2(-((lnw + lne) - (lsw + lse)), (lnw + lsw) - (lne + lse));
    float reduce = max((ln + ls + le + lw) * 0.03, 1.0 / 128.0);
    dir = clamp(dir / (min(abs(dir.x), abs(dir.y)) + reduce), vec2(-4.0), vec2(4.0)) * px;

    vec3 a = 0.5 * (texture(colortex0, uv + dir * (1.0 / 3.0 - 0.5)).rgb + texture(colortex0, uv + dir * (2.0 / 3.0 - 0.5)).rgb);
    vec3 b = a * 0.5 + 0.25 * (texture(colortex0, uv - dir * 0.5).rgb + texture(colortex0, uv + dir * 0.5).rgb);
    float lb = dot(b, vec3(0.299, 0.587, 0.114));
    return (lb < lo || lb > hi) ? a : b;
#else
    return center;
#endif
}

void main() {
    vec3 color = antiAlias(texcoord);
    vec2 v = texcoord - 0.5;
    color *= 1.0 - dot(v, v) * 0.22;
    color += (hash12(gl_FragCoord.xy + float(frameCounter % 16)) - 0.5) / 255.0;
    outColor = vec4(color, 1.0);
}

// Glare meter: how much the bright sun fills the view (visible, near the middle of the screen), eased over time the
// way an eye or a camera adapts. Writes texel (0, 0) of colortex8; composite2 dims the exposure and veils the image
// by it and copies it to colortex9, where the next frame continues from. (Two buffers, because a pass that read and
// wrote the same one would get Iris to flip it.)

#include "/lib/common.glsl"
#include "/lib/atmosphere.glsl"
uniform sampler2D colortex7;
#include "/lib/sky.glsl"

/*
const int colortex8Format = R16F;
const bool colortex8Clear = false;
const int colortex9Format = R16F;
const bool colortex9Clear = false;
*/

uniform sampler2D colortex0;
uniform sampler2D colortex9;
uniform float frameTime;

#include "/lib/sun_view.glsl"

in vec2 texcoord;

/* RENDERTARGETS: 8 */
layout(location = 0) out vec4 outGlare;

void main() {
    if (any(greaterThanEqual(gl_FragCoord.xy, vec2(1.0)))) {
        discard;
    }
    float target = 0.0;
#ifdef CINEMATIC_GLARE
    vec2 sunUv;
    if (sunOnScreen(sunUv)) {
        // Straight at the sun it blinds; at the edge of the view it hardly does.
        float facing = -normalize(sunPosition).z;
        target = sunVisibility(sunUv) * smoothstep(0.82, 0.985, facing)
                * smoothstep(0.0, 0.08, sunDirection().y);
    }
#endif
    float previous = saturate(texelFetch(colortex9, ivec2(0), 0).r);
    // Dazzled within a fraction of a second, back to normal in about two.
    float seconds = target > previous ? 0.3 : 1.2;
    outGlare = vec4(mix(previous, target, 1.0 - exp(-frameTime / seconds)), 0.0, 0.0, 1.0);
}

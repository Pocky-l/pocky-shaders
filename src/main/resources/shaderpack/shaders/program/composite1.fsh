// Glare meter: how much the bright sun is in the middle of the view (visible, and how close to where the camera
// points), like the light meter of a camera. Eased only over a few frames, so a sun flickering through leaves does not
// make the picture flicker; looking away takes the effect away at once. Writes texel (0, 0) of colortex8; composite2 dims the exposure and veils the image
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
        // Strongest looking straight at the sun, fading smoothly to nothing about 30 degrees away from it.
        float facing = -normalize(sunPosition).z;
        float aim = smoothstep(cos(radians(30.0)), 1.0, facing);
        target = sunVisibility(sunUv) * aim * aim * smoothstep(0.0, 0.08, sunDirection().y);
    }
#endif
    float previous = saturate(texelFetch(colortex9, ivec2(0), 0).r);
    float seconds = 0.08;
    outGlare = vec4(mix(previous, target, 1.0 - exp(-frameTime / seconds)), 0.0, 0.0, 1.0);
}

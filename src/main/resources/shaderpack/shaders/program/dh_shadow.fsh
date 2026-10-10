// See dh_shadow.vsh. Near the camera vanilla chunks cast the shadows; LODs there would only add acne.

#include "/lib/common.glsl"

in float cameraDistance;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outTint;

void main() {
    if (cameraDistance < far * 0.8) {
        discard;
    }
    outTint = vec4(1.0);
}

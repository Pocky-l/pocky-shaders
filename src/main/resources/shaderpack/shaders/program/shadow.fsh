// Depth goes to shadowtex0/1 automatically; shadowcolor0 keeps the tint of light through translucent blocks.

#include "/lib/common.glsl"

/*
const int shadowcolor0Format = RGBA8;
const vec4 shadowcolor0ClearColor = vec4(1.0, 1.0, 1.0, 1.0);
const bool shadowcolor0Clear = true;
*/

uniform sampler2D gtexture;

in vec2 texcoord;
in vec4 vertexColor;
flat in int blockId;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 outTint;

void main() {
    vec4 color = texture(gtexture, texcoord) * vertexColor;
    if (blockId == ID_WATER) {
        // Light keeps most of its strength through shallow water and takes on its colour.
        outTint = vec4(mix(vec3(1.0), srgbToLinearApprox(vertexColor.rgb), 0.45) * 0.9, 1.0);
        return;
    }
    if (color.a < 0.1) {
        discard;
    }
    // Stained glass and similar: coloured light; opaque blocks do not matter (shadowtex1 blocks them anyway).
    outTint = vec4(mix(vec3(1.0), srgbToLinearApprox(color.rgb), color.a), 1.0);
}

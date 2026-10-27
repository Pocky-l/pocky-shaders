// Unlit programs: sky parts, block outline, glowing eyes, beacon beams, enchantment glint, block breaking, weather.

#include "/lib/common.glsl"

out vec2 texcoord;
out vec2 lightmap;
out vec4 vertexColor;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightmap = saturate(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 1.0 / 32.0) * 16.0 / 15.0);
    vertexColor = gl_Color;
    gl_Position = ftransform();
}

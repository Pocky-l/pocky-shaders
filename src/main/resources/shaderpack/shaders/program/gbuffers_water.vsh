// Translucent terrain: water, stained glass, ice, slime, honey and modded translucent blocks.

#include "/lib/common.glsl"

in vec4 mc_Entity;

out vec2 texcoord;
out vec2 lightmap;
out vec4 vertexColor;
out vec3 playerPos;
out vec3 worldNormal;
flat out int blockId;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lightmap = saturate(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 1.0 / 32.0) * 16.0 / 15.0);
    vertexColor = gl_Color;
    blockId = int(mc_Entity.x + 0.5);

    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
    worldNormal = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));
    gl_Position = gl_ProjectionMatrix * gbufferModelView * vec4(playerPos, 1.0);
}

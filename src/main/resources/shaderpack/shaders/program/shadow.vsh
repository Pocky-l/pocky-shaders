// Shadow map pass: the same waving as the visible geometry, so shadows of plants move with them.

#include "/lib/common.glsl"
#include "/lib/wind.glsl"
#include "/lib/shadow.glsl"

uniform mat4 shadowModelViewInverse;

in vec4 mc_Entity;
in vec4 at_midBlock;

out vec2 texcoord;
out vec4 vertexColor;
flat out int blockId;

void main() {
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vertexColor = gl_Color;
    blockId = int(mc_Entity.x + 0.5);

    vec3 shadowView = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 playerPos = mat3(shadowModelViewInverse) * shadowView + shadowModelViewInverse[3].xyz;
    vec3 worldPos = playerPos + cameraPosition;
    float height = saturate(0.5 - at_midBlock.y / 64.0);
    vec2 lm = saturate(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 1.0 / 32.0) * 16.0 / 15.0);
    float exposed = smoothstep(0.2, 0.7, lm.y);
#ifdef WAVING_PLANTS
    if (blockId == ID_PLANT || blockId == ID_EMISSIVE_PLANT) {
        playerPos += windSway(worldPos, 0.09 * height) * exposed;
    } else if (blockId == ID_PLANT_LOWER) {
        playerPos += windSway(worldPos, 0.06 * height) * exposed;
    } else if (blockId == ID_PLANT_UPPER) {
        playerPos += windSway(worldPos, 0.06 + 0.08 * height) * exposed;
    }
#endif
#ifdef WAVING_LEAVES
    if (blockId == ID_LEAVES) {
        playerPos += leafRustle(worldPos, 0.035) * exposed;
    } else if (blockId == ID_VINE) {
        playerPos += leafRustle(worldPos, 0.03) * exposed * vec3(1.0, 0.3, 1.0);
    }
#endif

    vec4 clip = shadowProjection * shadowModelView * vec4(playerPos, 1.0);
    gl_Position = vec4(distortShadowClip(clip.xyz / clip.w), 1.0);
}

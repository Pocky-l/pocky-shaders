// Distant Horizons terrain (and water, with PROG_DH_WATER): lit like nearby terrain, without the shadow map.

#include "/lib/common.glsl"

out vec2 lightmap;
out vec4 vertexColor;
out vec3 playerPos;
out vec3 worldNormal;
flat out int dhMaterial;

void main() {
    lightmap = saturate(((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy - 1.0 / 32.0) * 16.0 / 15.0);
    vertexColor = gl_Color;
    dhMaterial = dhMaterialId;
    vec3 viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;
    playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
    worldNormal = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));
    gl_Position = ftransform();
}

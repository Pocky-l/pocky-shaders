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
#ifdef PROG_DH_WATER
    if (worldNormal.y > 0.5) {
        // LOD water tops sit at the full block height, vanilla water surfaces 1/9 of a block lower.
        const float DROP = 1.0 / 9.0;
        playerPos.y -= DROP;
        viewPos -= mat3(gl_ModelViewMatrix) * vec3(0.0, DROP, 0.0);
    }
    gl_Position = gl_ProjectionMatrix * vec4(viewPos, 1.0);
#else
    gl_Position = ftransform();
#endif
}

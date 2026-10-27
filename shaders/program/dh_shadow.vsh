// Distant Horizons terrain in the shadow map (Iris' DH shadow pass), so LODs cast shadows like chunks.

#include "/lib/common.glsl"
#include "/lib/shadow.glsl"

uniform mat4 shadowModelViewInverse;

out float cameraDistance;

void main() {
    vec3 shadowView = (gl_ModelViewMatrix * gl_Vertex).xyz;
    vec3 playerPos = mat3(shadowModelViewInverse) * shadowView + shadowModelViewInverse[3].xyz;
    cameraDistance = length(playerPos);
    vec4 clip = gl_ProjectionMatrix * vec4(shadowView, 1.0);
    gl_Position = vec4(distortShadowClip(clip.xyz / clip.w), 1.0);
}

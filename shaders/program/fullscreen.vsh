// Full-screen pass vertex shader shared by prepare, deferred, composite and final.

out vec2 texcoord;

void main() {
    gl_Position = ftransform();
    texcoord = gl_MultiTexCoord0.xy;
}

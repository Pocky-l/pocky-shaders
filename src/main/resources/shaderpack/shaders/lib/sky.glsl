// Reading the baked sky (colortex7, written by the prepare pass). Needs lib/atmosphere.glsl and colortex7.

vec3 sunDirection() {
    return normalize(mat3(gbufferModelViewInverse) * sunPosition);
}

vec3 lightDirection() {
    return normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
}

vec3 sampleSkyLut(vec3 dir, vec3 sunDir) {
    vec2 uv = skyLutCoord(dir, sunDir);
    vec2 texel = uv * vec2(SKY_LUT_SIZE - 1) + 0.5 + vec2(0.0, float(SKY_LUT_ROW));
    return texture(colortex7, texel / vec2(viewWidth, viewHeight)).rgb;
}

// Direct light colour of the current shadow light (sun by day, moon by night).
vec3 directLightColor() {
    return texelFetch(colortex7, PIXEL_LIGHT_COLOR, 0).rgb;
}

// Irradiance from the whole sky on an upward-facing surface.
vec3 ambientLightColor() {
    return texelFetch(colortex7, PIXEL_AMBIENT_COLOR, 0).rgb;
}

// Colour of the sun disc itself (sun illuminance through the air on the way to the eye).
vec3 sunDiscColor() {
    return texelFetch(colortex7, PIXEL_SUN_COLOR, 0).rgb;
}

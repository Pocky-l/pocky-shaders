// Sky model: single scattering through a Rayleigh + Mie atmosphere around a spherical planet (units: km).
// The prepare pass bakes it into a small sky lookup table and the frame's light colours (colortex7), everything else
// reads those, so the march runs for a few thousand pixels per frame only.

const float PLANET_RADIUS = 6371.0;
const float ATMOSPHERE_RADIUS = 6471.0;
const float RAYLEIGH_HEIGHT = 8.0;
const float MIE_HEIGHT = 1.2;
const vec3 RAYLEIGH_BETA = vec3(5.8e-3, 13.5e-3, 33.1e-3);
const float MIE_BETA = 9e-3;
const float MIE_G = 0.8;
// Ozone absorbs mostly green-orange light; it keeps twilight skies blue instead of grey-green. Expressed per unit of
// Rayleigh optical depth, since both follow the air column.
const vec3 OZONE_PER_RAYLEIGH = vec3(1.2e-3, 3.5e-3, 0.16e-3) / RAYLEIGH_HEIGHT * 8.0;

const float SUN_ILLUMINANCE = 10.0;
const float MOON_ILLUMINANCE = 0.8;
// Single scattering alone leaves the sky too dim next to sunlit ground; this stands in for multiple scattering.
const float SKY_RADIANCE_SCALE = 1.8;
const vec3 MOON_TINT = vec3(0.62, 0.74, 1.0);

// Rain fills the air with droplets (more Mie haze) and greys the sky out.
float hazeFactor() {
    return 1.0 + rainStrength * 7.0;
}

float rayleighPhase(float mu) {
    return 3.0 / (16.0 * PI) * (1.0 + mu * mu);
}

float miePhase(float mu, float g) {
    float g2 = g * g;
    return 3.0 / (8.0 * PI) * ((1.0 - g2) * (1.0 + mu * mu)) / ((2.0 + g2) * pow(1.0 + g2 - 2.0 * g * mu, 1.5));
}

// Relative optical air mass for a ray leaving the ground at the given zenith cosine (Kasten & Young).
float airMass(float cosZenith) {
    float z = degrees(acos(clamp(cosZenith, -1.0, 1.0)));
    return 1.0 / (max(cosZenith, 0.0) + 0.50572 * pow(max(96.07995 - z, 0.5), -1.6364));
}

vec2 raySphere(vec3 origin, vec3 dir, float radius) {
    float b = dot(origin, dir);
    float c = dot(origin, origin) - radius * radius;
    float d = b * b - c;
    if (d < 0.0) {
        return vec2(-1.0);
    }
    d = sqrt(d);
    return vec2(-b - d, -b + d);
}

// Light of a body (sun or moon) that reaches the ground through the atmosphere.
vec3 directTransmittance(float cosZenith) {
    float m = airMass(cosZenith);
    vec3 tau = (RAYLEIGH_BETA + OZONE_PER_RAYLEIGH) * RAYLEIGH_HEIGHT + MIE_BETA * 1.11 * MIE_HEIGHT * hazeFactor();
    return exp(-tau * m) * smoothstep(-0.04, 0.06, cosZenith);
}

// Light scattered towards the viewer along dir by one light body of the given illuminance.
vec3 scatterAlong(vec3 dir, vec3 lightDir, vec3 illuminance, int steps) {
    vec3 origin = vec3(0.0, PLANET_RADIUS + 0.3, 0.0);
    dir.y = max(dir.y, 0.0);
    dir = normalize(dir);

    float tMax = raySphere(origin, dir, ATMOSPHERE_RADIUS).y;
    float mu = dot(dir, lightDir);
    float haze = hazeFactor();
    float phaseR = rayleighPhase(mu);
    float phaseM = miePhase(mu, MIE_G * (1.0 - 0.45 * rainStrength));

    vec3 result = vec3(0.0);
    vec2 viewDepth = vec2(0.0);
    float prevT = 0.0;
    for (int i = 0; i < steps; i++) {
        float f = (float(i) + 1.0) / float(steps);
        float t = tMax * f * f;
        float dt = t - prevT;
        float tMid = prevT + dt * 0.5;
        prevT = t;

        vec3 p = origin + dir * tMid;
        float r = length(p);
        float h = max(r - PLANET_RADIUS, 0.0);
        vec2 density = exp(-h / vec2(RAYLEIGH_HEIGHT, MIE_HEIGHT));
        viewDepth += density * dt;

        // Planet shadow: the light ray from this point hits the ground.
        float cosLight = dot(p / r, lightDir);
        float horizonCos = -sqrt(max(1.0 - sqr(PLANET_RADIUS / r), 0.0));
        float lit = smoothstep(horizonCos - 0.01, horizonCos + 0.03, cosLight);
        if (lit <= 0.0) {
            continue;
        }

        vec2 lightDepth = density * vec2(RAYLEIGH_HEIGHT, MIE_HEIGHT) * airMass(cosLight);
        vec2 depth = viewDepth + lightDepth;
        vec3 transmittance = exp(-((RAYLEIGH_BETA + OZONE_PER_RAYLEIGH) * depth.x + MIE_BETA * 1.11 * haze * depth.y));
        result += (RAYLEIGH_BETA * density.x * phaseR + MIE_BETA * haze * density.y * phaseM) * transmittance * dt * lit;
    }
    return result * illuminance;
}

vec3 rainGrey(vec3 color) {
    float l = luminance(color);
    return mix(color, vec3(l) * vec3(0.92, 0.96, 1.0), rainStrength * 0.75) * (1.0 - rainStrength * 0.5) * (1.0 - thunderStrength * 0.45);
}

// Full sky radiance (sun + moon scattering + faint airglow), in world space directions.
vec3 skyRadiance(vec3 dir, vec3 sunDir, int steps) {
    vec3 sky = scatterAlong(dir, sunDir, vec3(SUN_ILLUMINANCE), steps);
    sky += scatterAlong(dir, -sunDir, MOON_TINT * MOON_ILLUMINANCE, steps / 2 + 1);
    sky = sky * SKY_RADIANCE_SCALE + vec3(0.0016, 0.0022, 0.0038) * (1.0 + 2.0 * saturate(dir.y));
    return rainGrey(sky);
}

// --- Sky lookup table in colortex7 -----------------------------------------------------------------------------
// Row 0 holds single values (light colours), the table starts at row 1. It is indexed by the angle between the view
// direction and the sun around the vertical axis (the sky is mirror-symmetric around the sun's vertical plane, the
// moon is always opposite the sun) and by elevation, packed with a square root for more detail near the horizon.

const ivec2 SKY_LUT_SIZE = ivec2(64, 64);
const int SKY_LUT_ROW = 1;
const ivec2 PIXEL_LIGHT_COLOR = ivec2(0, 0);
const ivec2 PIXEL_AMBIENT_COLOR = ivec2(1, 0);
const ivec2 PIXEL_SUN_COLOR = ivec2(2, 0);

vec2 skyLutCoord(vec3 dir, vec3 sunDir) {
    vec2 a = dir.xz;
    vec2 b = sunDir.xz;
    float la = length(a);
    float lb = length(b);
    float cosAzimuth = (la > 1e-4 && lb > 1e-4) ? dot(a / la, b / lb) : 1.0;
    float u = acos(clamp(cosAzimuth, -1.0, 1.0)) / PI;
    float v = 0.5 + 0.5 * sign(dir.y) * sqrt(abs(dir.y));
    return vec2(u, v);
}

vec3 skyLutDirection(vec2 uv, vec3 sunDir) {
    float s = uv.y * 2.0 - 1.0;
    float y = sign(s) * s * s;
    float azimuth = uv.x * PI;
    vec2 sunXZ = length(sunDir.xz) > 1e-4 ? normalize(sunDir.xz) : vec2(1.0, 0.0);
    float base = atan(sunXZ.y, sunXZ.x);
    float horizontal = sqrt(max(1.0 - y * y, 0.0));
    return vec3(cos(base + azimuth) * horizontal, y, sin(base + azimuth) * horizontal);
}

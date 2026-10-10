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
const float MOON_ILLUMINANCE = 0.5;
// Single scattering alone leaves the sky too dim next to sunlit ground; this stands in for multiple scattering.
const float SKY_RADIANCE_SCALE = 1.8;
const vec3 MOON_TINT = vec3(0.78, 0.85, 1.0);

// Moon brightness by phase (0 = full moon ... 4 = new moon).
float moonPhaseLight() {
    float lit = abs(float(moonPhase) - 4.0) / 4.0;
    return mix(0.15, 1.0, lit);
}

// Rain fills the air with droplets: a little more Mie haze in what is left of the clear sky (the overcast model
// below takes over the sky itself).
float hazeFactor() {
    return 1.0 + rainStrength * 2.0;
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

// The eye adapts to the colour of the light it is in: a low sun looks golden rather than deep red, a midday sun
// close to white. Softens the hue of a transmittance, keeps its luminance.
vec3 adaptedTint(vec3 transmittance) {
    float m = max(max(transmittance.r, transmittance.g), max(transmittance.b, 1e-6));
    vec3 c = pow(transmittance / m, vec3(0.6));
    return c * (luminance(transmittance) / max(luminance(c), 1e-6));
}

// Share of a light body's direct light while it is up. Zero at the horizon: Iris switches the shadow light between
// sun and moon there, and neither may light the world from the other's direction.
float aboveHorizon(float cosZenith) {
    return smoothstep(0.0, 0.07, cosZenith);
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

// --- Weather ----------------------------------------------------------------------------------------------------

// Brightness of a lightning flash right now (0 without one): a bolt flickers in a few strokes. One value per frame,
// the same for every pixel.
float lightningFlash() {
    if (lightningBoltPosition.w < 0.5) {
        return 0.0;
    }
    float stroke = hash12(vec2(floor(frameTimeCounter * 14.0), 7.0));
    return 0.35 + 0.65 * step(0.45, stroke);
}

const vec3 FLASH_TINT = vec3(0.8, 0.86, 1.0);

// Sky radiance a flash adds to the cloud deck (zenith value; it follows the overcast shape).
vec3 flashSkyRadiance() {
    return FLASH_TINT * lightningFlash() * 0.9 * rainStrength;
}

// Overcast sky: brightness relative to the zenith value. Rain: a softened CIE overcast sky (the horizon darker than
// the zenith, never a glowing band). Thunderstorm: dark down to the horizon, so the distance disappears into a dark
// haze rather than a white one. Blizzard: the same brightness everywhere, a white-out. All scaled to the same
// cos-weighted mean (0.818), so they light the ground the same.
float overcastShape(float elevation) {
    float e = saturate(elevation);
    float rain = (1.0 + 1.2 * e) / 2.2;
    // cos-weighted mean of (1 - e)^2 is 1/6: 0.9 - 0.35 / 6 = 0.842.
    float storm = (0.9 - 0.35 * sqr(1.0 - e)) * (0.818 / 0.842);
    float shape = mix(rain, storm, stormDarkness());
    return mix(shape, 0.818, snowWeather * thunderStrength);
}

// cos-weighted mean of overcastShape over the sky, x the ambient's multiple scattering factor (1.4) x pi.
const float OVERCAST_IRRADIANCE = 1.4 * PI * 0.818;

// All light that sun and moon would bring to the ground on a clear day (direct + sky, lux-like units, fitted to
// the clear-sky values of this atmosphere). An overcast deck spreads a share of it evenly over the sky.
float clearDaylight(vec3 sunDir) {
    float sunY = sunDir.y;
    float day = luminance(SUN_ILLUMINANCE * exp(-((RAYLEIGH_BETA + OZONE_PER_RAYLEIGH) * RAYLEIGH_HEIGHT
            + MIE_BETA * 1.11 * MIE_HEIGHT) * airMass(sunY))) * max(sunY, 0.0)
            + 1.1 * smoothstep(-0.12, 0.35, sunY);
    float night = MOON_ILLUMINANCE * moonPhaseLight() * (0.3 * max(-sunY, 0.0) + 0.04) * smoothstep(0.05, -0.1, sunY);
    return day + night;
}

// Zenith radiance of the overcast deck: rain lets about a fifth of the daylight through, a thunderstorm about a
// twentieth. Snow clouds are thinner and the white ground lights them from below: a snowy sky stays bright and
// neutral white, in a blizzard too.
vec3 overcastZenith(vec3 sunDir) {
    float through = mix(mix(0.2, 0.045, stormDarkness()), 0.3, snowWeather);
    vec3 tint = mix(vec3(0.93, 0.97, 1.05), vec3(0.78, 0.85, 1.0), stormDarkness());
    tint = mix(tint, vec3(0.97, 0.99, 1.03), snowWeather);
    return tint * clearDaylight(sunDir) * through / OVERCAST_IRRADIANCE + flashSkyRadiance();
}

// Hue of sunlight that has crossed the air at elevation sine y (brightest channel 1): white high up, golden, then
// orange and red towards the horizon; softened like adaptedTint.
vec3 lowSunHue(float y) {
    vec3 t = exp(-((RAYLEIGH_BETA + OZONE_PER_RAYLEIGH) * RAYLEIGH_HEIGHT + MIE_BETA * 1.11 * MIE_HEIGHT) * airMass(max(y, 0.0)));
    return pow(t / max(max(t.r, t.g), max(t.b, 1e-6)), vec3(0.5));
}

// How much of the sunset / twilight look there is: strongest with the sun right at the horizon, gone once it is about
// 9 degrees up (higher, it only tinted the whole morning lemon yellow) or 11 degrees down.
float twilightAmount(float sunY) {
    return smoothstep(-0.2, -0.03, sunY) * (1.0 - smoothstep(0.02, 0.16, sunY));
}

// The colours of sunrise and sunset that single scattering alone cannot give (it leaves a thin red line at the
// horizon under a grey sky): light scattered many times through the low, dusty air.
//  - Over the sun a wide arch: gold and orange at the horizon, through rose into violet higher up. Sunrise is pinker,
//    sunset more orange and red.
//  - On the opposite side, where the moon sets or rises: once the sun is down, the blue-grey shadow of the Earth
//    rises from the horizon, with the pink Belt of Venus above it.
//  - Overhead the sky deepens into the blue hour (ozone absorption, which single scattering underplays).
// Returns rgb to add and, in w, how much of the sky light the Earth's shadow takes away.
vec4 twilightGlow(vec3 dir, vec3 sunDir) {
    float amount = twilightAmount(sunDir.y);
    if (amount <= 0.0) {
        return vec4(0.0);
    }
    float m = morning();
    float la = length(dir.xz);
    float lb = length(sunDir.xz);
    float toward = (la > 1e-4 && lb > 1e-4) ? 0.5 + 0.5 * dot(dir.xz / la, sunDir.xz / lb) : 0.5;
    float away = 1.0 - toward;
    float e = max(dir.y, 0.0);

    vec3 horizon = lowSunHue(sunDir.y + 0.04);
    horizon = mix(horizon, vec3(1.0, 0.42, 0.38), 0.35 * m);
    vec3 rose = mix(vec3(1.0, 0.42, 0.45), vec3(0.95, 0.45, 0.75), m);
    float archHeight = mix(0.08, 0.28, toward * toward);
    vec3 arch = mix(rose, horizon, exp(-e / 0.07)) * exp(-e / archHeight) * (0.15 + 0.85 * toward * toward);

    float below = smoothstep(0.03, -0.05, sunDir.y);
    float beltHeight = mix(0.06, 0.16, below);
    float belt = exp(-sqr((e - beltHeight) / 0.08)) * away * away;
    vec3 beltColor = mix(vec3(1.0, 0.55, 0.6), vec3(0.95, 0.55, 0.8), m);
    float shadow = below * exp(-e / 0.06) * away * away * 0.45;

    vec3 blueHour = vec3(0.1, 0.3, 1.0) * 0.014 * smoothstep(0.0, 0.6, e);
    // Kept moderate: stronger, the pink and orange washed over the land, the sea and every cloud (fog, reflections and
    // the ambient light all take the sky colour).
    return vec4((arch * 0.22 + beltColor * belt * 0.07 + blueHour) * amount, shadow * amount);
}

// Full sky radiance (sun + moon scattering + faint airglow), in world space directions; rain blends in the overcast
// deck.
vec3 skyRadiance(vec3 dir, vec3 sunDir, int steps) {
    vec3 sky = scatterAlong(dir, sunDir, vec3(SUN_ILLUMINANCE), steps);
    sky += scatterAlong(dir, -sunDir, MOON_TINT * MOON_ILLUMINANCE * moonPhaseLight(), steps / 2 + 1);
    vec3 airglow = vec3(0.0016, 0.0022, 0.0038) * (1.0 + 2.0 * saturate(dir.y));
    vec4 twilight = twilightGlow(dir, sunDir);
    sky *= SKY_RADIANCE_SCALE * (1.0 - twilight.w);
    float twilightNow = twilightAmount(sunDir.y);
    // Near the horizon the light has crossed so much air that it was scattered many times over and comes out pale,
    // close to white. Single scattering alone reddens it there: a thin brownish band along the horizon by day and
    // night. Sunset keeps its own colours.
    float horizon = exp(-max(dir.y, 0.0) / 0.04) * (1.0 - twilightNow);
    sky = mix(sky, vec3(luminance(sky)) * vec3(0.97, 1.0, 1.04), horizon * 0.75);
    // The low sun's light reaches the sky through the dusty lower air: richer colour than the clean model gives.
    sky = max(mix(vec3(luminance(sky)), sky, 1.0 + 0.2 * twilightNow), 0.0);
    sky += airglow + twilight.rgb;
    if (rainStrength > 0.0) {
        // Below the horizon (reflections, fog looking down) the deck's light is what the ground bounces back.
        float shape = dir.y >= 0.0 ? overcastShape(dir.y) : overcastShape(0.0) * 0.8;
        vec3 overcast = overcastZenith(sunDir) * shape + airglow;
        sky = mix(sky, overcast, rainStrength);
    }
    return sky;
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

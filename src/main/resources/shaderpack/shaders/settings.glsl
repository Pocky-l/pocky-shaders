// Pack options. Every "// [...]" list is an option Iris shows in the shader pack menu; profiles in
// shaders.properties set them together (Low / Medium / High / Ultra).

#define QUALITY 1 // [0 1 2 3]

// Lighting
#define SHADOWS
const int shadowMapResolution = 2048; // [1024 1536 2048 3072 4096]
const float shadowDistance = 192.0; // [96.0 128.0 160.0 192.0 256.0 320.0 384.0 512.0]
// Shadow casters are drawn into the shadow map only within the shadow distance (by default Iris draws every chunk of
// the render distance, all of it wasted beyond the shadow distance).
const float shadowDistanceRenderMul = 1.0;
// The shadow map stays fixed to the world and moves after the player only every 16 blocks: each move re-maps the shadow
// texels (the distortion is centred on the map), so with Iris' default 2 blocks crisp shadows jerked while walking,
// and following smoothly (0) made every edge and grass blade flicker as the texels slid under the world.
const float shadowIntervalSize = 16.0;
// 1 = crisp pixel shadows on the 1/16-block texel grid of the textures (cheap), 0 = soft filtered shadows.
#define SHADOW_STYLE 1 // [0 1]
#define SHADOW_SOFTNESS 1.0 // [0.5 0.75 1.0 1.5 2.0 3.0]
// Share of the sunlight that still reaches shaded places (0 = realistic dark shade).
#define SHADOW_LIGHT 0.2 // [0.0 0.1 0.2 0.3 0.4]
#define COLORED_SHADOWS
#define SSAO
#define SSAO_STRENGTH 1.0 // [0.5 0.75 1.0 1.25 1.5 2.0]
#define HANDHELD_LIGHT
#define SURFACE_SHEEN
#define BLOCK_LIGHT_WARMTH 1.0 // [0.0 0.5 1.0 1.5]
#define AMBIENT_MIN 0.012 // [0.0 0.006 0.012 0.025 0.05]

// Nature
#define WAVING_PLANTS
#define WAVING_LEAVES
#define WIND_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0]
#define FOLIAGE_TRANSLUCENCY
#define WET_SURFACES

// Water
#define WATER_REFLECTIONS 2 // [0 1 2]
#define WATER_REFRACTION
#define WATER_WAVE_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define WATER_CLARITY 1.0 // [0.5 0.75 1.0 1.5 2.0]
#define WATER_CAUSTICS
#define WATER_FOAM

// Sky
#define CLOUDS 2 // [0 1 2]
#define CLOUD_COVERAGE 1.0 // [0.5 0.75 1.0 1.25 1.5]
#define CLOUD_SIZE 1.6 // [1.0 1.3 1.6 2.0 2.5 3.0]
#define CLOUD_HEIGHT 1.5 // [1.0 1.25 1.5 2.0 2.5]
#define LIGHT_SHAFTS
#define LIGHT_SHAFT_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define FOG_DENSITY 1.0 // [0.0 0.25 0.5 0.75 1.0 1.5 2.0]
#define VALLEY_MIST
#define FAR_HAZE 1.0 // [0.0 0.5 1.0 1.5 2.0]
#define LOW_HAZE 1.0 // [0.0 0.5 0.75 1.0 1.5 2.0]

// Post processing
#define BLOOM
#define BLOOM_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define LENS_FLARE
#define LENS_FLARE_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.5 2.0]
#define EXPOSURE 1.0 // [0.6 0.8 1.0 1.2 1.4 1.6]
#define SATURATION 1.0 // [0.6 0.8 0.9 1.0 1.1 1.2 1.4]
#define WARMTH 1.0 // [0.0 0.5 1.0 1.5 2.0]
#define FXAA

// Debug: 1 = colour each pixel by who drew it (vanilla chunks / Distant Horizons / water).
#define DEBUG_VIEW 0 // [0 1]

// Iris lists a boolean option in its menu only when some file tests it with #ifdef (a "#if defined X && ..." test
// does not count, and several options are only tested that way). These empty tests make every one of them show.
#ifdef SHADOWS
#endif
#ifdef COLORED_SHADOWS
#endif
#ifdef SSAO
#endif
#ifdef HANDHELD_LIGHT
#endif
#ifdef SURFACE_SHEEN
#endif
#ifdef WAVING_PLANTS
#endif
#ifdef WAVING_LEAVES
#endif
#ifdef FOLIAGE_TRANSLUCENCY
#endif
#ifdef WET_SURFACES
#endif
#ifdef WATER_REFRACTION
#endif
#ifdef WATER_CAUSTICS
#endif
#ifdef WATER_FOAM
#endif
#ifdef LIGHT_SHAFTS
#endif
#ifdef VALLEY_MIST
#endif
#ifdef BLOOM
#endif
#ifdef LENS_FLARE
#endif
#ifdef FXAA
#endif

const float sunPathRotation = -20.0; // [-40.0 -30.0 -20.0 -10.0 0.0 10.0 20.0 30.0 40.0]

#if QUALITY == 0
    #define SHADOW_SAMPLES 4
    #define SSAO_SAMPLES 4
    #define SSR_STEPS 0
    #define SKY_STEPS 6
    #define CLOUD_STEPS 10
    #define LIGHT_SHAFT_STEPS 8
    #define SS_SHADOW_STEPS 10
    #define SS_SHADOW_GROWTH 1.73
    #define MIST_STEPS 6
#elif QUALITY == 1
    #define SHADOW_SAMPLES 8
    #define SSAO_SAMPLES 6
    #define SSR_STEPS 16
    #define SKY_STEPS 8
    #define CLOUD_STEPS 14
    #define LIGHT_SHAFT_STEPS 12
    #define SS_SHADOW_STEPS 14
    #define SS_SHADOW_GROWTH 1.43
    #define MIST_STEPS 8
#elif QUALITY == 2
    #define SHADOW_SAMPLES 12
    #define SSAO_SAMPLES 8
    #define SSR_STEPS 24
    #define SKY_STEPS 10
    #define CLOUD_STEPS 20
    #define LIGHT_SHAFT_STEPS 16
    #define SS_SHADOW_STEPS 20
    #define SS_SHADOW_GROWTH 1.25
    #define MIST_STEPS 10
#else
    #define SHADOW_SAMPLES 16
    #define SSAO_SAMPLES 12
    #define SSR_STEPS 32
    #define SKY_STEPS 12
    #define CLOUD_STEPS 28
    #define LIGHT_SHAFT_STEPS 20
    #define SS_SHADOW_STEPS 24
    #define SS_SHADOW_GROWTH 1.19
    #define MIST_STEPS 12
#endif

package com.pockyl.pocky_shaders.client.weather;

import net.minecraft.client.Minecraft;
import net.minecraft.world.phys.Vec3;
import net.neoforged.fml.ModList;

import com.pockyl.pocky_shaders.PockyShaders;

import java.lang.invoke.MethodHandle;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.MethodType;
import java.lang.reflect.Field;

/**
 * The weather of the author's other mods as the pack sees it: Petrichor (rain types, sun showers, wetness, rainbows,
 * lightning), Hoarfrost (snow kinds, blizzards, visibility) and Rustling Leaves (the wind and its gusts). All of them
 * are optional and reached by reflection, so none is needed to build or run this mod; a reader that fails once (an
 * incompatible version) is switched off for the session and the pack falls back to vanilla weather.
 *
 * <p>Layout of the texels written by {@link #write} (see {@code lib/modweather.glsl}):
 * <pre>
 * 0  petrichor present, rain 0..1, rain level 0..1 (drizzle .. thunderstorm), sunshine (sun shower)
 * 1  wetness, rainbow strength, rainbow side (1 east, -1 west), lightning flash
 * 2  gust factor of the rain, sky view, -, -
 * 3  hoarfrost present, snow 0..1, snow streaming in the wind 0..1 (blizzards), visibility (blocks)
 * 4  snow density, accumulation, gust factor, -
 * 5  wind present, direction x, direction z, speed (blocks per tick)
 * 6  wind drift x, drift z (blocks, wrapped), share of the leaves' wind, phase of the leaves' gust waves
 * 7  marker 0.123, 0.456, 0.789, 1 (a missing texture never reads like this)
 * </pre>
 */
final class ModWeather {
    static final int TEXELS = 8;

    /** The leaves' gusts mix sin(s) and sin(2.7 s): both repeat after 20 pi. */
    private static final float GUST_PERIOD = 20.0F * (float) Math.PI;
    private static final double DRIFT_WRAP = 100000.0;
    /** The wind direction turns towards the current source over about 5 seconds. */
    private static final float WIND_FOLLOW = 0.01F;

    private final Petrichor petrichor = Petrichor.create();
    private final Hoarfrost hoarfrost = Hoarfrost.create();
    private final Leaves leaves = Leaves.create();

    private float windX;
    private float windZ;
    private float dirX = 1.0F;
    private float dirZ = 0.35F;
    private float leavesShare;
    private double driftX;
    private double driftZ;
    private float leavesTime = Float.NaN;
    private long leavesTimeChanged;

    void write(float[] out, float partialTick, float frameTicks) {
        java.util.Arrays.fill(out, 0.0F);
        Vec3 camera = Minecraft.getInstance().gameRenderer.getMainCamera().getPosition();
        float rain = 0.0F;
        float snow = 0.0F;
        float rainWindX = 0.0F;
        float rainWindZ = 0.0F;
        float snowWindX = 0.0F;
        float snowWindZ = 0.0F;

        if (petrichor.available()) {
            try {
                rain = petrichor.rain();
                out[0] = 1.0F;
                out[1] = rain;
                out[2] = Math.clamp(petrichor.level() / 3.0F, 0.0F, 1.0F);
                out[3] = petrichor.sunshine();
                out[4] = petrichor.wetness();
                out[5] = petrichor.rainbow();
                out[6] = petrichor.rainbowSide();
                out[7] = petrichor.flash(partialTick);
                out[8] = rain > 0.001F ? petrichor.intensity() / rain : 1.0F;
                out[9] = petrichor.skyView(partialTick);
                rainWindX = petrichor.windX();
                rainWindZ = petrichor.windZ();
            } catch (Throwable e) {
                petrichor.fail(e);
                java.util.Arrays.fill(out, 0, 12, 0.0F);
                rain = 0.0F;
            }
        }
        if (hoarfrost.available()) {
            try {
                snow = hoarfrost.snow();
                out[12] = 1.0F;
                out[13] = snow;
                out[14] = hoarfrost.stream();
                out[15] = hoarfrost.visibility();
                out[16] = hoarfrost.density();
                out[17] = hoarfrost.accumulation();
                out[18] = hoarfrost.gust();
                float speed = hoarfrost.windSpeed();
                snowWindX = hoarfrost.windDirX() * speed;
                snowWindZ = hoarfrost.windDirZ() * speed;
            } catch (Throwable e) {
                hoarfrost.fail(e);
                java.util.Arrays.fill(out, 12, 20, 0.0F);
                snow = 0.0F;
            }
        }
        float leafWindX = 0.0F;
        float leafWindZ = 0.0F;
        float phase = 0.0F;
        boolean leafWind = false;
        if (leaves.available()) {
            try {
                Object wind = leaves.wind();
                if (wind != null) {
                    float speed = leaves.base(wind) + 0.18F * leaves.squall(wind, camera.x, camera.z);
                    leafWindX = leaves.dirX(wind) * speed;
                    leafWindZ = leaves.dirZ(wind) * speed;
                    phase = leavesPhase(leaves.time(wind));
                    leafWind = true;
                }
            } catch (Throwable e) {
                leaves.fail(e);
            }
        }

        // One wind for the whole pack: the rain's while it rains, the snow's while it snows (Hoarfrost blows the same
        // way as Petrichor), the leaves' otherwise.
        float weather = Math.min(1.0F, rain + snow);
        float leafWeight = leafWind ? 1.0F - weather : 0.0F;
        float total = leafWeight + rain + snow;
        boolean anyWind = total > 0.001F && (leafWind || petrichor.available() || hoarfrost.available());
        if (anyWind) {
            float targetX = (leafWindX * leafWeight + rainWindX * rain + snowWindX * snow) / total;
            float targetZ = (leafWindZ * leafWeight + rainWindZ * rain + snowWindZ * snow) / total;
            float follow = 1.0F - (float) Math.pow(1.0F - WIND_FOLLOW, Math.max(frameTicks, 0.0F) * 3.0F);
            windX += (targetX - windX) * follow;
            windZ += (targetZ - windZ) * follow;
            leavesShare += (leafWeight / total - leavesShare) * follow;
            float speed = (float) Math.sqrt(windX * windX + windZ * windZ);
            if (speed > 1.0E-4F) {
                dirX = windX / speed;
                dirZ = windZ / speed;
            }
            driftX = (driftX + windX * frameTicks) % DRIFT_WRAP;
            driftZ = (driftZ + windZ * frameTicks) % DRIFT_WRAP;
            out[20] = 1.0F;
            out[21] = dirX;
            out[22] = dirZ;
            out[23] = speed;
            out[24] = (float) driftX;
            out[25] = (float) driftZ;
            out[26] = leafWind ? leavesShare : 0.0F;
            out[27] = phase;
        }
        out[28] = 0.123F;
        out[29] = 0.456F;
        out[30] = 0.789F;
        out[31] = 1.0F;
    }

    /** The leaves' gust phase with the time since their last tick added, so the gusts glide between ticks. */
    private float leavesPhase(float time) {
        long now = System.nanoTime();
        if (time != leavesTime) {
            leavesTime = time;
            leavesTimeChanged = now;
        }
        float since = Math.min((now - leavesTimeChanged) / 50_000_000.0F, 1.0F);
        float s = (float) (((double) (time + since) * 0.025) % GUST_PERIOD);
        return s < 0.0F ? s + GUST_PERIOD : s;
    }

    String describe() {
        return "petrichor " + petrichor.state() + ", hoarfrost " + hoarfrost.state() + ", rustling_leaves " + leaves.state();
    }

    // ----------------------------------------------------------------------------------------------------------------

    private abstract static class Source {
        private final String modId;
        private boolean failed;

        Source(String modId, boolean found) {
            this.modId = modId;
            this.failed = !found;
        }

        boolean available() {
            return !failed;
        }

        void fail(Throwable e) {
            if (!failed) {
                failed = true;
                PockyShaders.LOGGER.warn("Pocky Shaders: weather of {} not available to the pack, using vanilla weather: {}", modId, e.toString());
            }
        }

        String state() {
            return !ModList.get().isLoaded(modId) ? "absent" : failed ? "incompatible" : "linked";
        }

        static MethodHandle staticFloat(Class<?> owner, String name) throws ReflectiveOperationException {
            return MethodHandles.publicLookup().findStatic(owner, name, MethodType.methodType(float.class));
        }

        static MethodHandle staticFloatOfTick(Class<?> owner, String name) throws ReflectiveOperationException {
            return MethodHandles.publicLookup().findStatic(owner, name, MethodType.methodType(float.class, float.class));
        }

        /** A getter for a (possibly private) field; mod jars are automatic modules, open to reflection. */
        static MethodHandle getter(Class<?> owner, String name) throws ReflectiveOperationException {
            Field field = owner.getDeclaredField(name);
            field.setAccessible(true);
            return MethodHandles.lookup().unreflectGetter(field);
        }

        static Class<?> load(String name) throws ClassNotFoundException {
            return Class.forName(name, true, ModWeather.class.getClassLoader());
        }
    }

    private static final class Petrichor extends Source {
        private MethodHandle rain;
        private MethodHandle level;
        private MethodHandle sunshine;
        private MethodHandle wetness;
        private MethodHandle intensity;
        private MethodHandle windX;
        private MethodHandle windZ;
        private MethodHandle flash;
        private MethodHandle skyView;
        private MethodHandle rainbow;
        private MethodHandle rainbowSide;

        private Petrichor(boolean found) {
            super("petrichor", found);
        }

        static Petrichor create() {
            if (!ModList.get().isLoaded("petrichor")) {
                return new Petrichor(false);
            }
            Petrichor source = new Petrichor(true);
            try {
                Class<?> weather = load("com.pockyl.petrichor.client.ClientWeather");
                Class<?> client = load("com.pockyl.petrichor.client.WeatherClient");
                Class<?> bow = load("com.pockyl.petrichor.client.render.Rainbow");
                source.rain = staticFloat(weather, "rain");
                source.level = staticFloat(weather, "level");
                source.sunshine = staticFloat(weather, "sunshine");
                source.wetness = staticFloat(weather, "wetness");
                source.intensity = staticFloat(weather, "intensity");
                source.windX = staticFloat(weather, "windX");
                source.windZ = staticFloat(weather, "windZ");
                source.flash = staticFloatOfTick(client, "flash");
                source.skyView = staticFloatOfTick(client, "skyView");
                source.rainbow = staticFloat(bow, "strength");
                source.rainbowSide = getter(bow, "sunSide");
            } catch (Throwable e) {
                source.fail(e);
            }
            return source;
        }

        float rain() throws Throwable {
            return (float) rain.invokeExact();
        }

        float level() throws Throwable {
            return (float) level.invokeExact();
        }

        float sunshine() throws Throwable {
            return (float) sunshine.invokeExact();
        }

        float wetness() throws Throwable {
            return (float) wetness.invokeExact();
        }

        float intensity() throws Throwable {
            return (float) intensity.invokeExact();
        }

        float windX() throws Throwable {
            return (float) windX.invokeExact();
        }

        float windZ() throws Throwable {
            return (float) windZ.invokeExact();
        }

        float flash(float partialTick) throws Throwable {
            return (float) flash.invokeExact(partialTick);
        }

        float skyView(float partialTick) throws Throwable {
            return (float) skyView.invokeExact(partialTick);
        }

        float rainbow() throws Throwable {
            return (float) rainbow.invokeExact();
        }

        float rainbowSide() throws Throwable {
            return (float) rainbowSide.invokeExact();
        }
    }

    private static final class Hoarfrost extends Source {
        private MethodHandle snow;
        private MethodHandle gust;
        private MethodHandle conditions;
        private MethodHandle stream;
        private MethodHandle visibility;
        private MethodHandle density;
        private MethodHandle accumulation;
        private MethodHandle windDirX;
        private MethodHandle windDirZ;
        private MethodHandle windSpeed;
        private Object current;

        private Hoarfrost(boolean found) {
            super("hoarfrost", found);
        }

        static Hoarfrost create() {
            if (!ModList.get().isLoaded("hoarfrost")) {
                return new Hoarfrost(false);
            }
            Hoarfrost source = new Hoarfrost(true);
            try {
                Class<?> weather = load("com.pockyl.hoarfrost.client.ClientWeather");
                Class<?> conditions = load("com.pockyl.hoarfrost.weather.SnowConditions");
                source.snow = staticFloat(weather, "snow");
                source.gust = staticFloat(weather, "gust");
                source.conditions = MethodHandles.publicLookup().findStatic(weather, "conditions", MethodType.methodType(conditions))
                        .asType(MethodType.methodType(Object.class));
                source.stream = field(conditions, "stream");
                source.visibility = field(conditions, "visibility");
                source.density = field(conditions, "density");
                source.accumulation = field(conditions, "accumulation");
                source.windDirX = field(conditions, "windDirX");
                source.windDirZ = field(conditions, "windDirZ");
                source.windSpeed = field(conditions, "windSpeed");
            } catch (Throwable e) {
                source.fail(e);
            }
            return source;
        }

        private static MethodHandle field(Class<?> owner, String name) throws ReflectiveOperationException {
            return MethodHandles.publicLookup().findGetter(owner, name, float.class)
                    .asType(MethodType.methodType(float.class, Object.class));
        }

        float snow() throws Throwable {
            current = (Object) conditions.invokeExact();
            return (float) snow.invokeExact();
        }

        float gust() throws Throwable {
            return (float) gust.invokeExact();
        }

        float stream() throws Throwable {
            return (float) stream.invokeExact(current);
        }

        float visibility() throws Throwable {
            return (float) visibility.invokeExact(current);
        }

        float density() throws Throwable {
            return (float) density.invokeExact(current);
        }

        float accumulation() throws Throwable {
            return (float) accumulation.invokeExact(current);
        }

        float windDirX() throws Throwable {
            return (float) windDirX.invokeExact(current);
        }

        float windDirZ() throws Throwable {
            return (float) windDirZ.invokeExact(current);
        }

        float windSpeed() throws Throwable {
            return (float) windSpeed.invokeExact(current);
        }
    }

    private static final class Leaves extends Source {
        private MethodHandle simulation;
        private MethodHandle wind;
        private MethodHandle dirX;
        private MethodHandle dirZ;
        private MethodHandle squall;
        private MethodHandle base;
        private MethodHandle time;

        private Leaves(boolean found) {
            super("rustling_leaves", found);
        }

        static Leaves create() {
            if (!ModList.get().isLoaded("rustling_leaves")) {
                return new Leaves(false);
            }
            Leaves source = new Leaves(true);
            try {
                Class<?> manager = load("com.pockyl.rustling_leaves.client.LeafManager");
                Class<?> sim = load("com.pockyl.rustling_leaves.sim.LeafSimulation");
                Class<?> windClass = load("com.pockyl.rustling_leaves.sim.Wind");
                source.simulation = getter(manager, "simulation").asType(MethodType.methodType(Object.class));
                source.wind = MethodHandles.publicLookup().findVirtual(sim, "wind", MethodType.methodType(windClass))
                        .asType(MethodType.methodType(Object.class, Object.class));
                source.dirX = MethodHandles.publicLookup().findVirtual(windClass, "dirX", MethodType.methodType(float.class))
                        .asType(MethodType.methodType(float.class, Object.class));
                source.dirZ = MethodHandles.publicLookup().findVirtual(windClass, "dirZ", MethodType.methodType(float.class))
                        .asType(MethodType.methodType(float.class, Object.class));
                source.squall = MethodHandles.publicLookup().findVirtual(windClass, "squall",
                        MethodType.methodType(float.class, double.class, double.class))
                        .asType(MethodType.methodType(float.class, Object.class, double.class, double.class));
                source.base = getter(windClass, "base").asType(MethodType.methodType(float.class, Object.class));
                source.time = getter(windClass, "time").asType(MethodType.methodType(float.class, Object.class));
            } catch (Throwable e) {
                source.fail(e);
            }
            return source;
        }

        /** The leaves' wind, null while their simulation does not run (no world yet). */
        Object wind() throws Throwable {
            Object sim = (Object) simulation.invokeExact();
            return sim == null ? null : (Object) wind.invokeExact(sim);
        }

        float dirX(Object wind) throws Throwable {
            return (float) dirX.invokeExact(wind);
        }

        float dirZ(Object wind) throws Throwable {
            return (float) dirZ.invokeExact(wind);
        }

        float squall(Object wind, double x, double z) throws Throwable {
            return (float) squall.invokeExact(wind, x, z);
        }

        float base(Object wind) throws Throwable {
            return (float) base.invokeExact(wind);
        }

        float time(Object wind) throws Throwable {
            return (float) time.invokeExact(wind);
        }
    }
}

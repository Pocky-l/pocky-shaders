package com.pockyl.pocky_shaders.client.perf;

import net.minecraft.ChatFormatting;
import net.minecraft.client.Minecraft;
import net.minecraft.network.chat.Component;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.ModList;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.ClientTickEvent;
import org.lwjgl.opengl.GL11;

import com.pockyl.pocky_shaders.PockyShaders;
import com.pockyl.pocky_shaders.client.ShaderControl;
import com.pockyl.pocky_shaders.client.iris.IrisAccess;
import com.pockyl.pocky_shaders.pack.BundledPack;
import com.pockyl.pocky_shaders.pack.Preset;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

/**
 * {@code /shaders bench}: measures what each part of the pack costs. Step by step it switches one feature off (or
 * picks a preset, or turns shaders off), waits for the shaders to compile and the frame rate to settle, measures, and
 * finally restores the player's settings and writes a report to {@code pocky_shaders/benchmarks/}. VSync and the frame
 * rate limit are lifted while it runs, so the numbers show what the GPU can do.
 */
@EventBusSubscriber(modid = PockyShaders.MOD_ID, value = Dist.CLIENT)
public final class Benchmark {
    private static final long WARMUP_NANOS = 3_000_000_000L;
    private static final long MEASURE_NANOS = 6_000_000_000L;
    private static final int UNLIMITED_FPS = 260;

    /** One configuration to measure: options queued on top of the player's own, or shaders off. */
    private record Step(String id, String label, Map<String, String> options, boolean shadersOff) {
        static Step of(String id, String label, String... keyValues) {
            Map<String, String> options = new LinkedHashMap<>();
            for (int i = 0; i < keyValues.length; i += 2) {
                options.put(keyValues[i], keyValues[i + 1]);
            }
            return new Step(id, label, options, false);
        }
    }

    private record Row(Step step, FrameStats.Result result) {
    }

    private static List<Step> steps;
    private static List<Row> rows;
    private static int current;
    private static boolean measuringPhase;
    private static long phaseStart;
    private static byte[] savedOptions;
    private static boolean savedVsync;
    private static int savedFramerateLimit;

    private Benchmark() {
    }

    static boolean running() {
        return steps != null;
    }

    public static Component start() {
        if (running()) {
            return Component.translatable("pocky_shaders.bench.running").withStyle(ChatFormatting.RED);
        }
        if (!ShaderControl.active()) {
            return Component.translatable("pocky_shaders.bench.need_pack").withStyle(ChatFormatting.RED);
        }
        try {
            steps = buildSteps();
            Path optionsFile = optionsFile();
            savedOptions = Files.isRegularFile(optionsFile) ? Files.readAllBytes(optionsFile) : null;
        } catch (Exception e) {
            steps = null;
            PockyShaders.LOGGER.error("Benchmark could not start", e);
            return Component.translatable("pocky_shaders.message.failed", String.valueOf(e.getMessage()))
                    .withStyle(ChatFormatting.RED);
        }
        Minecraft mc = Minecraft.getInstance();
        savedVsync = mc.options.enableVsync().get();
        savedFramerateLimit = mc.options.framerateLimit().get();
        mc.options.enableVsync().set(false);
        mc.options.framerateLimit().set(UNLIMITED_FPS);
        rows = new ArrayList<>();
        current = 0;
        apply(steps.get(0));
        long minutes = Math.round(steps.size() * (WARMUP_NANOS + MEASURE_NANOS + 1_500_000_000L) / 60e9);
        return Component.translatable("pocky_shaders.bench.started", steps.size(), Math.max(minutes, 1));
    }

    public static Component stop() {
        if (!running()) {
            return Component.translatable("pocky_shaders.bench.not_running");
        }
        restore();
        return Component.translatable("pocky_shaders.bench.stopped");
    }

    /** Overlay line while a benchmark runs. */
    static Optional<Component> statusLine() {
        if (!running()) {
            return Optional.empty();
        }
        Step step = steps.get(current);
        Component phase = Component.translatable(paused() ? "pocky_shaders.bench.paused"
                : measuringPhase ? "pocky_shaders.bench.measuring" : "pocky_shaders.bench.warmup");
        return Optional.of(Component.translatable("pocky_shaders.bench.status", current + 1, steps.size(),
                Component.translatable("pocky_shaders.bench.step." + step.id()), phase));
    }

    private static List<Step> buildSteps() throws Exception {
        List<Step> list = new ArrayList<>();
        list.add(Step.of("current", "Current settings"));
        list.add(new Step("off", "Shaders off (no shader pack)", Map.of(), true));
        Map<Preset, Map<String, String>> profiles = BundledPack.profiles();
        for (Preset preset : Preset.values()) {
            Map<String, String> options = profiles.get(preset);
            if (options != null) {
                list.add(new Step("preset_" + preset.id(), "Preset " + preset.id(), options, false));
            }
        }
        list.add(Step.of("no_shadows", "No shadows", "SHADOWS", "false"));
        list.add(Step.of("shadow_1024", "Shadow map 1024", "shadowMapResolution", "1024"));
        list.add(Step.of("no_colored_shadows", "No coloured shadows", "COLORED_SHADOWS", "false"));
        list.add(Step.of("no_ssao", "No ambient occlusion", "SSAO", "false"));
        list.add(Step.of("no_clouds", "No clouds", "CLOUDS", "0"));
        list.add(Step.of("flat_clouds", "Flat clouds", "CLOUDS", "1"));
        list.add(Step.of("sky_reflections", "Sky-only water reflections (no SSR)", "WATER_REFLECTIONS", "1"));
        list.add(Step.of("no_light_shafts", "No light shafts", "LIGHT_SHAFTS", "false"));
        list.add(Step.of("no_bloom", "No bloom", "BLOOM", "false"));
        list.add(Step.of("no_fxaa", "No FXAA", "FXAA", "false"));
        list.add(Step.of("no_water_extras", "No caustics and foam", "WATER_CAUSTICS", "false", "WATER_FOAM", "false"));
        list.add(Step.of("no_fog_extras", "No low haze, far haze, mist", "LOW_HAZE", "0.0", "FAR_HAZE", "0.0",
                "VALLEY_MIST", "false"));
        list.add(Step.of("no_waving", "No waving plants and leaves", "WAVING_PLANTS", "false", "WAVING_LEAVES", "false"));
        return list;
    }

    private static Path optionsFile() {
        return IrisAccess.ourPackOptionsFile();
    }

    /** Puts the player's own option file back, then applies the step on top of it. */
    private static void apply(Step step) {
        try {
            restoreOptionsFile();
            if (step.shadersOff()) {
                IrisAccess.disableShaders();
            } else {
                IrisAccess.enableOurPack(step.options());
            }
        } catch (Exception e) {
            PockyShaders.LOGGER.error("Benchmark step {} could not be applied", step.id(), e);
        }
        measuringPhase = false;
        phaseStart = System.nanoTime();
    }

    private static void restoreOptionsFile() throws IOException {
        Path file = optionsFile();
        if (savedOptions != null) {
            Files.write(file, savedOptions);
        } else {
            Files.deleteIfExists(file);
        }
    }

    private static boolean paused() {
        Minecraft mc = Minecraft.getInstance();
        return mc.isPaused() || mc.screen != null || !mc.isWindowActive();
    }

    @SubscribeEvent
    static void onTick(ClientTickEvent.Post event) {
        if (!running()) {
            return;
        }
        Minecraft mc = Minecraft.getInstance();
        if (mc.level == null || mc.player == null) {
            restore();
            return;
        }
        long now = System.nanoTime();
        if (paused()) {
            // A menu or an unfocused window changes the frame rate: start this step over once the game is back.
            if (measuringPhase) {
                PerfMonitor.endStep();
            }
            measuringPhase = false;
            phaseStart = now;
            return;
        }
        if (!measuringPhase) {
            if (now - phaseStart >= WARMUP_NANOS) {
                PerfMonitor.startStep();
                measuringPhase = true;
                phaseStart = now;
            }
            return;
        }
        if (now - phaseStart < MEASURE_NANOS) {
            return;
        }
        rows.add(new Row(steps.get(current), PerfMonitor.endStep()));
        current++;
        if (current < steps.size()) {
            apply(steps.get(current));
            return;
        }
        List<Row> finished = rows;
        restore();
        report(finished);
    }

    /** The player's settings back as they were. */
    private static void restore() {
        if (measuringPhase) {
            PerfMonitor.endStep();
        }
        try {
            restoreOptionsFile();
            IrisAccess.enableOurPack(Map.of());
        } catch (Exception e) {
            PockyShaders.LOGGER.error("Benchmark could not restore the shader settings", e);
        }
        Minecraft mc = Minecraft.getInstance();
        mc.options.enableVsync().set(savedVsync);
        mc.options.framerateLimit().set(savedFramerateLimit);
        steps = null;
        rows = null;
        measuringPhase = false;
    }

    private static void report(List<Row> finished) {
        Minecraft mc = Minecraft.getInstance();
        FrameStats.Result base = finished.get(0).result();
        String time = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd_HH-mm-ss"));
        Path file = mc.gameDirectory.toPath().resolve("pocky_shaders").resolve("benchmarks").resolve("bench-" + time + ".md");
        StringBuilder out = new StringBuilder();
        out.append("# Pocky Shaders benchmark ").append(time).append("\n\n");
        out.append("- GPU: ").append(GL11.glGetString(GL11.GL_RENDERER)).append('\n');
        out.append("- Window: ").append(mc.getWindow().getWidth()).append('x').append(mc.getWindow().getHeight()).append('\n');
        out.append("- Render distance: ").append(mc.options.getEffectiveRenderDistance()).append(" chunks\n");
        out.append("- Mods: ").append(version("pocky_shaders")).append(", iris ").append(version("iris"))
                .append(", sodium ").append(version("sodium")).append(", distanthorizons ").append(version("distanthorizons"))
                .append('\n');
        if (mc.level != null && mc.player != null) {
            out.append("- Place: ").append(mc.level.dimension().location()).append(' ')
                    .append(mc.player.blockPosition().toShortString()).append(", biome ")
                    .append(mc.level.getBiome(mc.player.blockPosition()).unwrapKey().map(k -> k.location().toString()).orElse("?"))
                    .append(", time ").append(mc.level.getDayTime() % 24000)
                    .append(mc.level.isThundering() ? ", thunder" : mc.level.isRaining() ? ", rain" : ", clear").append('\n');
            out.append("- Camera: yaw ").append(Math.round(mc.player.getYRot())).append(", pitch ")
                    .append(Math.round(mc.player.getXRot())).append('\n');
        }
        out.append("- GPU timer: ").append(PerfMonitor.gpuTimerSupported() ? "yes" : "no (GPU column empty)").append("\n\n");
        out.append("Each step: 3 s warm-up, 6 s measured. \"Saves\" = how much faster than the current settings the frame is.\n\n");
        out.append("| Step | FPS | Frame ms | 1% low ms | GPU ms | Saves frame ms | Saves GPU ms |\n");
        out.append("|---|---:|---:|---:|---:|---:|---:|\n");
        for (Row row : finished) {
            FrameStats.Result r = row.result();
            out.append("| ").append(row.step().label())
                    .append(" | ").append(fmt(r.fps(), 0))
                    .append(" | ").append(fmt(r.frameMs(), 2))
                    .append(" | ").append(fmt(r.lowMs(), 2))
                    .append(" | ").append(fmt(r.gpuMs(), 2))
                    .append(" | ").append(row == finished.get(0) ? "-" : fmt(base.frameMs() - r.frameMs(), 2))
                    .append(" | ").append(row == finished.get(0) ? "-" : fmt(base.gpuMs() - r.gpuMs(), 2))
                    .append(" |\n");
        }
        try {
            Files.createDirectories(file.getParent());
            Files.writeString(file, out.toString(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            PockyShaders.LOGGER.error("Could not write the benchmark report", e);
        }
        PockyShaders.LOGGER.info("Benchmark report written to {}\n{}", file, out);

        // Chat: the result and the three features that cost the most.
        List<Row> features = new ArrayList<>(finished.stream()
                .filter(r -> r.step().id().startsWith("no_") || r.step().id().equals("shadow_1024")
                        || r.step().id().equals("flat_clouds") || r.step().id().equals("sky_reflections"))
                .toList());
        features.sort(Comparator.comparingDouble(r -> r.result().frameMs()));
        StringBuilder top = new StringBuilder();
        for (int i = 0; i < Math.min(3, features.size()); i++) {
            Row r = features.get(i);
            if (i > 0) {
                top.append(", ");
            }
            top.append(Component.translatable("pocky_shaders.bench.step." + r.step().id()).getString())
                    .append(" ").append(fmt(base.frameMs() - r.result().frameMs(), 1)).append(" ms");
        }
        if (mc.player != null) {
            mc.player.sendSystemMessage(Component.translatable("pocky_shaders.bench.done", fmt(base.fps(), 0),
                    fmt(base.gpuMs(), 1), mc.gameDirectory.toPath().relativize(file).toString()).withStyle(ChatFormatting.GREEN));
            mc.player.sendSystemMessage(Component.translatable("pocky_shaders.bench.top", top.toString()));
        }
    }

    private static String version(String modId) {
        return ModList.get().getModContainerById(modId).map(c -> c.getModInfo().getVersion().toString()).orElse("-");
    }

    private static String fmt(double value, int decimals) {
        return Double.isNaN(value) ? "-" : String.format(Locale.ROOT, "%." + decimals + "f", value);
    }
}

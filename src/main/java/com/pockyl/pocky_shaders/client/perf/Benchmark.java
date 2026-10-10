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
 * {@code /shaders bench}: measures what each part of the pack costs. It first waits until the frame time stops
 * drifting (chunks and Distant Horizons LODs still loading make early frames slower), then step by step switches one
 * feature off (or picks a preset, or turns shaders off), waits for the shaders to compile and the frame rate to
 * settle, and measures. The player's own settings are measured again after every two steps, and each step is compared
 * with the baselines around it, so slow drift does not show up as savings; the difference between those two
 * baselines is reported as the noise. Finally the player's settings are restored and a report is written to
 * {@code pocky_shaders/benchmarks/}. VSync and the frame rate limit are lifted while it runs, so the numbers show
 * what the GPU can do.
 */
@EventBusSubscriber(modid = PockyShaders.MOD_ID, value = Dist.CLIENT)
public final class Benchmark {
    private static final long WARMUP_NANOS = 3_000_000_000L;
    private static final long MEASURE_NANOS = 6_000_000_000L;
    private static final long SETTLE_WINDOW_NANOS = 2_000_000_000L;
    private static final int SETTLE_MIN_WINDOWS = 4;
    private static final int SETTLE_MAX_WINDOWS = 45;
    /** Two consecutive settle windows closer than this (relative) count as settled. */
    private static final double SETTLE_TOLERANCE = 0.03;
    /** Steps measured between two baselines. */
    private static final int STEPS_PER_BASELINE = 2;
    /** Smallest difference reported as real, whatever the baselines say (ms). */
    private static final double MIN_NOISE_MS = 0.1;
    private static final int UNLIMITED_FPS = 260;
    private static final String BASELINE = "current";

    /** One configuration to measure: options queued on top of the player's own, or shaders off. */
    private record Step(String id, String label, Map<String, String> options, boolean shadersOff) {
        static Step of(String id, String label, String... keyValues) {
            Map<String, String> options = new LinkedHashMap<>();
            for (int i = 0; i < keyValues.length; i += 2) {
                options.put(keyValues[i], keyValues[i + 1]);
            }
            return new Step(id, label, options, false);
        }

        boolean baseline() {
            return id.equals(BASELINE);
        }
    }

    private record Row(Step step, FrameStats.Result result) {
    }

    /** A step's result next to the baselines measured before and after it. */
    private record Compared(Row row, double savesFrameMs, double savesGpuMs, double noiseMs) {
        /** The saving the step's GPU (or, without a GPU timer, frame) time shows. */
        double saves() {
            return Double.isNaN(savesGpuMs) ? savesFrameMs : savesGpuMs;
        }

        boolean significant() {
            return Math.abs(saves()) > noiseMs;
        }
    }

    private static List<Step> steps;
    private static List<Row> rows;
    private static int current;
    private static boolean settling;
    private static int settleWindows;
    private static double lastSettleMs;
    private static boolean settled;
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
        settling = true;
        settleWindows = 0;
        lastSettleMs = Double.NaN;
        settled = false;
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
        if (settling) {
            return Optional.of(Component.translatable(paused() ? "pocky_shaders.bench.paused" : "pocky_shaders.bench.settling",
                    settleWindows * SETTLE_WINDOW_NANOS / 1_000_000_000L));
        }
        Step step = steps.get(current);
        Component phase = Component.translatable(paused() ? "pocky_shaders.bench.paused"
                : measuringPhase ? "pocky_shaders.bench.measuring" : "pocky_shaders.bench.warmup");
        return Optional.of(Component.translatable("pocky_shaders.bench.status", current + 1, steps.size(),
                Component.translatable("pocky_shaders.bench.step." + step.id()), phase));
    }

    private static List<Step> buildSteps() throws Exception {
        List<Step> measured = new ArrayList<>();
        measured.add(new Step("off", "Shaders off (no shader pack)", Map.of(), true));
        Map<Preset, Map<String, String>> profiles = BundledPack.profiles();
        for (Preset preset : Preset.values()) {
            Map<String, String> options = profiles.get(preset);
            if (options != null) {
                measured.add(new Step("preset_" + preset.id(), "Preset " + preset.id(), options, false));
            }
        }
        measured.add(Step.of("no_shadows", "No shadows", "SHADOWS", "false"));
        measured.add(Step.of("shadow_1024", "Shadow map 1024", "shadowMapResolution", "1024"));
        measured.add(Step.of("no_colored_shadows", "No coloured shadows", "COLORED_SHADOWS", "false"));
        measured.add(Step.of("no_ssao", "No ambient occlusion", "SSAO", "false"));
        measured.add(Step.of("no_clouds", "No clouds", "CLOUDS", "0"));
        measured.add(Step.of("flat_clouds", "Flat clouds", "CLOUDS", "1"));
        measured.add(Step.of("sky_reflections", "Sky-only water reflections (no SSR)", "WATER_REFLECTIONS", "1"));
        measured.add(Step.of("no_light_shafts", "No light shafts", "LIGHT_SHAFTS", "false"));
        measured.add(Step.of("no_bloom", "No bloom", "BLOOM", "false"));
        measured.add(Step.of("no_fxaa", "No FXAA", "FXAA", "false"));
        measured.add(Step.of("no_water_extras", "No caustics and foam", "WATER_CAUSTICS", "false", "WATER_FOAM", "false"));
        measured.add(Step.of("no_fog_extras", "No low haze, far haze, mist", "LOW_HAZE", "0.0", "FAR_HAZE", "0.0",
                "VALLEY_MIST", "false"));
        measured.add(Step.of("no_waving", "No waving plants and leaves", "WAVING_PLANTS", "false", "WAVING_LEAVES", "false"));

        // Baseline, two steps, baseline, two steps, ..., baseline.
        Step baseline = Step.of(BASELINE, "Current settings (baseline)");
        List<Step> list = new ArrayList<>();
        for (int i = 0; i < measured.size(); i++) {
            if (i % STEPS_PER_BASELINE == 0) {
                list.add(baseline);
            }
            list.add(measured.get(i));
        }
        list.add(baseline);
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
        if (settling) {
            settle(now);
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
        boolean wasSettled = settled;
        restore();
        report(finished, wasSettled);
    }

    /**
     * Before the first step: measures the player's settings in short windows until two in a row agree, i.e. the world
     * has finished loading around the player. The first step's own warm-up starts after that.
     */
    private static void settle(long now) {
        if (!measuringPhase) {
            if (now - phaseStart >= WARMUP_NANOS) {
                PerfMonitor.startStep();
                measuringPhase = true;
                phaseStart = now;
            }
            return;
        }
        if (now - phaseStart < SETTLE_WINDOW_NANOS) {
            return;
        }
        FrameStats.Result window = PerfMonitor.endStep();
        double ms = Double.isNaN(window.gpuMs()) ? window.frameMs() : window.gpuMs();
        settleWindows++;
        boolean stable = !Double.isNaN(lastSettleMs) && Math.abs(ms - lastSettleMs) <= lastSettleMs * SETTLE_TOLERANCE;
        lastSettleMs = ms;
        if ((stable && settleWindows >= SETTLE_MIN_WINDOWS) || settleWindows >= SETTLE_MAX_WINDOWS) {
            settled = stable;
            settling = false;
            measuringPhase = false;
            phaseStart = now;
            return;
        }
        PerfMonitor.startStep();
        phaseStart = now;
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
        settling = false;
        measuringPhase = false;
    }

    /** Every non-baseline row against the mean of the baselines measured right before and after it. */
    private static List<Compared> compare(List<Row> finished) {
        List<Compared> out = new ArrayList<>();
        for (int i = 0; i < finished.size(); i++) {
            Row row = finished.get(i);
            if (row.step().baseline()) {
                continue;
            }
            FrameStats.Result before = nearestBaseline(finished, i, -1);
            FrameStats.Result after = nearestBaseline(finished, i, 1);
            if (before == null) {
                before = after;
            }
            if (after == null) {
                after = before;
            }
            double baseFrame = (before.frameMs() + after.frameMs()) / 2;
            double baseGpu = (before.gpuMs() + after.gpuMs()) / 2;
            boolean gpu = !Double.isNaN(baseGpu) && !Double.isNaN(row.result().gpuMs());
            double drift = gpu ? Math.abs(before.gpuMs() - after.gpuMs()) : Math.abs(before.frameMs() - after.frameMs());
            out.add(new Compared(row, baseFrame - row.result().frameMs(),
                    gpu ? baseGpu - row.result().gpuMs() : Double.NaN, Math.max(MIN_NOISE_MS, drift)));
        }
        return out;
    }

    private static FrameStats.Result nearestBaseline(List<Row> finished, int from, int direction) {
        for (int i = from + direction; i >= 0 && i < finished.size(); i += direction) {
            if (finished.get(i).step().baseline()) {
                return finished.get(i).result();
            }
        }
        return null;
    }

    private static void report(List<Row> finished, boolean wasSettled) {
        Minecraft mc = Minecraft.getInstance();
        List<FrameStats.Result> baselines = finished.stream().filter(r -> r.step().baseline()).map(Row::result).toList();
        double baseFrame = baselines.stream().mapToDouble(FrameStats.Result::frameMs).average().orElse(Double.NaN);
        double baseGpu = baselines.stream().mapToDouble(FrameStats.Result::gpuMs).average().orElse(Double.NaN);
        double baseLow = baselines.stream().mapToDouble(FrameStats.Result::lowMs).average().orElse(Double.NaN);
        double minGpu = baselines.stream().mapToDouble(FrameStats.Result::gpuMs).min().orElse(Double.NaN);
        double maxGpu = baselines.stream().mapToDouble(FrameStats.Result::gpuMs).max().orElse(Double.NaN);
        List<Compared> compared = compare(finished);

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
        out.append("- GPU timer: ").append(PerfMonitor.gpuTimerSupported() ? "yes" : "no (GPU column empty)").append('\n');
        out.append("- Start: ").append(wasSettled ? "frame time settled after " : "frame time still drifting after ")
                .append(settleWindows * SETTLE_WINDOW_NANOS / 1_000_000_000L + WARMUP_NANOS / 1_000_000_000L).append(" s\n");
        out.append("- Your settings (").append(baselines.size()).append(" baseline runs): ").append(fmt(1000.0 / baseFrame, 0))
                .append(" FPS, frame ").append(fmt(baseFrame, 2)).append(" ms, 1% low ").append(fmt(baseLow, 2))
                .append(" ms, GPU ").append(fmt(baseGpu, 2)).append(" ms (baseline runs ").append(fmt(minGpu, 2))
                .append("..").append(fmt(maxGpu, 2)).append(" ms)\n\n");
        if (maxGpu - minGpu > 0.5) {
            out.append("**The baseline drifted by ").append(fmt(maxGpu - minGpu, 2))
                    .append(" ms during the run: something else was loading the game. Treat small differences with care.**\n\n");
        }
        out.append("Each step: 3 s warm-up, 6 s measured. \"Saves\" = how much faster the frame is than your settings, ")
                .append("measured right before and after the step (positive = the step is cheaper). \"Noise\" = how much ")
                .append("those two baseline runs differ (at least ").append(fmt(MIN_NOISE_MS, 1))
                .append(" ms); a saving within the noise is marked ~.\n\n");
        out.append("| Step | FPS | Frame ms | 1% low ms | GPU ms | Saves frame ms | Saves GPU ms | Noise ms |\n");
        out.append("|---|---:|---:|---:|---:|---:|---:|---:|\n");
        for (Row row : finished) {
            FrameStats.Result r = row.result();
            out.append("| ").append(row.step().label())
                    .append(" | ").append(fmt(r.fps(), 0))
                    .append(" | ").append(fmt(r.frameMs(), 2))
                    .append(" | ").append(fmt(r.lowMs(), 2))
                    .append(" | ").append(fmt(r.gpuMs(), 2));
            Optional<Compared> c = compared.stream().filter(x -> x.row() == row).findFirst();
            if (c.isPresent()) {
                String mark = c.get().significant() ? "" : " ~";
                out.append(" | ").append(fmt(c.get().savesFrameMs(), 2))
                        .append(" | ").append(fmt(c.get().savesGpuMs(), 2)).append(mark)
                        .append(" | ").append(fmt(c.get().noiseMs(), 2));
            } else {
                out.append(" | - | - | -");
            }
            out.append(" |\n");
        }
        try {
            Files.createDirectories(file.getParent());
            Files.writeString(file, out.toString(), StandardCharsets.UTF_8);
        } catch (IOException e) {
            PockyShaders.LOGGER.error("Could not write the benchmark report", e);
        }
        PockyShaders.LOGGER.info("Benchmark report written to {}\n{}", file, out);

        // Chat: the result and the (up to) three features that cost measurably the most.
        List<Compared> features = new ArrayList<>(compared.stream()
                .filter(c -> !c.row().step().shadersOff() && !c.row().step().id().startsWith("preset_"))
                .filter(c -> c.significant() && c.saves() > 0)
                .toList());
        features.sort(Comparator.comparingDouble(Compared::saves).reversed());
        StringBuilder top = new StringBuilder();
        for (int i = 0; i < Math.min(3, features.size()); i++) {
            Compared c = features.get(i);
            if (i > 0) {
                top.append(", ");
            }
            top.append(Component.translatable("pocky_shaders.bench.step." + c.row().step().id()).getString())
                    .append(" ").append(fmt(c.saves(), 1)).append(" ms");
        }
        if (mc.player != null) {
            mc.player.sendSystemMessage(Component.translatable("pocky_shaders.bench.done", fmt(1000.0 / baseFrame, 0),
                    fmt(baseGpu, 1), mc.gameDirectory.toPath().relativize(file).toString()).withStyle(ChatFormatting.GREEN));
            mc.player.sendSystemMessage(features.isEmpty() ? Component.translatable("pocky_shaders.bench.top_none")
                    : Component.translatable("pocky_shaders.bench.top", top.toString()));
            if (maxGpu - minGpu > 0.5) {
                mc.player.sendSystemMessage(Component.translatable("pocky_shaders.bench.drift", fmt(maxGpu - minGpu, 1))
                        .withStyle(ChatFormatting.YELLOW));
            }
        }
    }

    private static String version(String modId) {
        return ModList.get().getModContainerById(modId).map(c -> c.getModInfo().getVersion().toString()).orElse("-");
    }

    private static String fmt(double value, int decimals) {
        return Double.isNaN(value) ? "-" : String.format(Locale.ROOT, "%." + decimals + "f", value);
    }
}

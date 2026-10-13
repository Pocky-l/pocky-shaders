package com.pockyl.pocky_shaders.client.perf;

import net.minecraft.ChatFormatting;
import net.minecraft.client.Minecraft;
import net.minecraft.network.chat.Component;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.ClientTickEvent;

import com.pockyl.pocky_shaders.PockyShaders;
import com.pockyl.pocky_shaders.client.ShaderControl;
import com.pockyl.pocky_shaders.client.iris.IrisAccess;
import com.pockyl.pocky_shaders.pack.BundledPack;
import com.pockyl.pocky_shaders.pack.Preset;
import com.pockyl.pocky_shaders.pack.PresetChooser;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

/**
 * {@code /shaders preset auto}: tries the presets from Ultra down, a few seconds each, and keeps the best one this
 * computer runs smoothly ({@link PresetChooser}). VSync and the frame rate limit are lifted while it measures and put
 * back afterwards. Leaving the world or opening a menu restarts the current measurement; leaving the world stops it
 * and puts the player's settings back.
 */
@EventBusSubscriber(modid = PockyShaders.MOD_ID, value = Dist.CLIENT)
public final class AutoPreset {
    /** The first step waits longer: right after joining the world chunks are still loading. */
    private static final long FIRST_WARMUP_NANOS = 6_000_000_000L;
    private static final long WARMUP_NANOS = 3_000_000_000L;
    private static final long MEASURE_NANOS = 3_000_000_000L;
    private static final int UNLIMITED_FPS = 260;

    private static Preset trying;
    private static boolean first;
    private static boolean measuringPhase;
    private static long phaseStart;
    private static byte[] savedOptions;
    private static boolean savedVsync;
    private static int savedFramerateLimit;

    private AutoPreset() {
    }

    static boolean running() {
        return trying != null;
    }

    public static Component start() {
        if (running() || Benchmark.running()) {
            return Component.translatable("pocky_shaders.bench.running").withStyle(ChatFormatting.RED);
        }
        if (!ShaderControl.active()) {
            return Component.translatable("pocky_shaders.bench.need_pack").withStyle(ChatFormatting.RED);
        }
        try {
            Path optionsFile = IrisAccess.ourPackOptionsFile();
            savedOptions = Files.isRegularFile(optionsFile) ? Files.readAllBytes(optionsFile) : null;
        } catch (Exception e) {
            PockyShaders.LOGGER.error("Auto preset could not start", e);
            return Component.translatable("pocky_shaders.message.failed", String.valueOf(e.getMessage())).withStyle(ChatFormatting.RED);
        }
        Minecraft mc = Minecraft.getInstance();
        savedVsync = mc.options.enableVsync().get();
        savedFramerateLimit = mc.options.framerateLimit().get();
        mc.options.enableVsync().set(false);
        mc.options.framerateLimit().set(UNLIMITED_FPS);
        first = true;
        apply(PresetChooser.first());
        return Component.translatable("pocky_shaders.auto.started");
    }

    /** Overlay line while it runs. */
    static Optional<Component> statusLine() {
        if (!running()) {
            return Optional.empty();
        }
        return Optional.of(Component.translatable("pocky_shaders.auto.status", Component.translatable(trying.translationKey()),
                Component.translatable(paused() ? "pocky_shaders.bench.paused"
                        : measuringPhase ? "pocky_shaders.bench.measuring" : "pocky_shaders.bench.warmup")));
    }

    private static void apply(Preset preset) {
        trying = preset;
        try {
            Map<String, String> options = BundledPack.profiles().get(preset);
            IrisAccess.enableOurPack(options == null ? Map.of() : options);
        } catch (Exception e) {
            PockyShaders.LOGGER.error("Auto preset could not apply {}", preset.id(), e);
        }
        measuringPhase = false;
        phaseStart = System.nanoTime();
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
            abort();
            return;
        }
        long now = System.nanoTime();
        if (paused()) {
            if (measuringPhase) {
                PerfMonitor.endStep();
            }
            measuringPhase = false;
            phaseStart = now;
            return;
        }
        if (!measuringPhase) {
            if (now - phaseStart >= (first ? FIRST_WARMUP_NANOS : WARMUP_NANOS)) {
                PerfMonitor.startStep();
                measuringPhase = true;
                phaseStart = now;
            }
            return;
        }
        if (now - phaseStart < MEASURE_NANOS) {
            return;
        }
        FrameStats.Result result = PerfMonitor.endStep();
        first = false;
        boolean gpuTime = !Double.isNaN(result.gpuMs());
        double ms = gpuTime ? result.gpuMs() : result.frameMs();
        PockyShaders.LOGGER.info("Auto preset: {} measured {} ms ({})", trying.id(), String.format(Locale.ROOT, "%.2f", ms),
                gpuTime ? "GPU" : "frame");
        Preset lower = PresetChooser.below(trying);
        if (PresetChooser.fits(ms, gpuTime) || lower == null) {
            finish(trying, result);
        } else {
            apply(lower);
        }
    }

    private static void finish(Preset chosen, FrameStats.Result result) {
        trying = null;
        measuringPhase = false;
        restoreFrameRate();
        // The preset's options are already applied on top of the player's own: keep them.
        Minecraft mc = Minecraft.getInstance();
        if (mc.player != null) {
            mc.player.displayClientMessage(Component.translatable("pocky_shaders.auto.done",
                    Component.translatable(chosen.translationKey()), String.format(Locale.ROOT, "%.0f", result.fps())), false);
        }
    }

    public static Component stop() {
        if (!running()) {
            return Component.translatable("pocky_shaders.bench.not_running");
        }
        abort();
        return Component.translatable("pocky_shaders.bench.stopped");
    }

    private static void abort() {
        if (measuringPhase) {
            PerfMonitor.endStep();
        }
        trying = null;
        measuringPhase = false;
        try {
            Path file = IrisAccess.ourPackOptionsFile();
            if (savedOptions != null) {
                Files.write(file, savedOptions);
            } else {
                Files.deleteIfExists(file);
            }
            IrisAccess.enableOurPack(Map.of());
        } catch (Exception e) {
            PockyShaders.LOGGER.error("Auto preset could not restore the shader settings", e);
        }
        restoreFrameRate();
    }

    private static void restoreFrameRate() {
        Minecraft mc = Minecraft.getInstance();
        mc.options.enableVsync().set(savedVsync);
        mc.options.framerateLimit().set(savedFramerateLimit);
    }
}

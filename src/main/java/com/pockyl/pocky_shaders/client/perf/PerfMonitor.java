package com.pockyl.pocky_shaders.client.perf;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.network.chat.Component;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.RenderFrameEvent;
import net.neoforged.neoforge.client.event.RenderGuiEvent;

import com.pockyl.pocky_shaders.PockyShaders;
import com.pockyl.pocky_shaders.client.ShaderControl;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Measures every frame (CPU frame interval and GPU time) and draws the performance overlay ({@code /shaders perf}).
 * The benchmark reads its numbers from here too.
 */
@EventBusSubscriber(modid = PockyShaders.MOD_ID, value = Dist.CLIENT)
public final class PerfMonitor {
    private static final int OVERLAY_WINDOW = 240;

    private static final GpuTimer GPU = new GpuTimer();
    private static final FrameStats LIVE = new FrameStats();
    private static final FrameStats STEP = new FrameStats();
    private static long lastFrame;
    private static boolean overlay;
    private static boolean recordingStep;
    private static FrameStats.Result shown;
    private static Component header;
    private static long shownAt;

    private PerfMonitor() {
    }

    public static boolean toggleOverlay() {
        overlay = !overlay;
        return overlay;
    }

    static boolean measuring() {
        return overlay || Benchmark.running();
    }

    static void startStep() {
        STEP.clear();
        recordingStep = true;
    }

    static FrameStats.Result endStep() {
        recordingStep = false;
        return STEP.result(0);
    }

    static boolean gpuTimerSupported() {
        return GPU.supported();
    }

    @SubscribeEvent
    static void onFrameStart(RenderFrameEvent.Pre event) {
        if (!measuring()) {
            lastFrame = 0;
            return;
        }
        long now = System.nanoTime();
        if (lastFrame != 0) {
            long frame = now - lastFrame;
            LIVE.addFrame(frame);
            if (recordingStep) {
                STEP.addFrame(frame);
            }
        }
        lastFrame = now;
        GPU.begin();
    }

    @SubscribeEvent
    static void onFrameEnd(RenderFrameEvent.Post event) {
        if (!measuring()) {
            return;
        }
        GPU.end(nanos -> {
            LIVE.addGpu(nanos);
            if (recordingStep) {
                STEP.addGpu(nanos);
            }
        });
    }

    @SubscribeEvent
    static void onGui(RenderGuiEvent.Post event) {
        if (!measuring()) {
            return;
        }
        Minecraft mc = Minecraft.getInstance();
        if (mc.getDebugOverlay().showDebugScreen()) {
            return;
        }
        long now = System.nanoTime();
        // Refresh twice a second, so the numbers can be read (and the preset is not looked up every frame).
        if (shown == null || now - shownAt > 500_000_000L) {
            shown = LIVE.result(OVERLAY_WINDOW);
            header = Component.translatable("pocky_shaders.perf.header",
                    Component.translatable(ShaderControl.active() ? "pocky_shaders.status.on" : "pocky_shaders.status.off"),
                    Component.translatable(ShaderControl.currentPreset().map(p -> p.translationKey())
                            .orElse("pocky_shaders.preset.custom")));
            shownAt = now;
        }
        List<Component> lines = new ArrayList<>();
        lines.add(header);
        if (shown.frames() > 0) {
            lines.add(Component.translatable("pocky_shaders.perf.frame", fmt(shown.fps(), 0), fmt(shown.frameMs(), 2),
                    fmt(shown.lowMs(), 2)));
            if (!Double.isNaN(shown.gpuMs())) {
                lines.add(Component.translatable(shown.gpuBound() ? "pocky_shaders.perf.gpu_bound" : "pocky_shaders.perf.cpu_bound",
                        fmt(shown.gpuMs(), 2)));
            }
        }
        Benchmark.statusLine().ifPresent(lines::add);
        draw(event.getGuiGraphics(), mc.font, lines);
    }

    private static String fmt(double value, int decimals) {
        return String.format(Locale.ROOT, "%." + decimals + "f", value);
    }

    private static void draw(GuiGraphics graphics, Font font, List<Component> lines) {
        int width = 0;
        for (Component line : lines) {
            width = Math.max(width, font.width(line));
        }
        int x = 4;
        int y = 4;
        graphics.fill(x - 2, y - 2, x + width + 2, y + lines.size() * 10, 0x90000000);
        for (Component line : lines) {
            graphics.drawString(font, line, x, y, 0xFFFFFF, false);
            y += 10;
        }
    }
}

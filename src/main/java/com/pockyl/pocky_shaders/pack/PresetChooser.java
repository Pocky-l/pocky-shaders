package com.pockyl.pocky_shaders.pack;

/**
 * Picks the quality preset for {@code /shaders preset auto}: the presets are measured from the best down, and the first
 * one that leaves the frame enough room wins. The GPU time per frame is the better measure (it does not depend on the
 * frame rate limit or on what the CPU does); without a GPU timer the frame time is used with a looser target.
 */
public final class PresetChooser {
    /** Highest GPU time per frame (ms) a preset may take: about 90 FPS of GPU headroom, room for the rest of the frame. */
    public static final double GPU_TARGET_MS = 11.0;
    /** Highest frame time (ms) a preset may take when only the frame time is known: about 70 FPS. */
    public static final double FRAME_TARGET_MS = 14.0;

    private PresetChooser() {
    }

    /** The order in which presets are tried. */
    public static Preset first() {
        return Preset.ULTRA;
    }

    /** Whether a preset measured at {@code ms} per frame is good enough. */
    public static boolean fits(double ms, boolean gpuTime) {
        return !Double.isNaN(ms) && ms <= (gpuTime ? GPU_TARGET_MS : FRAME_TARGET_MS);
    }

    /** The next preset to try after {@code tried} did not fit, or {@code null} when it was the lowest. */
    public static Preset below(Preset tried) {
        return tried.ordinal() == 0 ? null : Preset.values()[tried.ordinal() - 1];
    }
}

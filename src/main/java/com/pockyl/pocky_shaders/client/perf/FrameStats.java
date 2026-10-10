package com.pockyl.pocky_shaders.client.perf;

import java.util.Arrays;

/** Frame times (CPU frame interval and GPU time) over a sliding window, or accumulated for a benchmark step. */
public final class FrameStats {
    private static final int CAPACITY = 4096;

    private final long[] frames = new long[CAPACITY];
    private final long[] gpu = new long[CAPACITY];
    private int frameCount;
    private int gpuCount;

    void addFrame(long nanos) {
        frames[frameCount % CAPACITY] = nanos;
        frameCount++;
    }

    void addGpu(long nanos) {
        gpu[gpuCount % CAPACITY] = nanos;
        gpuCount++;
    }

    void clear() {
        frameCount = 0;
        gpuCount = 0;
    }

    /** Snapshot of the last {@code window} frames (all recorded ones when window <= 0). */
    public Result result(int window) {
        long[] f = last(frames, frameCount, window);
        long[] g = last(gpu, gpuCount, window);
        return new Result(f.length, average(f), percentile(f, 0.99), g.length == 0 ? Double.NaN : average(g));
    }

    private static long[] last(long[] ring, int count, int window) {
        int n = Math.min(count, CAPACITY);
        if (window > 0) {
            n = Math.min(n, window);
        }
        long[] out = new long[n];
        for (int i = 0; i < n; i++) {
            out[i] = ring[(count - n + i) % CAPACITY];
        }
        return out;
    }

    private static double average(long[] values) {
        if (values.length == 0) {
            return Double.NaN;
        }
        double sum = 0;
        for (long v : values) {
            sum += v;
        }
        return sum / values.length / 1e6;
    }

    /** Frame time (ms) that the slowest share of frames reaches: 0.99 = the "1% low" frame time. */
    private static double percentile(long[] values, double p) {
        if (values.length == 0) {
            return Double.NaN;
        }
        long[] sorted = values.clone();
        Arrays.sort(sorted);
        return sorted[Math.min(sorted.length - 1, (int) Math.floor(p * sorted.length))] / 1e6;
    }

    /**
     * @param frames  number of frames measured
     * @param frameMs average time between frames (what FPS is made of)
     * @param lowMs   1% low frame time
     * @param gpuMs   average GPU time per frame, NaN when the GPU timer is not available
     */
    public record Result(int frames, double frameMs, double lowMs, double gpuMs) {
        public double fps() {
            return 1000.0 / frameMs;
        }

        /** The GPU is busy for nearly the whole frame: the shaders (not the game's CPU side) set the frame rate. */
        public boolean gpuBound() {
            return !Double.isNaN(gpuMs) && gpuMs > frameMs * 0.85;
        }
    }
}

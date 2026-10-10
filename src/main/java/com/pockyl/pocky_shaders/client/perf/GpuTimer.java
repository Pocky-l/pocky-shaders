package com.pockyl.pocky_shaders.client.perf;

import org.lwjgl.opengl.GL;
import org.lwjgl.opengl.GL15;
import org.lwjgl.opengl.GL33;

import java.util.function.LongConsumer;

/**
 * GPU time of a frame from two GL timestamp queries (start and end of the frame's rendering). Results are read a few
 * frames later, only once the GPU has them, so measuring never stalls the pipeline. Render thread only.
 */
final class GpuTimer {
    private static final int RING = 8;

    private final int[] startQueries = new int[RING];
    private final int[] endQueries = new int[RING];
    private final boolean[] pending = new boolean[RING];
    private int index;
    private boolean running;
    private Boolean supported;

    boolean supported() {
        if (supported == null) {
            supported = GL.getCapabilities().OpenGL33;
            if (supported) {
                GL15.glGenQueries(startQueries);
                GL15.glGenQueries(endQueries);
            }
        }
        return supported;
    }

    void begin() {
        running = false;
        if (!supported() || pending[index]) {
            // The GPU is more than RING frames behind on this slot: skip measuring this frame.
            return;
        }
        GL33.glQueryCounter(startQueries[index], GL33.GL_TIMESTAMP);
        running = true;
    }

    /** Ends the frame and hands every finished frame's GPU time (nanoseconds) to the consumer. */
    void end(LongConsumer finished) {
        if (running) {
            GL33.glQueryCounter(endQueries[index], GL33.GL_TIMESTAMP);
            pending[index] = true;
            index = (index + 1) % RING;
            running = false;
        }
        if (!supported()) {
            return;
        }
        for (int i = 0; i < RING; i++) {
            int slot = (index + i) % RING;
            if (pending[slot] && GL15.glGetQueryObjecti(endQueries[slot], GL15.GL_QUERY_RESULT_AVAILABLE) != 0) {
                long start = GL33.glGetQueryObjecti64(startQueries[slot], GL15.GL_QUERY_RESULT);
                long end = GL33.glGetQueryObjecti64(endQueries[slot], GL15.GL_QUERY_RESULT);
                pending[slot] = false;
                finished.accept(end - start);
            }
        }
    }
}

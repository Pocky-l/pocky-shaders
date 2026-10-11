package com.pockyl.pocky_shaders.client.weather;

import com.mojang.blaze3d.platform.GlStateManager;
import com.mojang.blaze3d.systems.RenderSystem;
import net.minecraft.client.renderer.texture.AbstractTexture;
import net.minecraft.server.packs.resources.ResourceManager;
import org.lwjgl.opengl.GL11;
import org.lwjgl.opengl.GL12;
import org.lwjgl.opengl.GL15;
import org.lwjgl.opengl.GL21;
import org.lwjgl.opengl.GL30;
import org.lwjgl.system.MemoryUtil;

import java.nio.FloatBuffer;

/**
 * A row of float texels the pack reads with {@code texelFetch}: Iris binds it to the sampler named in
 * {@code customTexture.modWeather} of shaders.properties, looking it up in the texture manager on every bind.
 * Render thread only.
 */
final class WeatherTexture extends AbstractTexture {
    private static final int[] UNPACK_PARAMETERS = {GL11.GL_UNPACK_ROW_LENGTH, GL11.GL_UNPACK_SKIP_ROWS,
            GL11.GL_UNPACK_SKIP_PIXELS, GL11.GL_UNPACK_ALIGNMENT};
    private static final int[] UNPACK_DEFAULTS = {0, 0, 0, 4};

    private final int width;
    private final FloatBuffer buffer;
    private boolean freed;

    WeatherTexture(int width) {
        RenderSystem.assertOnRenderThread();
        this.width = width;
        this.buffer = MemoryUtil.memAllocFloat(width * 4);
        bind();
        // No mipmaps: with the default minifying filter the texture would be incomplete and read as zero.
        GlStateManager._texParameter(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_MIN_FILTER, GL11.GL_NEAREST);
        GlStateManager._texParameter(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_MAG_FILTER, GL11.GL_NEAREST);
        GlStateManager._texParameter(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_WRAP_S, GL12.GL_CLAMP_TO_EDGE);
        GlStateManager._texParameter(GL11.GL_TEXTURE_2D, GL11.GL_TEXTURE_WRAP_T, GL12.GL_CLAMP_TO_EDGE);
        int[] saved = cleanUnpackState();
        GL11.glTexImage2D(GL11.GL_TEXTURE_2D, 0, GL30.GL_RGBA32F, width, 1, 0, GL11.GL_RGBA, GL11.GL_FLOAT, (FloatBuffer) null);
        restoreUnpackState(saved);
    }

    /** Uploads {@code width * 4} values (rgba per texel). */
    void upload(float[] values) {
        if (freed) {
            return;
        }
        buffer.clear();
        buffer.put(values, 0, width * 4).flip();
        bind();
        int[] saved = cleanUnpackState();
        GL11.glTexSubImage2D(GL11.GL_TEXTURE_2D, 0, 0, 0, width, 1, GL11.GL_RGBA, GL11.GL_FLOAT, buffer);
        restoreUnpackState(saved);
    }

    /**
     * Uploads read client memory with the current unpack state, which other renderers leave behind: a pixel buffer
     * still bound turns the pointer into an offset into it, a row length or skip of a large image made the driver read
     * far past this 8-texel buffer (a native crash in the driver). Clean state for the upload, the old one put back.
     */
    private static int[] cleanUnpackState() {
        int[] saved = new int[UNPACK_PARAMETERS.length + 1];
        for (int i = 0; i < UNPACK_PARAMETERS.length; i++) {
            saved[i] = GL11.glGetInteger(UNPACK_PARAMETERS[i]);
            GlStateManager._pixelStore(UNPACK_PARAMETERS[i], UNPACK_DEFAULTS[i]);
        }
        saved[UNPACK_PARAMETERS.length] = GL11.glGetInteger(GL21.GL_PIXEL_UNPACK_BUFFER_BINDING);
        if (saved[UNPACK_PARAMETERS.length] != 0) {
            GL15.glBindBuffer(GL21.GL_PIXEL_UNPACK_BUFFER, 0);
        }
        return saved;
    }

    private static void restoreUnpackState(int[] saved) {
        for (int i = 0; i < UNPACK_PARAMETERS.length; i++) {
            GlStateManager._pixelStore(UNPACK_PARAMETERS[i], saved[i]);
        }
        if (saved[UNPACK_PARAMETERS.length] != 0) {
            GL15.glBindBuffer(GL21.GL_PIXEL_UNPACK_BUFFER, saved[UNPACK_PARAMETERS.length]);
        }
    }

    @Override
    public void load(ResourceManager resourceManager) {
        // Filled from code, nothing to load.
    }

    @Override
    public void close() {
        super.close();
        if (!freed) {
            freed = true;
            MemoryUtil.memFree(buffer);
        }
    }
}

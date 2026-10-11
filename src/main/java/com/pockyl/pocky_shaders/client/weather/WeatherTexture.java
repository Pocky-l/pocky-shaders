package com.pockyl.pocky_shaders.client.weather;

import com.mojang.blaze3d.platform.GlStateManager;
import com.mojang.blaze3d.systems.RenderSystem;
import net.minecraft.client.renderer.texture.AbstractTexture;
import net.minecraft.server.packs.resources.ResourceManager;
import org.lwjgl.opengl.GL11;
import org.lwjgl.opengl.GL12;
import org.lwjgl.opengl.GL30;
import org.lwjgl.system.MemoryUtil;

import java.nio.FloatBuffer;

/**
 * A row of float texels the pack reads with {@code texelFetch}: Iris binds it to the sampler named in
 * {@code customTexture.modWeather} of shaders.properties, looking it up in the texture manager on every bind.
 * Render thread only.
 */
final class WeatherTexture extends AbstractTexture {
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
        GL11.glTexImage2D(GL11.GL_TEXTURE_2D, 0, GL30.GL_RGBA32F, width, 1, 0, GL11.GL_RGBA, GL11.GL_FLOAT, (FloatBuffer) null);
    }

    /** Uploads {@code width * 4} values (rgba per texel). */
    void upload(float[] values) {
        if (freed) {
            return;
        }
        buffer.clear();
        buffer.put(values, 0, width * 4).flip();
        bind();
        GL11.glTexSubImage2D(GL11.GL_TEXTURE_2D, 0, 0, 0, width, 1, GL11.GL_RGBA, GL11.GL_FLOAT, buffer);
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

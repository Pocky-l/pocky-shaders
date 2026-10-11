package com.pockyl.pocky_shaders.client.weather;

import net.minecraft.client.Minecraft;
import net.minecraft.resources.ResourceLocation;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.RenderFrameEvent;

import com.pockyl.pocky_shaders.PockyShaders;
import com.pockyl.pocky_shaders.client.ShaderControl;

/**
 * Hands the weather of the author's other mods to the pack once per frame, before the world is drawn: a small float
 * texture ({@code pocky_shaders:mod_weather}, the pack's {@code customTexture.modWeather}) filled by {@link ModWeather}.
 * Without the pack active nothing is read or uploaded.
 */
@EventBusSubscriber(modid = PockyShaders.MOD_ID, value = Dist.CLIENT)
public final class WeatherBridge {
    public static final ResourceLocation TEXTURE = ResourceLocation.fromNamespaceAndPath(PockyShaders.MOD_ID, "mod_weather");

    private static final float[] VALUES = new float[ModWeather.TEXELS * 4];
    private static ModWeather weather;
    private static WeatherTexture texture;
    private static long lastFrame;
    private static boolean broken;

    private WeatherBridge() {
    }

    @SubscribeEvent
    static void onFrameStart(RenderFrameEvent.Pre event) {
        Minecraft minecraft = Minecraft.getInstance();
        if (broken || minecraft.level == null || !ShaderControl.active()) {
            lastFrame = 0L;
            return;
        }
        try {
            if (texture == null) {
                texture = new WeatherTexture(ModWeather.TEXELS);
                minecraft.getTextureManager().register(TEXTURE, texture);
                weather = new ModWeather();
                PockyShaders.LOGGER.info("Pocky Shaders weather bridge: {}", weather.describe());
            }
            long now = System.nanoTime();
            // Game ticks since the last frame, for what drifts with the wind; nothing moves while the game is paused.
            float frameTicks = lastFrame == 0L || minecraft.isPaused() ? 0.0F : Math.min((now - lastFrame) / 50_000_000.0F, 5.0F);
            lastFrame = now;
            weather.write(VALUES, event.getPartialTick().getGameTimeDeltaPartialTick(false), frameTicks);
            texture.upload(VALUES);
        } catch (Throwable e) {
            // Never take the game down for an extra: the pack keeps its vanilla weather.
            broken = true;
            PockyShaders.LOGGER.error("Pocky Shaders weather bridge stopped", e);
        }
    }
}

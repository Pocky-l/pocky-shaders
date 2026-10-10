package com.pockyl.pocky_shaders.client;

import com.mojang.blaze3d.platform.InputConstants;
import net.minecraft.client.KeyMapping;
import net.minecraft.client.Minecraft;
import net.minecraft.network.chat.Component;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.ClientTickEvent;
import net.neoforged.neoforge.client.event.RegisterKeyMappingsEvent;
import org.lwjgl.glfw.GLFW;

import com.pockyl.pocky_shaders.PockyShaders;

/** F6 switches the pack on and off; a second, unbound key cycles the quality presets. */
@EventBusSubscriber(modid = PockyShaders.MOD_ID, value = Dist.CLIENT)
public final class KeyBindings {
    private static final String CATEGORY = "key.categories.pocky_shaders";

    public static final KeyMapping TOGGLE = new KeyMapping("key.pocky_shaders.toggle",
            InputConstants.Type.KEYSYM, GLFW.GLFW_KEY_F6, CATEGORY);
    public static final KeyMapping CYCLE_PRESET = new KeyMapping("key.pocky_shaders.cycle_preset",
            InputConstants.Type.KEYSYM, GLFW.GLFW_KEY_UNKNOWN, CATEGORY);

    private KeyBindings() {
    }

    @SubscribeEvent
    static void onRegister(RegisterKeyMappingsEvent event) {
        event.register(TOGGLE);
        event.register(CYCLE_PRESET);
    }

    @SubscribeEvent
    static void onClientTick(ClientTickEvent.Post event) {
        while (TOGGLE.consumeClick()) {
            show(ShaderControl.toggle());
        }
        while (CYCLE_PRESET.consumeClick()) {
            show(ShaderControl.cyclePreset());
        }
    }

    private static void show(Component message) {
        Minecraft mc = Minecraft.getInstance();
        if (mc.player != null) {
            mc.player.displayClientMessage(message, true);
        }
    }
}

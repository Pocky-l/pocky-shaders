package com.pockyl.pocky_shaders.client;

import com.mojang.brigadier.builder.LiteralArgumentBuilder;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.network.chat.Component;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.neoforge.client.event.RegisterClientCommandsEvent;

import com.pockyl.pocky_shaders.PockyShaders;
import com.pockyl.pocky_shaders.pack.Preset;

import java.util.function.Supplier;

/** Client command {@code /shaders on|off|toggle|status|preset <low|medium|high|ultra>}. */
@EventBusSubscriber(modid = PockyShaders.MOD_ID, value = Dist.CLIENT)
public final class ShadersCommand {
    private ShadersCommand() {
    }

    @SubscribeEvent
    static void onRegister(RegisterClientCommandsEvent event) {
        LiteralArgumentBuilder<CommandSourceStack> preset = Commands.literal("preset");
        for (Preset p : Preset.values()) {
            preset.then(Commands.literal(p.id()).executes(ctx -> reply(ctx.getSource(), () -> ShaderControl.setPreset(p))));
        }
        event.getDispatcher().register(Commands.literal("shaders")
                .executes(ctx -> reply(ctx.getSource(), ShaderControl::status))
                .then(Commands.literal("on").executes(ctx -> reply(ctx.getSource(), ShaderControl::enable)))
                .then(Commands.literal("off").executes(ctx -> reply(ctx.getSource(), ShaderControl::disable)))
                .then(Commands.literal("toggle").executes(ctx -> reply(ctx.getSource(), ShaderControl::toggle)))
                .then(Commands.literal("status").executes(ctx -> reply(ctx.getSource(), ShaderControl::status)))
                .then(preset));
    }

    private static int reply(CommandSourceStack source, Supplier<Component> action) {
        Component message = action.get();
        source.sendSystemMessage(message);
        return 1;
    }
}

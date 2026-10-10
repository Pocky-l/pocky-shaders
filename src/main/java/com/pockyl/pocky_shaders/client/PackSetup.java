package com.pockyl.pocky_shaders.client;

import net.minecraft.client.Minecraft;
import net.neoforged.api.distmarker.Dist;
import net.neoforged.bus.api.SubscribeEvent;
import net.neoforged.fml.common.EventBusSubscriber;
import net.neoforged.fml.event.lifecycle.FMLLoadCompleteEvent;
import net.neoforged.neoforge.client.event.ClientTickEvent;

import com.pockyl.pocky_shaders.Config;
import com.pockyl.pocky_shaders.PockyShaders;
import com.pockyl.pocky_shaders.client.iris.IrisAccess;
import com.pockyl.pocky_shaders.pack.BlockClassifier;
import com.pockyl.pocky_shaders.pack.BundledPack;
import com.pockyl.pocky_shaders.pack.PackInstaller;

import java.util.List;
import java.util.Map;

/**
 * Installs or updates the bundled pack once all mods are loaded (the block registry is needed for the modded block ids),
 * then, on the first client tick after loading, reloads Iris if the active pack changed or switches to the pack on its
 * first installation.
 */
@EventBusSubscriber(modid = PockyShaders.MOD_ID, value = Dist.CLIENT)
public final class PackSetup {
    private enum Pending { NONE, RELOAD, ENABLE }

    private static volatile Pending pending = Pending.NONE;

    private PackSetup() {
    }

    @SubscribeEvent
    static void onLoadComplete(FMLLoadCompleteEvent event) {
        if (!ShaderControl.irisPresent()) {
            PockyShaders.LOGGER.warn("Iris is not installed: the Pocky Shaders pack is not available");
            return;
        }
        if (!Config.INSTALL_PACK.get()) {
            return;
        }
        try {
            Map<Integer, List<String>> modded = Config.ADD_MODDED_BLOCKS.get() ? BlockClassifier.classifyModdedBlocks() : Map.of();
            String blockProperties = BundledPack.blockProperties(modded);
            PackInstaller.Result result = PackInstaller.install(BundledPack.root(),
                    IrisAccess.shaderpacksDirectory().resolve(PackInstaller.PACK_NAME),
                    Map.of(PackInstaller.BLOCK_PROPERTIES, blockProperties));
            int moddedCount = modded.values().stream().mapToInt(List::size).sum();
            PockyShaders.LOGGER.info("Shader pack ready ({} modded block entries, {})", moddedCount,
                    result.changed() ? "updated" : "up to date");

            boolean anotherPackOn = IrisAccess.shadersEnabled() && IrisAccess.selectedPack().isPresent()
                    && !IrisAccess.ourPackSelected();
            if (result.firstInstall() && Config.ENABLE_ON_FIRST_INSTALL.get() && !anotherPackOn) {
                pending = Pending.ENABLE;
            } else if (result.changed() && ShaderControl.active()) {
                pending = Pending.RELOAD;
            }
        } catch (Throwable e) {
            PockyShaders.LOGGER.error("Could not install the Pocky Shaders pack", e);
        }
    }

    @SubscribeEvent
    static void onClientTick(ClientTickEvent.Post event) {
        if (pending == Pending.NONE || Minecraft.getInstance().getOverlay() != null) {
            return;
        }
        Pending action = pending;
        pending = Pending.NONE;
        try {
            if (action == Pending.ENABLE) {
                ShaderControl.enable();
            } else {
                IrisAccess.reload();
            }
        } catch (Throwable e) {
            PockyShaders.LOGGER.error("Could not reload the shader pack", e);
        }
    }
}

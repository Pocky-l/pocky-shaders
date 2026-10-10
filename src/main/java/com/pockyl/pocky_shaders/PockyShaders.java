package com.pockyl.pocky_shaders;

import com.mojang.logging.LogUtils;
import net.minecraft.resources.ResourceLocation;
import net.neoforged.fml.ModContainer;
import net.neoforged.fml.common.Mod;
import net.neoforged.fml.config.ModConfig;
import org.slf4j.Logger;

/**
 * Pocky Shaders: a shader pack for Iris bundled in a mod. Everything happens on the client (see {@code client});
 * on a dedicated server the mod only loads.
 */
@Mod(PockyShaders.MOD_ID)
public final class PockyShaders {
    public static final String MOD_ID = "pocky_shaders";
    public static final Logger LOGGER = LogUtils.getLogger();

    public PockyShaders(ModContainer container) {
        container.registerConfig(ModConfig.Type.CLIENT, Config.SPEC);
    }

    public static ResourceLocation id(String path) {
        return ResourceLocation.fromNamespaceAndPath(MOD_ID, path);
    }
}

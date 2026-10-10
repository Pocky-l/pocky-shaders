package com.pockyl.pocky_shaders;

import net.neoforged.neoforge.common.ModConfigSpec;

public final class Config {
    private static final ModConfigSpec.Builder BUILDER = new ModConfigSpec.Builder();

    public static final ModConfigSpec.BooleanValue INSTALL_PACK = BUILDER
            .comment("Install and update the bundled shader pack in the shaderpacks folder on every start.")
            .translation("pocky_shaders.configuration.installPack")
            .define("installPack", true);

    public static final ModConfigSpec.BooleanValue ENABLE_ON_FIRST_INSTALL = BUILDER
            .comment("Switch Iris to Pocky Shaders the first time the pack is installed.")
            .translation("pocky_shaders.configuration.enableOnFirstInstall")
            .define("enableOnFirstInstall", true);

    public static final ModConfigSpec.BooleanValue ADD_MODDED_BLOCKS = BUILDER
            .comment("Let plants, leaves and light sources of other mods wave and glow like vanilla ones.")
            .translation("pocky_shaders.configuration.addModdedBlocks")
            .define("addModdedBlocks", true);

    public static final ModConfigSpec SPEC = BUILDER.build();

    private Config() {
    }
}

package com.pockyl.pocky_shaders.pack;

import net.neoforged.fml.ModList;

import com.pockyl.pocky_shaders.PockyShaders;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;

/** The shader pack shipped inside the mod jar ({@code shaderpack/}). */
public final class BundledPack {
    private BundledPack() {
    }

    public static Path root() throws IOException {
        Path root = ModList.get().getModFileById(PockyShaders.MOD_ID).getFile().findResource(PackInstaller.BUNDLED_ROOT);
        if (!Files.isDirectory(root)) {
            throw new IOException("Bundled shader pack not found at " + root);
        }
        return root;
    }

    public static Map<Preset, Map<String, String>> profiles() throws IOException {
        return PackProfiles.parse(PackInstaller.read(root(), PackInstaller.SHADERS_PROPERTIES));
    }

    /** block.properties with the given extra blocks merged in. */
    public static String blockProperties(Map<Integer, List<String>> additions) throws IOException {
        return BlockIdTable.merge(PackInstaller.read(root(), PackInstaller.BLOCK_PROPERTIES), additions);
    }
}

package com.pockyl.pocky_shaders.client.iris;

import net.irisshaders.iris.Iris;
import net.irisshaders.iris.config.IrisConfig;

import com.pockyl.pocky_shaders.pack.PackInstaller;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.Properties;

/**
 * Direct calls into Iris. Iris has a public API only for switching shaders on and off; choosing the pack and its
 * options goes through Iris' own classes, the same ones its shader pack screen uses. Only loaded when Iris is installed
 * (see {@code ShaderControl}), every caller handles failures.
 */
public final class IrisAccess {
    private IrisAccess() {
    }

    public static Path shaderpacksDirectory() {
        return Iris.getShaderpacksDirectory();
    }

    public static boolean shadersEnabled() {
        return Iris.getIrisConfig().areShadersEnabled();
    }

    public static Optional<String> selectedPack() {
        return Iris.getIrisConfig().getShaderPackName();
    }

    public static boolean ourPackSelected() {
        return selectedPack().map(PackInstaller.PACK_NAME::equals).orElse(false);
    }

    /** Selects the bundled pack, switches shaders on and applies the queued options (may be empty). */
    public static void enableOurPack(Map<String, String> options) throws IOException {
        IrisConfig config = Iris.getIrisConfig();
        config.setShaderPackName(PackInstaller.PACK_NAME);
        config.setShadersEnabled(true);
        config.save();
        Iris.getShaderPackOptionQueue().putAll(options);
        Iris.reload();
    }

    public static void disableShaders() throws IOException {
        IrisConfig config = Iris.getIrisConfig();
        config.setShadersEnabled(false);
        config.save();
        Iris.reload();
    }

    public static void reload() throws IOException {
        Iris.reload();
    }

    public static Optional<Exception> loadError() {
        return Iris.getStoredError();
    }

    /** The file where Iris keeps the option values the player changed for the bundled pack (read on every load). */
    public static Path ourPackOptionsFile() {
        return shaderpacksDirectory().resolve(PackInstaller.PACK_NAME + ".txt");
    }

    /** Option values the player changed for the bundled pack. */
    public static Map<String, String> ourPackOptions() throws IOException {
        Path file = ourPackOptionsFile();
        Map<String, String> result = new HashMap<>();
        if (Files.isRegularFile(file)) {
            Properties properties = new Properties();
            try (InputStream in = Files.newInputStream(file)) {
                properties.load(in);
            }
            properties.stringPropertyNames().forEach(name -> result.put(name, properties.getProperty(name)));
        }
        return result;
    }
}

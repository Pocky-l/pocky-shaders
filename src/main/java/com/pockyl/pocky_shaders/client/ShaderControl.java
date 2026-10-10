package com.pockyl.pocky_shaders.client;

import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.neoforged.fml.ModList;

import com.pockyl.pocky_shaders.PockyShaders;
import com.pockyl.pocky_shaders.client.iris.IrisAccess;
import com.pockyl.pocky_shaders.pack.BundledPack;
import com.pockyl.pocky_shaders.pack.PackProfiles;
import com.pockyl.pocky_shaders.pack.Preset;

import java.util.Map;
import java.util.Optional;

/**
 * What the key bindings and the /shaders command do. Every call returns the message to show the player; Iris being
 * absent, outdated or failing never crashes the game, it only produces an error message.
 */
public final class ShaderControl {
    private static Map<Preset, Map<String, String>> profiles;

    private ShaderControl() {
    }

    public static boolean irisPresent() {
        return ModList.get().isLoaded("iris");
    }

    public static boolean active() {
        if (!irisPresent()) {
            return false;
        }
        try {
            return IrisAccess.shadersEnabled() && IrisAccess.ourPackSelected();
        } catch (Throwable e) {
            return false;
        }
    }

    public static Component toggle() {
        return active() ? disable() : enable();
    }

    public static Component enable() {
        return run(() -> {
            IrisAccess.enableOurPack(Map.of());
            return loadedMessage(Component.translatable("pocky_shaders.message.enabled"));
        });
    }

    public static Component disable() {
        return run(() -> {
            IrisAccess.disableShaders();
            return Component.translatable("pocky_shaders.message.disabled");
        });
    }

    public static Component setPreset(Preset preset) {
        return run(() -> {
            Map<String, String> options = profiles().get(preset);
            if (options == null) {
                return error(Component.translatable("pocky_shaders.message.no_preset", preset.id()));
            }
            IrisAccess.enableOurPack(options);
            return loadedMessage(Component.translatable("pocky_shaders.message.preset",
                    Component.translatable(preset.translationKey())));
        });
    }

    public static Component cyclePreset() {
        Preset current = currentPreset().orElse(Preset.MEDIUM);
        return setPreset(active() ? current.next() : current);
    }

    public static Component status() {
        return run(() -> {
            String selected = IrisAccess.selectedPack().orElse("-");
            Component state = active()
                    ? Component.translatable("pocky_shaders.status.on").withStyle(ChatFormatting.GREEN)
                    : Component.translatable("pocky_shaders.status.off").withStyle(ChatFormatting.GRAY);
            Component preset = currentPreset()
                    .<Component>map(p -> Component.translatable(p.translationKey()))
                    .orElse(Component.translatable("pocky_shaders.preset.custom"));
            return Component.translatable("pocky_shaders.message.status", state, preset, selected);
        });
    }

    public static Optional<Preset> currentPreset() {
        if (!irisPresent()) {
            return Optional.empty();
        }
        try {
            return Optional.ofNullable(PackProfiles.match(profiles(), IrisAccess.ourPackOptions()));
        } catch (Throwable e) {
            return Optional.empty();
        }
    }

    private static Map<Preset, Map<String, String>> profiles() throws Exception {
        if (profiles == null) {
            profiles = BundledPack.profiles();
        }
        return profiles;
    }

    private static Component loadedMessage(Component success) {
        return IrisAccess.loadError()
                .<Component>map(e -> error(Component.translatable("pocky_shaders.message.load_failed", String.valueOf(e.getMessage()))))
                .orElse(success);
    }

    private static Component error(Component message) {
        return message.copy().withStyle(ChatFormatting.RED);
    }

    private interface Action {
        Component run() throws Exception;
    }

    private static Component run(Action action) {
        if (!irisPresent()) {
            return error(Component.translatable("pocky_shaders.message.no_iris"));
        }
        try {
            return action.run();
        } catch (Throwable e) {
            PockyShaders.LOGGER.error("Shader pack control failed", e);
            return error(Component.translatable("pocky_shaders.message.failed", String.valueOf(e.getMessage())));
        }
    }
}

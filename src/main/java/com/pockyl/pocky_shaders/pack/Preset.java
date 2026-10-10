package com.pockyl.pocky_shaders.pack;

import java.util.Locale;
import java.util.Optional;

/** Quality presets; each one is a {@code profile.<NAME>} line of the pack's shaders.properties. */
public enum Preset {
    LOW,
    MEDIUM,
    HIGH,
    ULTRA;

    public String id() {
        return name().toLowerCase(Locale.ROOT);
    }

    public String translationKey() {
        return "pocky_shaders.preset." + id();
    }

    public Preset next() {
        return values()[(ordinal() + 1) % values().length];
    }

    public static Optional<Preset> byId(String id) {
        for (Preset preset : values()) {
            if (preset.id().equalsIgnoreCase(id)) {
                return Optional.of(preset);
            }
        }
        return Optional.empty();
    }
}

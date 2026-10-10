package com.pockyl.pocky_shaders.pack;

import java.util.EnumMap;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Reads the quality profiles of shaders.properties ({@code profile.LOW = QUALITY=0 !SSAO ...}) into option values the
 * way Iris stores them: {@code NAME=value}, booleans as {@code true}/{@code false}.
 */
public final class PackProfiles {
    private PackProfiles() {
    }

    public static Map<Preset, Map<String, String>> parse(String shadersProperties) {
        Map<String, String> raw = new LinkedHashMap<>();
        String pending = "";
        for (String line : shadersProperties.split("\\R")) {
            // Properties-style continuation lines.
            String text = pending + line.strip();
            if (text.endsWith("\\")) {
                pending = text.substring(0, text.length() - 1) + " ";
                continue;
            }
            pending = "";
            if (text.startsWith("profile.")) {
                int eq = text.indexOf('=');
                if (eq > 0) {
                    raw.put(text.substring("profile.".length(), eq).strip(), text.substring(eq + 1).strip());
                }
            }
        }

        Map<Preset, Map<String, String>> result = new EnumMap<>(Preset.class);
        for (Preset preset : Preset.values()) {
            String spec = raw.get(preset.name());
            if (spec != null) {
                result.put(preset, options(spec, raw, 0));
            }
        }
        return result;
    }

    private static Map<String, String> options(String spec, Map<String, String> raw, int depth) {
        Map<String, String> options = new LinkedHashMap<>();
        for (String token : spec.split("\\s+")) {
            if (token.isEmpty()) {
                continue;
            }
            if (token.startsWith("profile.")) {
                // A profile may include another one.
                String other = raw.get(token.substring("profile.".length()));
                if (other != null && depth < 8) {
                    options.putAll(options(other, raw, depth + 1));
                }
            } else if (token.startsWith("!")) {
                options.put(token.substring(1), "false");
            } else {
                int eq = token.indexOf('=');
                int colon = token.indexOf(':');
                int sep = eq >= 0 ? eq : colon;
                if (sep > 0) {
                    options.put(token.substring(0, sep), token.substring(sep + 1));
                } else {
                    options.put(token, "true");
                }
            }
        }
        return options;
    }

    /** The preset whose options all match the given current values (missing ones count as the MEDIUM defaults). */
    public static Preset match(Map<Preset, Map<String, String>> profiles, Map<String, String> current) {
        Map<String, String> defaults = profiles.getOrDefault(Preset.MEDIUM, Map.of());
        for (Map.Entry<Preset, Map<String, String>> entry : profiles.entrySet()) {
            boolean all = true;
            for (Map.Entry<String, String> option : entry.getValue().entrySet()) {
                String value = current.getOrDefault(option.getKey(), defaults.get(option.getKey()));
                if (!option.getValue().equals(value)) {
                    all = false;
                    break;
                }
            }
            if (all) {
                return entry.getKey();
            }
        }
        return null;
    }
}

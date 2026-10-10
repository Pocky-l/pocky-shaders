package com.pockyl.pocky_shaders.pack;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * The pack's block.properties ({@code block.<id> = name name:state ...}) with extra block names merged in. Comments and the
 * order of the original lines are kept; new ids are appended at the end.
 */
public final class BlockIdTable {
    private BlockIdTable() {
    }

    public static String merge(String original, Map<Integer, List<String>> additions) {
        Map<Integer, Set<String>> remaining = new LinkedHashMap<>();
        additions.forEach((id, names) -> remaining.put(id, new LinkedHashSet<>(names)));

        List<String> out = new ArrayList<>();
        for (String line : original.split("\\R", -1)) {
            String trimmed = line.strip();
            int eq = trimmed.indexOf('=');
            if (trimmed.startsWith("block.") && eq > 0) {
                Integer id = parseId(trimmed.substring("block.".length(), eq).strip());
                Set<String> extra = id == null ? null : remaining.remove(id);
                if (extra != null) {
                    Set<String> present = Set.of(trimmed.substring(eq + 1).strip().split("\\s+"));
                    StringBuilder sb = new StringBuilder(line.stripTrailing());
                    for (String name : extra) {
                        if (!present.contains(name)) {
                            sb.append(' ').append(name);
                        }
                    }
                    out.add(sb.toString());
                    continue;
                }
            }
            out.add(line);
        }

        // Drop the empty element after a final newline, append new ids, then restore the newline.
        if (!out.isEmpty() && out.get(out.size() - 1).isEmpty()) {
            out.remove(out.size() - 1);
        }
        remaining.forEach((id, names) -> {
            if (!names.isEmpty()) {
                out.add("block." + id + " = " + String.join(" ", names));
            }
        });
        return String.join("\n", out) + "\n";
    }

    private static Integer parseId(String text) {
        try {
            return Integer.parseInt(text);
        } catch (NumberFormatException e) {
            return null;
        }
    }
}

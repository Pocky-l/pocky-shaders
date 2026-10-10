package com.pockyl.pocky_shaders.pack;

import com.pockyl.pocky_shaders.PockyShaders;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

/**
 * Copies the bundled shader pack into the shaderpacks folder. Generated files (block.properties with modded blocks)
 * replace their bundled versions. The copy is skipped while a fingerprint of the content is unchanged, so Iris only has
 * to reload after an update.
 */
public final class PackInstaller {
    public static final String PACK_NAME = "Pocky Shaders";
    public static final String BUNDLED_ROOT = "shaderpack";
    public static final String BLOCK_PROPERTIES = "shaders/block.properties";
    public static final String SHADERS_PROPERTIES = "shaders/shaders.properties";
    static final String FINGERPRINT_FILE = ".pocky_shaders";

    public record Result(boolean changed, boolean firstInstall) {
    }

    private PackInstaller() {
    }

    public static Result install(Path source, Path target, Map<String, String> generated) throws IOException {
        List<String> files = listFiles(source);
        String fingerprint = fingerprint(source, files, generated);
        Path marker = target.resolve(FINGERPRINT_FILE);
        boolean exists = Files.isDirectory(target);
        if (exists && Files.isRegularFile(marker) && Files.readString(marker).strip().equals(fingerprint)) {
            return new Result(false, false);
        }

        if (exists) {
            deleteRecursively(target);
        }
        for (String file : files) {
            Path to = resolve(target, file);
            Files.createDirectories(to.getParent());
            String override = generated.get(file);
            if (override != null) {
                Files.writeString(to, override, StandardCharsets.UTF_8);
            } else {
                Files.copy(resolve(source, file), to);
            }
        }
        Files.writeString(marker, fingerprint + "\n", StandardCharsets.UTF_8);
        PockyShaders.LOGGER.info("Installed shader pack \"{}\" ({} files)", target.getFileName(), files.size());
        return new Result(true, !exists);
    }

    public static String read(Path root, String relative) throws IOException {
        return Files.readString(resolve(root, relative), StandardCharsets.UTF_8);
    }

    /** Relative paths ("/"-separated) of all files under root, sorted. */
    static List<String> listFiles(Path root) throws IOException {
        List<String> files = new ArrayList<>();
        try (Stream<Path> walk = Files.walk(root)) {
            walk.filter(Files::isRegularFile).forEach(p -> {
                List<String> parts = new ArrayList<>();
                for (Path part : root.relativize(p)) {
                    parts.add(part.toString().replace("/", ""));
                }
                files.add(String.join("/", parts));
            });
        }
        files.sort(Comparator.naturalOrder());
        return files;
    }

    private static Path resolve(Path root, String relative) {
        Path p = root;
        for (String part : relative.split("/")) {
            p = p.resolve(part);
        }
        return p;
    }

    private static String fingerprint(Path source, List<String> files, Map<String, String> generated) throws IOException {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            for (String file : files) {
                digest.update(file.getBytes(StandardCharsets.UTF_8));
                String override = generated.get(file);
                digest.update(override != null ? override.getBytes(StandardCharsets.UTF_8) : Files.readAllBytes(resolve(source, file)));
            }
            return HexFormat.of().formatHex(digest.digest());
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }

    private static void deleteRecursively(Path dir) throws IOException {
        try (Stream<Path> walk = Files.walk(dir)) {
            walk.sorted(Comparator.reverseOrder()).forEach(p -> {
                try {
                    Files.delete(p);
                } catch (IOException e) {
                    throw new UncheckedIOException(e);
                }
            });
        } catch (UncheckedIOException e) {
            throw e.getCause();
        }
    }
}

package com.pockyl.pocky_shaders.gametest;

import net.minecraft.gametest.framework.GameTest;
import net.minecraft.gametest.framework.GameTestHelper;
import net.minecraft.world.level.block.Blocks;
import net.neoforged.neoforge.gametest.GameTestHolder;
import net.neoforged.neoforge.gametest.PrefixGameTestTemplate;

import com.pockyl.pocky_shaders.PockyShaders;
import com.pockyl.pocky_shaders.pack.BlockClassifier;
import com.pockyl.pocky_shaders.pack.BlockIdTable;
import com.pockyl.pocky_shaders.pack.BundledPack;
import com.pockyl.pocky_shaders.pack.PackInstaller;
import com.pockyl.pocky_shaders.pack.PackProfiles;
import com.pockyl.pocky_shaders.pack.Preset;
import com.pockyl.pocky_shaders.pack.PresetChooser;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

/**
 * In-game tests, run headless by {@code gradlew runGameTestServer}.
 * Tests use the 1x1x1 {@code empty} structure unless they need a prepared one.
 */
@GameTestHolder(PockyShaders.MOD_ID)
@PrefixGameTestTemplate(false)
public final class ModGameTests {
    private ModGameTests() {
    }

    @GameTest(template = "empty")
    public static void autoPresetStepsDownUntilItFits(GameTestHelper helper) {
        helper.assertTrue(PresetChooser.first() == Preset.ULTRA, "the best preset is tried first");
        helper.assertTrue(PresetChooser.below(Preset.ULTRA) == Preset.HIGH && PresetChooser.below(Preset.LOW) == null,
                "then one step lower each time, down to Low");
        helper.assertTrue(PresetChooser.fits(8.0, true) && !PresetChooser.fits(13.0, true), "GPU time against its target");
        helper.assertTrue(PresetChooser.fits(13.0, false) && !PresetChooser.fits(20.0, false), "frame time has a looser target");
        helper.assertFalse(PresetChooser.fits(Double.NaN, true), "no measurement never fits");
        helper.succeed();
    }

    @GameTest(template = "empty")
    public static void modLoads(GameTestHelper helper) {
        helper.succeed();
    }

    @GameTest(template = "empty")
    public static void bundledPackHasAllPresets(GameTestHelper helper) throws IOException {
        Map<Preset, Map<String, String>> profiles = BundledPack.profiles();
        for (Preset preset : Preset.values()) {
            helper.assertTrue(profiles.containsKey(preset), "missing profile " + preset);
        }
        helper.assertTrue("0".equals(profiles.get(Preset.LOW).get("QUALITY")), "LOW sets QUALITY=0");
        helper.assertTrue("false".equals(profiles.get(Preset.LOW).get("SSAO")), "LOW turns SSAO off");
        helper.assertTrue("4096".equals(profiles.get(Preset.ULTRA).get("shadowMapResolution")), "ULTRA shadow map");
        // Iris keeps only changed options; with none the defaults are the MEDIUM preset.
        helper.assertTrue(PackProfiles.match(profiles, Map.of()) == Preset.MEDIUM, "defaults match MEDIUM");
        helper.assertTrue(PackProfiles.match(profiles, profiles.get(Preset.HIGH)) == Preset.HIGH, "HIGH options match HIGH");
        helper.succeed();
    }

    @GameTest(template = "empty")
    public static void profileSyntax(GameTestHelper helper) {
        Map<Preset, Map<String, String>> p = PackProfiles.parse(
                "profile.BASE = A=1 !B\nprofile.LOW = profile.BASE C D:2 \\\n  E=x\n# profile.HIGH = A=9\n");
        Map<String, String> low = p.get(Preset.LOW);
        helper.assertTrue(low != null && "1".equals(low.get("A")) && "false".equals(low.get("B")), "included profile");
        helper.assertTrue("true".equals(low.get("C")) && "2".equals(low.get("D")) && "x".equals(low.get("E")), "own options");
        helper.assertFalse(p.containsKey(Preset.HIGH), "comment is not a profile");
        helper.succeed();
    }

    @GameTest(template = "empty")
    public static void blockTableMerges(GameTestHelper helper) {
        String original = "# plants\nblock.10001 = poppy fern\nblock.10004 = oak_leaves\n";
        String merged = BlockIdTable.merge(original, Map.of(
                10001, List.of("mymod:bush", "fern"),
                10010, List.of("mymod:lamp")));
        helper.assertTrue(merged.equals("# plants\nblock.10001 = poppy fern mymod:bush\nblock.10004 = oak_leaves\n"
                + "block.10010 = mymod:lamp\n"), "merged table: " + merged);
        helper.succeed();
    }

    @GameTest(template = "empty")
    public static void classifierSortsBlocks(GameTestHelper helper) {
        Map<Integer, List<String>> out = new HashMap<>();
        BlockClassifier.classify(Blocks.OAK_LEAVES, "a:leaves", out);
        BlockClassifier.classify(Blocks.POPPY, "a:flower", out);
        BlockClassifier.classify(Blocks.WHEAT, "a:crop", out);
        BlockClassifier.classify(Blocks.TALL_GRASS, "a:tall", out);
        BlockClassifier.classify(Blocks.VINE, "a:vine", out);
        BlockClassifier.classify(Blocks.LILY_PAD, "a:lily", out);
        BlockClassifier.classify(Blocks.GLOWSTONE, "a:lamp", out);
        BlockClassifier.classify(Blocks.STONE, "a:stone", out);
        BlockClassifier.classify(Blocks.FURNACE, "a:furnace", out);
        helper.assertTrue(out.get(BlockClassifier.LEAVES).equals(List.of("a:leaves")), "leaves");
        helper.assertTrue(out.get(BlockClassifier.PLANT).equals(List.of("a:flower", "a:crop")), "plants");
        helper.assertTrue(out.get(BlockClassifier.PLANT_LOWER).equals(List.of("a:tall:half=lower")), "tall lower");
        helper.assertTrue(out.get(BlockClassifier.PLANT_UPPER).equals(List.of("a:tall:half=upper")), "tall upper");
        helper.assertTrue(out.get(BlockClassifier.VINE).equals(List.of("a:vine")), "vine");
        helper.assertTrue(out.get(BlockClassifier.LILY).equals(List.of("a:lily")), "lily");
        helper.assertTrue(out.get(BlockClassifier.EMISSIVE).equals(List.of("a:lamp")), "only the lamp glows");
        helper.succeed();
    }

    @GameTest(template = "empty")
    public static void installerCopiesAndSkipsUnchanged(GameTestHelper helper) throws IOException {
        Path dir = Files.createTempDirectory("pocky_shaders_test");
        try {
            Path target = dir.resolve(PackInstaller.PACK_NAME);
            Map<String, String> generated = Map.of(PackInstaller.BLOCK_PROPERTIES, "block.1 = test\n");

            PackInstaller.Result first = PackInstaller.install(BundledPack.root(), target, generated);
            helper.assertTrue(first.changed() && first.firstInstall(), "first install");
            helper.assertTrue(Files.isRegularFile(target.resolve("shaders/world0/composite.fsh")), "programs copied");
            helper.assertTrue(Files.readString(target.resolve("shaders/block.properties")).equals("block.1 = test\n"),
                    "generated block.properties");

            PackInstaller.Result second = PackInstaller.install(BundledPack.root(), target, generated);
            helper.assertFalse(second.changed(), "unchanged content is not copied again");

            Files.writeString(target.resolve("stale.txt"), "x");
            PackInstaller.Result third = PackInstaller.install(BundledPack.root(), target,
                    Map.of(PackInstaller.BLOCK_PROPERTIES, "block.1 = other\n"));
            helper.assertTrue(third.changed() && !third.firstInstall(), "update");
            helper.assertFalse(Files.exists(target.resolve("stale.txt")), "update replaces the old pack");
        } finally {
            try (Stream<Path> walk = Files.walk(dir)) {
                walk.sorted(Comparator.reverseOrder()).forEach(p -> p.toFile().delete());
            }
        }
        helper.succeed();
    }
}

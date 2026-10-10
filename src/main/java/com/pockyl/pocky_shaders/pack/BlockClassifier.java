package com.pockyl.pocky_shaders.pack;

import net.minecraft.core.BlockPos;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.EmptyBlockGetter;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.BushBlock;
import net.minecraft.world.level.block.DoublePlantBlock;
import net.minecraft.world.level.block.HangingRootsBlock;
import net.minecraft.world.level.block.LeavesBlock;
import net.minecraft.world.level.block.VineBlock;
import net.minecraft.world.level.block.WaterlilyBlock;
import net.minecraft.world.level.block.state.BlockState;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;

/**
 * Sorts the blocks of other mods into the pack's block ids by what they are (leaves, plants, tall plants, vines, lamps),
 * so they wave and glow like their vanilla counterparts without a hand-written list per mod.
 */
public final class BlockClassifier {
    // Must match lib/common.glsl of the pack.
    public static final int PLANT = 10001;
    public static final int PLANT_LOWER = 10002;
    public static final int PLANT_UPPER = 10003;
    public static final int LEAVES = 10004;
    public static final int VINE = 10005;
    public static final int LILY = 10006;
    public static final int EMISSIVE = 10010;

    private BlockClassifier() {
    }

    /** Block ids for every non-vanilla block that fits a category. */
    public static Map<Integer, List<String>> classifyModdedBlocks() {
        Map<Integer, List<String>> result = new TreeMap<>();
        for (Block block : BuiltInRegistries.BLOCK) {
            ResourceLocation key = BuiltInRegistries.BLOCK.getKey(block);
            if (ResourceLocation.DEFAULT_NAMESPACE.equals(key.getNamespace())) {
                continue;
            }
            classify(block, key.toString(), result);
        }
        return result;
    }

    /** Adds the block.properties entries of one block to the map; does nothing for blocks without a category. */
    public static void classify(Block block, String name, Map<Integer, List<String>> out) {
        if (block instanceof LeavesBlock) {
            add(out, LEAVES, name);
        } else if (block instanceof DoublePlantBlock) {
            add(out, PLANT_LOWER, name + ":half=lower");
            add(out, PLANT_UPPER, name + ":half=upper");
        } else if (block instanceof WaterlilyBlock) {
            add(out, LILY, name);
        } else if (block instanceof VineBlock || block instanceof HangingRootsBlock) {
            add(out, VINE, name);
        } else if (block instanceof BushBlock) {
            add(out, PLANT, name);
        } else if (isLamp(block.defaultBlockState())) {
            add(out, EMISSIVE, name);
        }
    }

    // A bright full cube that always shines (a lamp, not a furnace that only glows while burning).
    private static boolean isLamp(BlockState state) {
        try {
            return state.getLightEmission() >= 10 && state.isCollisionShapeFullBlock(EmptyBlockGetter.INSTANCE, BlockPos.ZERO);
        } catch (RuntimeException e) {
            // Some modded blocks need a real level for their shape.
            return false;
        }
    }

    private static void add(Map<Integer, List<String>> out, int id, String entry) {
        out.computeIfAbsent(id, k -> new ArrayList<>()).add(entry);
    }
}

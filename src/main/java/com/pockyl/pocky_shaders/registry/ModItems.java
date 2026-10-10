package com.pockyl.pocky_shaders.registry;

import net.neoforged.bus.api.IEventBus;
import net.neoforged.neoforge.registries.DeferredRegister;

import com.pockyl.pocky_shaders.PockyShaders;

public final class ModItems {
    public static final DeferredRegister.Items ITEMS = DeferredRegister.createItems(PockyShaders.MOD_ID);

    private ModItems() {
    }

    public static void register(IEventBus modBus) {
        ITEMS.register(modBus);
    }
}

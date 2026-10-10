package com.pockyl.pocky_shaders.client;

import net.neoforged.api.distmarker.Dist;
import net.neoforged.fml.ModContainer;
import net.neoforged.fml.common.Mod;
import net.neoforged.neoforge.client.gui.ConfigurationScreen;
import net.neoforged.neoforge.client.gui.IConfigScreenFactory;

import com.pockyl.pocky_shaders.PockyShaders;

@Mod(value = PockyShaders.MOD_ID, dist = Dist.CLIENT)
public final class PockyShadersClient {
    public PockyShadersClient(ModContainer container) {
        container.registerExtensionPoint(IConfigScreenFactory.class, ConfigurationScreen::new);
    }
}

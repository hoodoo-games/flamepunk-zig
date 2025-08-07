const std = @import("std");
const rl = @import("raylib");
const gui = @import("gui.zig");
const asc = @import("ascensions.zig");
const bld = @import("buildings.zig");
const aug = @import("augments.zig");
const state = @import("state.zig");
const map = @import("map.zig");

var alloc = std.heap.DebugAllocator(.{}){};

pub fn main() !void {
    const screenWidth = 1920;
    const screenHeight = 1080;

    rl.initWindow(screenWidth, screenHeight, "Flamepunk");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    state.init(alloc.allocator());
    defer state.deinit();

    gui.init(alloc.allocator());
    defer gui.deinit();

    const tileTexture = try rl.loadTexture("./assets/sprites/tile.png");
    const tileHighlightTexture = try rl.loadTexture("./assets/sprites/tile_highlight.png");
    bld.loadBuildingTextures();

    _ = state.updateResources(state.getAscension().startingResources);

    state.openAugmentSelectMenu();

    state.handleMessage(state.Message{ .roundStart = {} });

    while (!rl.windowShouldClose()) {
        state.update();

        rl.beginDrawing();
        defer rl.endDrawing();

        map.drawGrid(tileTexture, tileHighlightTexture);
        gui.draw();
        state.drawHUD(); //TODO move to gui

        rl.clearBackground(.black);
    }
}

const std = @import("std");
const rl = @import("raylib");

const TILE_SIZE: f32 = 32;
const MAP_SIZE: f32 = 7;

pub fn main() !void {
    const screenWidth = 1920;
    const screenHeight = 1080;

    rl.initWindow(screenWidth, screenHeight, "Flamepunk");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    const cubeTexture = try rl.loadTexture("./assets/sprites/cube.png");

    while (!rl.windowShouldClose()) {
        const mousePos = rl.getMousePosition();
        const gridCell = screenToGrid(mousePos.x, mousePos.y);
        std.log.debug("{d}, {d}", .{ gridCell.x, gridCell.y });

        rl.beginDrawing();
        defer rl.endDrawing();

        drawGrid(cubeTexture);

        rl.clearBackground(.black);
    }
}

fn drawGrid(tile_sprite: rl.Texture2D) void {
    for (0..MAP_SIZE) |y| {
        for (0..MAP_SIZE) |x| {
            const x_f: f32 = @floatFromInt(x);
            const y_f: f32 = @floatFromInt(y);

            const screen_pos = gridToScreen(x_f, y_f);

            const src: rl.Rectangle = .{ .x = 0, .y = 0, .width = 32, .height = 32 };
            const dest: rl.Rectangle = .{ .x = screen_pos.x, .y = screen_pos.y, .width = 32 * 4, .height = 32 * 4 };

            rl.drawTexturePro(tile_sprite, src, dest, .{ .x = 0, .y = 0 }, 0, .white);
        }
    }
}

fn gridToScreen(x: f32, y: f32) rl.Vector2 {
    const i: rl.Vector2 = .{ .x = 1 * TILE_SIZE / 2, .y = 0.5 * TILE_SIZE / 2 };
    const j: rl.Vector2 = .{ .x = -1 * TILE_SIZE / 2, .y = 0.5 * TILE_SIZE / 2 };

    const width: f32 = @floatFromInt(rl.getScreenWidth());
    const height: f32 = @floatFromInt(rl.getScreenHeight());

    const offset: rl.Vector2 = .{ .x = (width / 2) - (TILE_SIZE / 2 * 4), .y = height / 2 - (MAP_SIZE * TILE_SIZE) };
    return i.scale(x).add(j.scale(y)).scale(4).add(offset);
}

fn screenToGrid(x: f32, y: f32) rl.Vector2 {
    const i: rl.Vector2 = .{ .x = 1 * TILE_SIZE / 2, .y = 0.5 * TILE_SIZE / 2 };
    const j: rl.Vector2 = .{ .x = -1 * TILE_SIZE / 2, .y = 0.5 * TILE_SIZE / 2 };

    const det = 1 / (i.x * j.y - j.x * i.y);
    const i_inv: rl.Vector2 = (rl.Vector2{ .x = j.y, .y = -i.y }).scale(det);
    const j_inv: rl.Vector2 = (rl.Vector2{ .x = -j.x, .y = i.x }).scale(det);

    //TODO derive offset from screen dimensions?

    const result = i_inv.scale(x).add(j_inv.scale(y)).scale(0.25).add(.{ .x = -12.5, .y = 2.5 });

    return .{ .x = @floor(result.x), .y = @floor(result.y) };
}

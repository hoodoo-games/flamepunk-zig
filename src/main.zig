const std = @import("std");
const rl = @import("raylib");
const Vector2 = rl.Vector2;
const Matrix = rl.Matrix;

const MAP_SIZE: f32 = 7;
const SCALE: f32 = 2;

const TILE_SIZE: f32 = 64;
const HALF_TILE_SIZE: f32 = TILE_SIZE / 2;

var hoveredTile: ?Vector2 = null;

var minerals: f64 = 0;
var gas: f64 = 0;
var flame: f64 = 0;

pub fn main() !void {
    const screenWidth = 1920;
    const screenHeight = 1080;

    rl.initWindow(screenWidth, screenHeight, "Flamepunk");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // const tileTexture = try rl.loadTexture("./assets/sprites/cube.png");
    const tileTexture64 = try rl.loadTexture("./assets/sprites/tile_64.png");
    const tileHighlightTexture = try rl.loadTexture("./assets/sprites/tile_highlight.png");

    while (!rl.windowShouldClose()) {
        hoveredTile = screenToIso(rl.getMousePosition());
        // std.log.debug("{d}, {d}", .{ hoveredTile.x, hoveredTile.y });

        rl.beginDrawing();
        defer rl.endDrawing();

        drawGrid(tileTexture64, tileHighlightTexture);

        // screen center marker
        // rl.drawCircle(@divFloor(rl.getScreenWidth(), 2), @divFloor(rl.getScreenHeight(), 2), 4, .white);

        rl.clearBackground(.black);
    }
}

fn drawGrid(tileSprite: rl.Texture2D, highlightSprite: rl.Texture2D) void {
    for (0..MAP_SIZE) |y| {
        for (0..MAP_SIZE) |x| {
            const pos = Vector2{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
            const screen_pos = isoToScreen(pos);

            const src: rl.Rectangle = .{ .x = 0, .y = 0, .width = TILE_SIZE, .height = TILE_SIZE };

            const dest: rl.Rectangle = .{
                .x = screen_pos.x,
                .y = screen_pos.y,
                .width = TILE_SIZE * SCALE,
                .height = TILE_SIZE * SCALE,
            };

            rl.drawTexturePro(tileSprite, src, dest, .{ .x = 0, .y = 0 }, 0, .white);

            if (hoveredTile) |t| {
                if (t.x == @as(f32, @floatFromInt(x)) and t.y == @as(f32, @floatFromInt(y))) {
                    rl.drawTexturePro(highlightSprite, src, dest, .{ .x = 0, .y = 0 }, 0, .white);
                }
            }
        }
    }
}

const I = Vector2{ .x = 1, .y = 0.5 };
const J = Vector2{ .x = -1, .y = 0.5 };
const IJ_DET = 1 / (I.x * J.y - J.x * I.y);
const I_INV = Vector2{ .x = J.y, .y = -I.y };
const J_INV = Vector2{ .x = -J.x, .y = I.x };

fn screenToIso(screen: Vector2) Vector2 {
    var iso = screen.subtract(halfScreenSize());

    iso = iso.scale(IJ_DET);
    iso = I_INV.scale(iso.x).add(J_INV.scale(iso.y));
    iso = iso.scale(1 / SCALE / HALF_TILE_SIZE);

    iso.x = @floor(iso.x + MAP_SIZE / 2);
    iso.y = @floor(iso.y + MAP_SIZE / 2);

    return iso;
}

fn isoToScreen(iso: Vector2) Vector2 {
    var screen = I.scale(iso.x).add(J.scale(iso.y));

    // offset origin to screen center
    screen.x -= 1;
    screen.y -= MAP_SIZE / 2;

    screen = screen.scale(SCALE * HALF_TILE_SIZE).add(halfScreenSize());

    return screen;
}

fn screenSize() Vector2 {
    return .{ .x = @floatFromInt(rl.getScreenWidth()), .y = @floatFromInt(rl.getScreenHeight()) };
}

fn halfScreenSize() Vector2 {
    return screenSize().scale(0.5);
}

fn degrees(rad: f32) f32 {
    return rad * 180 / std.math.pi;
}

fn radians(deg: f32) f32 {
    return deg * std.math.pi / 180;
}

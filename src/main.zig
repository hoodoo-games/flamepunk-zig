const std = @import("std");
const rl = @import("raylib");
const Vector2 = rl.Vector2;
const Matrix = rl.Matrix;

const MAP_SIZE: f32 = 7;
const NUM_TILES: usize = @intFromFloat(MAP_SIZE * MAP_SIZE);
const PX_SCALE: f32 = 2;

const TILE_SIZE: f32 = 64;
const HALF_TILE_SIZE: f32 = TILE_SIZE / 2;

var hoveredTile: ?Vector2 = null;

var tiles: [NUM_TILES]Tile = .{Tile{}} ** NUM_TILES;

const Tile = struct {
    building: ?PlacedBuilding = null,
};

const Building = struct {
    name: []u8 = "Building",
    description: []u8 = "...",
};

const PlacedBuilding = struct {};

var resources = Resources{};

const Resources = struct {
    minerals: f64 = 0,
    gas: f64 = 0,
    flame: f64 = 0,
};

/// transactional resource update
pub fn updateResources(delta: Resources) bool {
    const minerals = resources.minerals + delta.minerals;
    const gas = resources.gas + delta.gas;
    const flame = resources.flame + delta.flame;

    // rollback if any of the new totals are negative
    if (minerals < 0 or gas < 0 or flame < 0) return false;

    // commit new resource totals
    resources.minerals = minerals;
    resources.gas = gas;
    resources.flame = flame;

    return true;
}

pub fn main() !void {
    const screenWidth = 1920;
    const screenHeight = 1080;

    rl.initWindow(screenWidth, screenHeight, "Flamepunk");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    const tileTexture = try rl.loadTexture("./assets/sprites/tile.png");
    const tileHighlightTexture = try rl.loadTexture("./assets/sprites/tile_highlight.png");
    const buildingTexture = try rl.loadTexture("./assets/sprites/building.png");

    while (!rl.windowShouldClose()) {
        updateAim();

        if (hoveredTile) |coord| {
            if (rl.isMouseButtonPressed(.left)) {
                tiles[tileCoordToIdx(coord)].building = .{};
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        drawGrid(tileTexture, tileHighlightTexture, buildingTexture);
        drawHUD();

        rl.clearBackground(.black);
    }
}

fn updateAim() void {
    const coord = screenToIso(rl.getMousePosition());
    hoveredTile = if (isTileInMap(coord)) coord else null;
}

fn isTileInMap(coord: Vector2) bool {
    return coord.x >= 0 and coord.x < MAP_SIZE and coord.y >= 0 and coord.y < MAP_SIZE;
}

fn tileCoordToIdx(coord: Vector2) usize {
    return @intFromFloat(coord.x + coord.y * MAP_SIZE);
}

fn drawGrid(tileSprite: rl.Texture2D, highlightSprite: rl.Texture2D, buildingSprite: rl.Texture2D) void {
    for (0..MAP_SIZE) |y| {
        for (0..MAP_SIZE) |x| {
            const pos = Vector2{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
            const screen_pos = isoToScreen(pos);

            const src: rl.Rectangle = .{ .x = 0, .y = 0, .width = TILE_SIZE, .height = TILE_SIZE };

            const dest: rl.Rectangle = .{
                .x = screen_pos.x,
                .y = screen_pos.y,
                .width = TILE_SIZE * PX_SCALE,
                .height = TILE_SIZE * PX_SCALE,
            };

            rl.drawTexturePro(tileSprite, src, dest, .{ .x = 0, .y = 0 }, 0, .white);

            if (hoveredTile) |t| {
                if (t.x == @as(f32, @floatFromInt(x)) and t.y == @as(f32, @floatFromInt(y))) {
                    rl.drawTexturePro(highlightSprite, src, dest, .{ .x = 0, .y = 0 }, 0, .white);
                }
            }

            const tileIdx = x + (y * @as(usize, @intFromFloat(MAP_SIZE)));
            const t = tiles[tileIdx];
            const s: rl.Rectangle = .{ .x = 0, .y = 0, .width = TILE_SIZE, .height = 40 };

            const d: rl.Rectangle = .{
                .x = screen_pos.x,
                .y = screen_pos.y,
                .width = TILE_SIZE * PX_SCALE,
                .height = 40 * PX_SCALE,
            };

            if (t.building != null) {
                rl.drawTexturePro(buildingSprite, s, d, .{ .x = 0, .y = 16 }, 0, .white);
            }
        }
    }
}

fn formatResourceString(qty: f64, buffer: []u8) [:0]u8 {
    return std.fmt.bufPrintZ(buffer, "{d}", .{qty}) catch unreachable;
}

const RESOURCE_BUF_LEN = 16;

fn drawHUD() void {
    var mineralsBuf: [RESOURCE_BUF_LEN]u8 = .{0} ** RESOURCE_BUF_LEN;
    const mineralsStr = formatResourceString(resources.minerals, &mineralsBuf);

    var gasBuf: [RESOURCE_BUF_LEN]u8 = .{0} ** RESOURCE_BUF_LEN;
    const gasStr = formatResourceString(resources.gas, &gasBuf);

    rl.drawText(mineralsStr, 10, 10, 10 * PX_SCALE, .blue);
    rl.drawText(gasStr, 10, 40, 10 * PX_SCALE, .green);
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
    iso = iso.scale(1 / PX_SCALE / HALF_TILE_SIZE);

    iso.x = @floor(iso.x + MAP_SIZE / 2);
    iso.y = @floor(iso.y + MAP_SIZE / 2);

    return iso;
}

fn isoToScreen(iso: Vector2) Vector2 {
    var screen = I.scale(iso.x).add(J.scale(iso.y));

    // offset origin to screen center
    screen.x -= 1;
    screen.y -= MAP_SIZE / 2;

    screen = screen.scale(PX_SCALE * HALF_TILE_SIZE).add(halfScreenSize());

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

fn changeMinerals() void {}
fn changeGas() void {}
fn changeFlame() void {}

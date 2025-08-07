const rl = @import("raylib");
const utils = @import("utils.zig");
const buildings = @import("buildings.zig");
const state = @import("state.zig");

const Vector2 = rl.Vector2;

const PlacedBuilding = buildings.PlacedBuilding;

pub const MAP_SIZE: f32 = 7; // tiles
pub const NUM_TILES: usize = @intFromFloat(MAP_SIZE * MAP_SIZE);
pub const TILE_SIZE: f32 = 64; // virtual pixels
pub const HALF_TILE_SIZE: f32 = TILE_SIZE / 2;

const I = Vector2{ .x = 1, .y = 0.5 };
const J = Vector2{ .x = -1, .y = 0.5 };
const IJ_DET = 1 / (I.x * J.y - J.x * I.y);
const I_INV = Vector2{ .x = J.y, .y = -I.y };
const J_INV = Vector2{ .x = -J.x, .y = I.x };

/// Transforms a position from screen to isometric space
pub fn screenToIso(screen: Vector2) Vector2 {
    var iso = screen.subtract(utils.halfScreenSize());

    iso = iso.scale(IJ_DET);
    iso = I_INV.scale(iso.x).add(J_INV.scale(iso.y));
    iso = iso.scale(1 / utils.PX_SCALE / HALF_TILE_SIZE);

    iso.x = @floor(iso.x + MAP_SIZE / 2);
    iso.y = @floor(iso.y + MAP_SIZE / 2);

    return iso;
}

/// Transforms a position from isometric to screen space
pub fn isoToScreen(iso: Vector2) Vector2 {
    var screen = I.scale(iso.x).add(J.scale(iso.y));

    // offset origin to screen center
    screen.x -= 1;
    screen.y -= MAP_SIZE / 2;

    screen = screen.scale(utils.PX_SCALE * HALF_TILE_SIZE).add(utils.halfScreenSize());

    return screen;
}

/// Checks if a tile coordinate is within the map bounds
pub fn isTileInBounds(coord: Vector2) bool {
    return coord.x >= 0 and coord.x < MAP_SIZE and coord.y >= 0 and coord.y < MAP_SIZE;
}

/// Flattens a 2d tile coordinate to an index
pub fn tileCoordToIdx(coord: Vector2) usize {
    return @intFromFloat(coord.x + coord.y * MAP_SIZE);
}

pub fn drawGrid(tileSprite: rl.Texture2D, highlightSprite: rl.Texture2D) void {
    for (0..MAP_SIZE) |y| {
        for (0..MAP_SIZE) |x| {
            const pos = Vector2{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
            const screen_pos = isoToScreen(pos);

            const src: rl.Rectangle = .{
                .x = 0,
                .y = 0,
                .width = TILE_SIZE,
                .height = TILE_SIZE,
            };

            const dest: rl.Rectangle = .{
                .x = screen_pos.x,
                .y = screen_pos.y,
                .width = TILE_SIZE * utils.PX_SCALE,
                .height = TILE_SIZE * utils.PX_SCALE,
            };

            rl.drawTexturePro(tileSprite, src, dest, .{ .x = 0, .y = 0 }, 0, .white);

            if (state.isRoundActive()) {
                if (state.getHoveredTile()) |t| {
                    if (t.x == @as(f32, @floatFromInt(x)) and t.y == @as(f32, @floatFromInt(y))) {
                        rl.drawTexturePro(
                            highlightSprite,
                            src,
                            dest,
                            .{ .x = 0, .y = 0 },
                            0,
                            .white,
                        );
                    }
                }
            }

            const tileIdx = x + (y * @as(usize, @intFromFloat(MAP_SIZE)));
            const t = state.tiles[tileIdx];
            const s: rl.Rectangle = .{ .x = 0, .y = 0, .width = TILE_SIZE, .height = 40 };

            const d: rl.Rectangle = .{
                .x = screen_pos.x,
                .y = screen_pos.y,
                .width = TILE_SIZE * utils.PX_SCALE,
                .height = 40 * utils.PX_SCALE,
            };

            if (t.building) |b| {
                rl.drawTexturePro(
                    buildings.buildingTextures[b.archetypeIdx],
                    s,
                    d,
                    .{ .x = 0, .y = 8 * utils.PX_SCALE },
                    0,
                    .white,
                );
            }
        }
    }
}

pub const Tile = struct {
    building: ?PlacedBuilding = null,
};

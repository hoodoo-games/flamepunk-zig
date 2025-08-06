const std = @import("std");
const rl = @import("raylib");
const gui = @import("gui.zig");
const asc = @import("ascensions.zig");
const bld = @import("buildings.zig");
const aug = @import("augments.zig");

const ArrayList = std.ArrayList;
const Vector2 = rl.Vector2;
const Matrix = rl.Matrix;

const Building = bld.Building;
const PlacedBuilding = bld.PlacedBuilding;
const buildings = bld.buildings;

const Ascension = asc.Ascension;
const ascensions = asc.ascensions;

const Augment = aug.Augment;
const augments = aug.augments;

const Allocator = std.mem.Allocator;
var alloc = std.heap.DebugAllocator(.{}){};

const MAP_SIZE: f32 = 7;
const NUM_TILES: usize = @intFromFloat(MAP_SIZE * MAP_SIZE);
pub const PX_SCALE: f32 = 3;

const TILE_SIZE: f32 = 64;
const HALF_TILE_SIZE: f32 = TILE_SIZE / 2;

var hoveredTile: ?Vector2 = null;
var tiles: [NUM_TILES]Tile = .{Tile{}} ** NUM_TILES;

pub var resources = Resources{};

var ascensionIndex: usize = 0;

pub var augmentSelectOpen: bool = false;
var roundActive: bool = false;
var roundIdx: usize = 0;
var elapsedRoundTime: f32 = 0;

pub var activeAugments: ArrayList(Augment) = undefined;
var activeBuildings: [9]Building = undefined;

var victory: ?bool = null;

pub var placementMode: PlacementMode = .none;

const PlacementMode = union(enum(u8)) {
    none,
    place: struct { archetypeIdx: usize },
    demolish,
};

pub fn remainingRoundTime() f32 {
    return ascension().roundDuration - elapsedRoundTime;
}

pub fn ascension() Ascension {
    return ascensions[ascensionIndex];
}

pub fn goldQuota() f64 {
    return ascension().goldQuota(roundIdx);
}

pub const Message = union(enum(usize)) {
    roundStart: void,
    roundEnd: void,
    buildingPlaced: struct { building: *PlacedBuilding },
    buildingDemolished: struct { building: *PlacedBuilding },
    buildingProduced: struct {
        building: *PlacedBuilding,
        yield: Resources,
    },
    buildingUnlocked: struct { archetypeIdx: usize },
    augmentSelected: struct {},

    fn apply(self: *const Message) void {
        switch (self.*) {
            .buildingProduced => |m| {
                _ = updateResources(m.yield);
            },
            else => {},
        }
    }
};

pub fn handleMessage(message: Message) void {
    var m = message;

    for (activeAugments.items) |*a| if (a.callbacks.before) |e| e(a, &m);
    for (activeAugments.items) |*a| if (a.callbacks.add) |e| e(a, &m);
    for (activeAugments.items) |*a| if (a.callbacks.multiply) |e| e(a, &m);
    for (activeAugments.items) |*a| if (a.callbacks.after) |e| e(a, &m);

    m.apply();
}

const Tile = struct {
    building: ?PlacedBuilding = null,
};

pub const Resources = struct {
    minerals: f64 = 0,
    gas: f64 = 0,
    gold: f64 = 0,

    pub fn add(self: Resources, other: Resources) Resources {
        return .{
            .minerals = self.minerals + other.minerals,
            .gas = self.gas + other.gas,
            .gold = self.gold + other.gold,
        };
    }

    pub fn negate(self: Resources) Resources {
        return .{
            .minerals = -self.minerals,
            .gas = -self.gas,
            .gold = -self.gold,
        };
    }

    pub fn scale(self: Resources, scalar: f32) Resources {
        return .{
            .minerals = self.minerals * scalar,
            .gas = self.gas * scalar,
            .gold = self.gold * scalar,
        };
    }
};

/// checks if this delta is a valid resource update
pub fn canAfford(delta: Resources) bool {
    const minerals = resources.minerals + delta.minerals;
    const gas = resources.gas + delta.gas;
    const gold = resources.gold + delta.gold;

    return minerals >= 0 and gas >= 0 and gold >= 0;
}

/// transactional resource update
pub fn updateResources(delta: Resources) bool {
    const minerals = resources.minerals + delta.minerals;
    const gas = resources.gas + delta.gas;
    const gold = resources.gold + delta.gold;

    // rollback if any of the new totals are negative
    if (!canAfford(delta)) return false;

    // commit new resource totals
    resources.minerals = minerals;
    resources.gas = gas;
    resources.gold = gold;

    return true;
}

pub fn selectAugment(augmentIdx: usize) void {
    var augment = aug.augments[augmentIdx];
    if (augment.callbacks.init) |e| e(&augment);
    activeAugments.append(augment) catch unreachable;

    augmentSelectOpen = false;
    roundActive = true;
}

pub fn getAugment(augmentIdx: usize) Augment {
    return aug.augments[augmentIdx];
}

var augmentBuf: [3]?usize = .{null} ** 3;
pub var augmentSelectionPool: []?usize = augmentBuf[0..3];
pub fn openAugmentSelectMenu() void {
    if (aug.getRemainingAugmentCount() <= 0) return;

    const numAugments = aug.getRandomAugments(&augmentBuf);
    augmentSelectionPool = augmentBuf[0..numAugments];

    augmentSelectOpen = true;
    roundActive = false;
}

pub fn main() !void {
    const screenWidth = 1920;
    const screenHeight = 1080;

    rl.initWindow(screenWidth, screenHeight, "Flamepunk");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    activeAugments = ArrayList(Augment).init(alloc.allocator());
    defer activeAugments.deinit();

    activeBuildings = buildings;

    gui.init(alloc.allocator());
    defer gui.deinit();

    const tileTexture = try rl.loadTexture("./assets/sprites/tile.png");
    const tileHighlightTexture = try rl.loadTexture("./assets/sprites/tile_highlight.png");
    bld.loadBuildingTextures();

    _ = updateResources(ascension().startingResources);

    openAugmentSelectMenu();

    handleMessage(Message{ .roundStart = {} });

    while (!rl.windowShouldClose()) {
        updateAim();

        if (roundActive) {
            updateBuildings();

            elapsedRoundTime += rl.getFrameTime();
            if (elapsedRoundTime >= ascension().roundDuration) {
                if (resources.gold >= goldQuota()) {
                    roundIdx += 1;

                    if (roundIdx >= ascension().numRounds) {
                        endGame(true);
                    } else {
                        // start next round
                        openAugmentSelectMenu();
                        elapsedRoundTime = 0;
                        resources.gold = 0;
                    }
                } else {
                    endGame(false);
                }
            }

            // place building
            if (hoveredTile) |coord| {
                const lmbPressed = rl.isMouseButtonPressed(.left);
                const rmbPressed = rl.isMouseButtonPressed(.right);

                switch (placementMode) {
                    .place => |m| {
                        if (lmbPressed) placeBuilding(coord, m.archetypeIdx);
                    },
                    .demolish => {
                        if (lmbPressed) demolishBuilding(coord);
                    },
                    else => {},
                }

                if (rmbPressed) placementMode = .none;
            }
        }

        rl.beginDrawing();
        defer rl.endDrawing();

        drawGrid(tileTexture, tileHighlightTexture);
        gui.draw();
        drawHUD();

        rl.clearBackground(.black);
    }
}

fn placeBuilding(coord: Vector2, archetypeIdx: usize) void {
    if (!updateResources(building(archetypeIdx).price.negate())) return;

    // destroy obstructing building if exists
    if (tiles[tileCoordToIdx(coord)].building != null) demolishBuilding(coord);

    tiles[tileCoordToIdx(coord)].building = .{ .archetypeIdx = archetypeIdx };
}

fn demolishBuilding(coord: Vector2) void {
    // refund 50% of building price
    if (tiles[tileCoordToIdx(coord)].building) |b| {
        _ = updateResources(building(b.archetypeIdx).price.scale(0.5));
    }

    tiles[tileCoordToIdx(coord)].building = null;
}

pub fn selectBuilding(archetypeIdx: usize) void {
    if (archetypeIdx >= activeBuildings.len or activeBuildings[archetypeIdx].locked) {
        placementMode = .none;
        return;
    }

    placementMode = .{ .place = .{ .archetypeIdx = archetypeIdx } };
}

pub fn selectedBuilding() ?usize {
    return switch (placementMode) {
        .place => |m| m.archetypeIdx,
        else => null,
    };
}

pub fn unlockBuilding(archetypeIdx: usize) void {
    activeBuildings[archetypeIdx].locked = false;
}

pub fn building(archetypeIdx: usize) *const Building {
    return &activeBuildings[archetypeIdx];
}

fn updateAim() void {
    const coord = screenToIso(rl.getMousePosition());
    hoveredTile = if (isTileInMap(coord)) coord else null;
}

fn endGame(win: bool) void {
    roundActive = false;
    victory = win;
}

fn updateBuildings() void {
    for (&tiles) |*t| {
        if (t.building) |*b| {
            const archetype = activeBuildings[b.archetypeIdx];

            b.elapsedCooldown += rl.getFrameTime();
            if (b.elapsedCooldown >= archetype.cooldown) {
                b.produce();
            }
        }
    }
}

fn isTileInMap(coord: Vector2) bool {
    return coord.x >= 0 and coord.x < MAP_SIZE and coord.y >= 0 and coord.y < MAP_SIZE;
}

fn tileCoordToIdx(coord: Vector2) usize {
    return @intFromFloat(coord.x + coord.y * MAP_SIZE);
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
                .width = TILE_SIZE * PX_SCALE,
                .height = TILE_SIZE * PX_SCALE,
            };

            rl.drawTexturePro(tileSprite, src, dest, .{ .x = 0, .y = 0 }, 0, .white);

            if (roundActive) {
                if (hoveredTile) |t| {
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
            const t = tiles[tileIdx];
            const s: rl.Rectangle = .{ .x = 0, .y = 0, .width = TILE_SIZE, .height = 40 };

            const d: rl.Rectangle = .{
                .x = screen_pos.x,
                .y = screen_pos.y,
                .width = TILE_SIZE * PX_SCALE,
                .height = 40 * PX_SCALE,
            };

            if (t.building) |b| {
                rl.drawTexturePro(
                    bld.buildingTextures[b.archetypeIdx],
                    s,
                    d,
                    .{ .x = 0, .y = 8 * PX_SCALE },
                    0,
                    .white,
                );
            }
        }
    }
}

fn formatResourceString(qty: f64, buffer: []u8) [:0]u8 {
    return std.fmt.bufPrintZ(buffer, "{d:.0}", .{qty}) catch unreachable;
}

const RESOURCE_BUF_LEN = 16;

fn drawHUD() void {
    var mineralsBuf: [RESOURCE_BUF_LEN]u8 = .{0} ** RESOURCE_BUF_LEN;
    const mineralsStr = formatResourceString(resources.minerals, &mineralsBuf);

    var gasBuf: [RESOURCE_BUF_LEN]u8 = .{0} ** RESOURCE_BUF_LEN;
    const gasStr = formatResourceString(resources.gas, &gasBuf);

    var roundTimeBuf: [RESOURCE_BUF_LEN]u8 = .{0} ** RESOURCE_BUF_LEN;
    const roundTimeStr = formatResourceString(remainingRoundTime(), &roundTimeBuf);

    const xCenter = @divFloor(rl.getScreenWidth(), 2);

    rl.drawText(mineralsStr, 10, 10, 10 * PX_SCALE, .blue);
    rl.drawText(gasStr, 10, 40, 10 * PX_SCALE, .green);
    rl.drawText(roundTimeStr, xCenter, 10, 10 * PX_SCALE, .white);

    if (victory) |v| {
        rl.drawText(if (v) "VICTORY" else "DEFEAT", xCenter - 85, @divFloor(rl.getScreenHeight(), 5), 20 * PX_SCALE, .white);
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

pub fn screenSize() Vector2 {
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

fn enumLen(t: type) usize {
    return @typeInfo(t).@"enum".fields.len;
}

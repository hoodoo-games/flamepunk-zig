// imports
const std = @import("std");
const rl = @import("raylib");
const gui = @import("gui.zig");
const asc = @import("ascensions.zig");
const bld = @import("buildings.zig");
const aug = @import("augments.zig");
const map = @import("map.zig");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Vector2 = rl.Vector2;
const Matrix = rl.Matrix;

const Building = bld.Building;
const PlacedBuilding = bld.PlacedBuilding;
const Ascension = asc.Ascension;
const Augment = aug.Augment;
const Tile = map.Tile;

const ascensions = asc.ascensions;
const augments = aug.augments;
const buildings = bld.buildings;

// variables
var hoveredTile: ?Vector2 = null;
pub var tiles: [map.NUM_TILES]Tile = .{Tile{}} ** map.NUM_TILES;

var resources = Resources{};

var ascensionIndex: usize = 0;

var augmentSelectOpen: bool = false;
var roundActive: bool = false;
var roundIdx: usize = 0;
var elapsedRoundTime: f32 = 0;

pub var activeAugments: ArrayList(Augment) = undefined;
var activeBuildings: [9]Building = undefined;

var victory: ?bool = null;

pub var placementMode: PlacementMode = .none;

var augmentBuf: [3]?usize = .{null} ** 3;
pub var augmentSelectionPool: []?usize = augmentBuf[0..3];

// functions
pub fn isRoundActive() bool {
    return roundActive;
}

/// Seconds left in the current round
pub fn getRemainingRoundTime() f32 {
    return getAscension().roundDuration - elapsedRoundTime;
}

/// The selected ascension
pub fn getAscension() Ascension {
    return ascensions[ascensionIndex];
}

/// The current gold quota
pub fn getGoldQuota() f64 {
    return getAscension().goldQuota(roundIdx);
}

pub fn getHoveredTile() ?Vector2 {
    return hoveredTile;
}

pub fn isAugmentSelectOpen() bool {
    return augmentSelectOpen;
}

/// Send an augment message
pub fn handleMessage(message: Message) void {
    var m = message;

    for (activeAugments.items) |*a| if (a.callbacks.before) |e| e(a, &m);
    for (activeAugments.items) |*a| if (a.callbacks.add) |e| e(a, &m);
    for (activeAugments.items) |*a| if (a.callbacks.multiply) |e| e(a, &m);
    for (activeAugments.items) |*a| if (a.callbacks.after) |e| e(a, &m);

    m.apply();
}

/// Get the current resource stockpile
pub fn getResources() Resources {
    return resources;
}

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

/// gets the augment prototype
pub fn getAugment(augmentIdx: usize) Augment {
    return aug.augments[augmentIdx];
}

/// adds an augment to the active set
pub fn selectAugment(augmentIdx: usize) void {
    var augment = aug.augments[augmentIdx];
    if (augment.callbacks.init) |e| e(&augment);
    activeAugments.append(augment) catch unreachable;

    augmentSelectOpen = false;
    roundActive = true;
}

/// opens the augment selection menu
pub fn openAugmentSelectMenu() void {
    if (aug.getRemainingAugmentCount() <= 0) return;

    const numAugments = aug.getRandomAugments(&augmentBuf);
    augmentSelectionPool = augmentBuf[0..numAugments];

    augmentSelectOpen = true;
    roundActive = false;
}

/// Places a building on the map, demolishing an obstructing building if one exists.
/// No-op if we cannot afford the building price
fn placeBuilding(coord: Vector2, archetypeIdx: usize) void {
    if (!updateResources(getBuilding(archetypeIdx).price.negate())) return;

    // destroy obstructing building if exists
    if (tiles[map.tileCoordToIdx(coord)].building != null) demolishBuilding(coord);

    tiles[map.tileCoordToIdx(coord)].building = .{ .archetypeIdx = archetypeIdx };
    tiles[map.tileCoordToIdx(coord)].building.position = coord;
}

/// Demolishes a placed building, refunding 50% of price
fn demolishBuilding(coord: Vector2) void {
    // refund 50% of building price
    if (tiles[map.tileCoordToIdx(coord)].building) |b| {
        _ = updateResources(getBuilding(b.archetypeIdx).price.scale(0.5));
    }

    tiles[map.tileCoordToIdx(coord)].building = null;
}

/// Selects a building archetype from the construction menu and enters placement mode
pub fn selectBuilding(archetypeIdx: usize) void {
    if (archetypeIdx >= activeBuildings.len or activeBuildings[archetypeIdx].locked) {
        placementMode = .none;
        return;
    }

    placementMode = .{ .place = .{ .archetypeIdx = archetypeIdx } };
}

/// Gets the selected building archetype index, null if nothing is selected
pub fn getSelectedBuilding() ?usize {
    return switch (placementMode) {
        .place => |m| m.archetypeIdx,
        else => null,
    };
}

/// Sets a building archetype to be unlocked
pub fn unlockBuilding(archetypeIdx: usize) void {
    activeBuildings[archetypeIdx].locked = false;
}

/// Gets a building archetype
pub fn getBuilding(archetypeIdx: usize) *const Building {
    return &activeBuildings[archetypeIdx];
}

pub fn init(alloc: Allocator) void {
    activeAugments = ArrayList(Augment).init(alloc);
    activeBuildings = buildings;
}

pub fn deinit() void {
    activeAugments.deinit();
}

pub fn update() void {
    updateAim();

    if (isRoundActive()) {
        updateBuildings();

        elapsedRoundTime += rl.getFrameTime();
        if (elapsedRoundTime >= getAscension().roundDuration) {
            if (resources.gold >= getGoldQuota()) {
                roundIdx += 1;

                if (roundIdx >= getAscension().numRounds) {
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
}

fn endGame(win: bool) void {
    roundActive = false;
    victory = win;
}

fn updateAim() void {
    const coord = map.screenToIso(rl.getMousePosition());
    hoveredTile = if (map.isTileInBounds(coord)) coord else null;
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

fn formatResourceString(qty: f64, buffer: []u8) [:0]u8 {
    return std.fmt.bufPrintZ(buffer, "{d:.0}", .{qty}) catch unreachable;
}

const RESOURCE_BUF_LEN = 16;

pub fn drawHUD() void {
    var mineralsBuf: [RESOURCE_BUF_LEN]u8 = .{0} ** RESOURCE_BUF_LEN;
    const mineralsStr = formatResourceString(resources.minerals, &mineralsBuf);

    var gasBuf: [RESOURCE_BUF_LEN]u8 = .{0} ** RESOURCE_BUF_LEN;
    const gasStr = formatResourceString(resources.gas, &gasBuf);

    var roundTimeBuf: [RESOURCE_BUF_LEN]u8 = .{0} ** RESOURCE_BUF_LEN;
    const roundTimeStr = formatResourceString(getRemainingRoundTime(), &roundTimeBuf);

    const xCenter = @divFloor(rl.getScreenWidth(), 2);

    rl.drawText(mineralsStr, 10, 10, 10 * utils.PX_SCALE, .blue);
    rl.drawText(gasStr, 10, 40, 10 * utils.PX_SCALE, .green);
    rl.drawText(roundTimeStr, xCenter, 10, 10 * utils.PX_SCALE, .white);

    if (victory) |v| {
        rl.drawText(
            if (v) "VICTORY" else "DEFEAT",
            xCenter - 85,
            @divFloor(rl.getScreenHeight(), 5),
            20 * utils.PX_SCALE,
            .white,
        );
    }
}

// types
const PlacementMode = union(enum(u8)) {
    none,
    place: struct { archetypeIdx: usize },
    demolish,
};

/// Scriptable augment messages
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

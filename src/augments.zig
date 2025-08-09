const std = @import("std");
const rl = @import("raylib");
const state = @import("state.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Vector2 = rl.Vector2;
const Texture2D = rl.Texture2D;
const Message = state.Message;

pub const augments = [_]Augment{
    //.{
    //    .name = "Wright to Aviation", //fka Bloodrush
    //    .description = "Unlocks the skyport",
    //    .properties = .{ .buildingUnlock = .{ .archetypeIdx = 4 } },
    //    .callbacks = .{ .init = unlockBuilding },
    //},
    //.{
    //    .name = "Unlock Gravity Stone",
    //    .description = "Unlocks the Gravity Stone building.",
    //    .properties = .{ .buildingUnlock = .{ .archetypeIdx = 5 } },
    //    .callbacks = .{ .init = unlockBuilding },
    //},
    //.{
    //    .name = "Unlock Mountainshell",
    //    .description = "Unlocks the Mountainshell building.",
    //    .properties = .{ .buildingUnlock = .{ .archetypeIdx = 6 } },
    //    .callbacks = .{ .init = unlockBuilding },
    //},
    //.{
    //    .name = "Insanity Potion",
    //    .description = "Unlocks the Insanity Lab",
    //    .properties = .{ .buildingUnlock = .{ .archetypeIdx = 7 } },
    //    .callbacks = .{ .init = unlockBuilding },
    //},
    //.{
    //    .name = "???",
    //    .description = "Unlocks ???",
    //    .properties = .{ .buildingUnlock = .{ .archetypeIdx = 8 } },
    //    .callbacks = .{ .init = unlockBuilding },
    //},
    .{
        .name = "Word on Wallstreet", //fka campfire stories
        .description = "When a building produces gold, also gain the production of adjacent buildings.",
        .callbacks = .{ .after = wordOnWallstreet },
    },
    .{
        .name = "Glass Tools",
        .description = "Double all production of minerals for the next fiscal year; breaks afterwards.",
        .properties = .{ .glassTools = .{ .hasBroken = false } },
        .callbacks = .{ .after = glassTools },
    },
    .{
        .name = "Rapid Industrialization", //fka HOA
        .description = "All mine buildings produce 1 more of each resource.",
        .callbacks = .{ .add = rapidIndustrialization },
    },
    .{
        .name = "Overtime Policy",
        .description = "After the fiscal goal has been met, all buildings produce 50% bonus resources for the rest of the year.",
        .callbacks = .{ .multiply = overtimePolicy },
    },
    //.{
    //    .name = "Into Diamonds", //fka Petrified Wood
    //    .description = "When you produce gas, also produce 50% of that amount in minerals.",
    //    .callbacks = .{},
    //},
    //.{
    //    .name = "Trickledown Economics",
    //    .description = "Every time you produce 10 gold, also produce 1 gas and 1 minerals.",
    //    .callbacks = .{},
    //},

    // Augment ideas:
    // - "Bullish Market" - Halfway through each fiscal year, double your resources
    // - "Housing Subsidy" - Constructing a building instantly refunds 50% of its cost
    // - "New Age" - All buildings placed this year and after produce double gas
};

fn wordOnWallstreet(_: *Augment, m: *Message) void {
    switch (m.*) {
        .buildingProduced => |bpm| {
            if (bpm.building.archetypeIdx == 2) { // Market
                for (&state.tiles) |*t| {
                    if (t.building) |*adjBuilding| {
                        if (adjBuilding.archetypeIdx != bpm.building.archetypeIdx) {
                            // Check if adjacent
                            const dx = @abs(bpm.building.gridPos.x - adjBuilding.gridPos.x);
                            const dy = @abs(bpm.building.gridPos.y - adjBuilding.gridPos.y);
                            if ((dx <= 1) and (dy <= 1)) {
                                adjBuilding.produce();
                            }
                        }
                    }
                }
            }
        },
        else => {},
    }
}

fn glassTools(self: *Augment, m: *Message) void {
    switch (m.*) {
        .buildingProduced => |*bpm| {
            switch (self.properties) {
                .glassTools => |*gt| {
                    if (gt.hasBroken) return;
                    bpm.yield.minerals *= 2;
                    bpm.yield.gas *= 2;
                    bpm.yield.gold *= 2;
                },
                else => {},
            }
        },
        .roundEnd => {
            switch (self.properties) {
                .glassTools => |*gt| {
                    gt.hasBroken = true;
                    std.debug.print("Glass Tools have broken!", .{});
                },
                else => {},
            }
        },
        else => {},
    }
}

fn rapidIndustrialization(_: *Augment, m: *Message) void {
    switch (m.*) {
        .buildingProduced => |*bpm| {
            if (bpm.building.archetypeIdx == 0) { // it's a mine
                bpm.yield.minerals += 1;
                bpm.yield.gas += 1;
                bpm.yield.gold += 1;
            }
        },
        else => {},
    }
}

fn overtimePolicy(_: *Augment, m: *Message) void {
    switch (m.*) {
        .buildingProduced => |*bpm| {
            if (state.getResources().gold >= state.getGoldQuota()) {
                bpm.yield.minerals *= 1.5;
                bpm.yield.gas *= 1.5;
                bpm.yield.gold *= 1.5;
            }
        },
        else => {},
    }
}

fn unlockBuilding(self: *Augment) void {
    switch (self.properties) {
        .buildingUnlock => |v| {
            state.unlockBuilding(v.archetypeIdx);
        },
        else => {},
    }
}

pub const MessageHandler = *const fn (*Augment, *Message) void;

pub const Augment = struct {
    name: [:0]const u8,
    description: [:0]const u8,
    properties: Properties = .none,
    callbacks: struct {
        init: ?*const fn (*Augment) void = null,
        before: ?MessageHandler = null,
        add: ?MessageHandler = null,
        multiply: ?MessageHandler = null,
        after: ?MessageHandler = null,
    },

    const Properties = union(enum(usize)) { none, chainReaction: struct {
        procChance: f32,
    }, buildingUnlock: struct {
        archetypeIdx: usize,
    }, glassTools: struct {
        hasBroken: bool = false,
    } };
};

pub fn getRemainingAugmentCount() usize {
    var count: usize = 0;
    for (0..augments.len) |i| {
        if (!isAugmentActive(i)) count += 1;
    }

    return count;
}

pub fn isAugmentActive(augmentIdx: usize) bool {
    for (state.activeAugments.items) |active| {
        if (std.mem.eql(u8, augments[augmentIdx].name, active.name)) {
            return true;
        }
    }

    return false;
}

pub fn getRandomAugments(buffer: []?usize) usize {
    @memset(buffer, null);

    var numReturned: usize = 0;
    const qty = @min(buffer.len, getRemainingAugmentCount());

    for (0..qty) |i| {
        var randIdx: usize = @intCast(rl.getRandomValue(0, @as(i32, @intCast(qty)) - 1));
        while (isAugmentActive(randIdx) or arrayContains(randIdx, buffer)) {
            randIdx = @intCast(rl.getRandomValue(0, @as(i32, @intCast(augments.len)) - 1));
        }

        buffer[i] = randIdx;
        numReturned += 1;
    }

    return numReturned;
}

fn arrayContains(value: usize, buffer: []?usize) bool {
    for (buffer) |v| {
        if (v == value) return true;
    }

    return false;
}

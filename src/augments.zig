const std = @import("std");
const rl = @import("raylib");
const main = @import("main.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Vector2 = rl.Vector2;
const Texture2D = rl.Texture2D;
const Message = main.Message;

pub const augments = [_]Augment{
    .{
        .name = "Chain Reaction",
        .description = "5% chance to make all gas buildings produce when a gas building produces.",
        .properties = .{ .chainReaction = .{ .procChance = 0.05 } },
        .callbacks = .{ .after = chainReaction },
    },
    .{
        .name = "Insanity Potion",
        .description = "Unlocks the Insanity Lab",
        .properties = .{ .buildingUnlock = .{ .archetypeIdx = 7 } },
        .callbacks = .{ .init = unlockBuilding },
    },
    .{
        .name = "...",
        .description = "...",
        .callbacks = .{},
    },
};

fn chainReaction(_: *Augment, m: *Message) void {
    switch (m.*) {
        .buildingProduced => {
            // std.log.debug("AUGMENT {s}", .{self.name});
        },
        else => {},
    }
}

fn unlockBuilding(self: *Augment) void {
    switch (self.properties) {
        .buildingUnlock => |v| {
            main.unlockBuilding(v.archetypeIdx);
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

    const Properties = union(enum(usize)) {
        none,
        chainReaction: struct {
            procChance: f32,
        },
        buildingUnlock: struct {
            archetypeIdx: usize,
        },
    };
};

pub fn getRemainingAugmentCount() usize {
    var count: usize = 0;
    for (0..augments.len) |i| {
        if (!isAugmentActive(i)) count += 1;
    }

    return count;
}

pub fn isAugmentActive(augmentIdx: usize) bool {
    for (main.activeAugments.items) |active| {
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

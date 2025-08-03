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
};

fn chainReaction(self: *Augment, m: *Message) void {
    switch (m.*) {
        .buildingProduced => {
            std.log.debug("AUGMENT {s}", .{self.name});
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
    name: []const u8,
    description: []const u8,
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

const std = @import("std");
const rl = @import("raylib");
const state = @import("state.zig");

const Resources = state.Resources;

pub const ascensions = [_]Ascension{
    .{
        .name = "Demigod",
        .description = "For those powerful few",
        .startingResources = .{
            .minerals = 60,
        },
        .numRounds = 6,
        .roundDuration = 120,
    },
};

pub const Ascension = struct {
    name: []const u8,
    description: []const u8,
    startingResources: Resources,
    numRounds: usize,
    roundDuration: f32,

    pub fn goldQuota(_: *const Ascension, round: usize) f32 {
        //TODO gold quota scaling function
        return @floatFromInt((round + 1) * 100);
    }
};

const std = @import("std");
const rl = @import("raylib");
const state = @import("state.zig");

const Resources = state.Resources;

pub const ascensions = [_]Ascension{
    .{
        .name = "Junior Manager",
        .description = "A stepping stone for aspiring leaders.",
        .startingResources = .{
            .minerals = 60,
        },
        .numRounds = 6,
        .roundDuration = 2,
    },
};

pub const Ascension = struct {
    name: []const u8,
    description: []const u8,
    startingResources: Resources,
    numRounds: usize,
    roundDuration: f32,

    pub fn goldQuota(_: *const Ascension, _: usize) f32 {
        //TODO gold quota scaling function
        // return @floatFromInt(10 + std.math.pow(usize, 10, round));
        return 0;
    }
};

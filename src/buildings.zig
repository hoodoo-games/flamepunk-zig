const std = @import("std");
const rl = @import("raylib");
const main = @import("main.zig");

const Resources = main.Resources;

pub const buildings = [9]Building{
    .{
        .name = "Mine",
        .description = "Basic mineral and gas production",
        .cooldown = 3,
        .price = .{ .minerals = 30 },
        .yield = .{ .minerals = 3, .gas = 1 },
    },
    .{
        .name = "Extractor",
        .description = "Advanced gas production",
        .cooldown = 3,
        .price = .{ .minerals = 100 },
        .yield = .{ .gas = 10 },
    },
    .{
        .name = "Market", // fka kindlehall
        .description = "Produces gold",
        .cooldown = 3,
        .price = .{ .minerals = 250 },
        .yield = .{ .gold = 5 },
    },
    .{
        .name = "Quarry",
        .description = "Advanced mineral production",
        .cooldown = 3,
        .price = .{ .minerals = 150, .gas = 500 },
        .yield = .{ .minerals = 50 },
    },
    .{
        .name = "Sky Port", // fka pyrocore
        .description = "Produces lots of gold",
        .cooldown = 3,
        .price = .{},
        .yield = .{ .gold = 15 },
    },
    .{
        .name = "Gravity Stone",
        .description = "...",
        .cooldown = 3,
        .price = .{ .minerals = 100, .gas = 100 },
        .yield = .{},
        .locked = true,
    },
    .{
        .name = "Mountainshell",
        .description = "...",
        .cooldown = 5,
        .price = .{ .minerals = 100, .gas = 100 },
        .yield = .{},
        .locked = true,
    },
    .{
        .name = "Insanity Lab",
        .description = "...",
        .cooldown = 6,
        .price = .{ .minerals = 3141, .gas = 592 },
        .yield = .{ .minerals = -53, .gas = 58, .gold = 97 },
        .locked = true,
    },
    .{
        .name = "Obelisk",
        .description = "PONDER THE OBELISK",
        .cooldown = 5,
        .price = .{ .minerals = 100, .gas = 100 },
        .yield = .{ .gold = 1000 },
        .locked = true,
    },
};

pub const Building = struct {
    name: [:0]const u8,
    description: [:0]const u8,
    cooldown: f32,
    price: Resources,
    yield: Resources,
    locked: bool = false,
};

pub const PlacedBuilding = struct {
    archetypeIdx: usize,
    elapsedCooldown: f32 = 0,
    productionDurationModifier: f32 = 0,
    yieldModifier: Resources = .{},

    pub fn archetype(self: *const PlacedBuilding) Building {
        return buildings[self.archetypeIdx];
    }

    pub fn cooldown(self: *const PlacedBuilding) f32 {
        return self.archetype().cooldown + self.productionDurationModifier;
    }

    pub fn yield(self: *const PlacedBuilding) Resources {
        return self.archetype().yield.add(self.yieldModifier);
    }

    pub fn produce(self: *PlacedBuilding) void {
        main.handleMessage(.{ .buildingProduced = .{
            .building = self,
            .yield = self.yield(),
        } });

        self.elapsedCooldown = 0;
    }
};

pub var buildingTextures: [buildings.len]rl.Texture2D = .{undefined} ** buildings.len;

pub fn loadBuildingTextures() void {
    var buf: [64]u8 = .{0} ** 64;

    for (0..buildingTextures.len) |i| {
        const path = std.fmt.bufPrintZ(
            &buf,
            "./assets/sprites/buildings/{s}.png",
            .{buildings[i].name},
        ) catch unreachable;

        buildingTextures[i] = rl.loadTexture(path) catch unreachable;
    }
}

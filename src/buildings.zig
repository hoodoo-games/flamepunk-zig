const std = @import("std");
const rl = @import("raylib");
const main = @import("main.zig");

const Resources = main.Resources;

pub const buildings = [9]Building{
    .{
        .name = "Mine",
        .description = "Basic mineral and gas production",
        .productionDuration = 3,
        .yield = .{ .minerals = 3, .gas = 1 },
    },
    .{
        .name = "Extractor",
        .description = "Advanced gas production",
        .productionDuration = 3,
        .yield = .{ .gas = 10 },
    },
    .{
        .name = "Market", // fka kindlehall
        .description = "Produces gold",
        .productionDuration = 3,
        .yield = .{ .gold = 1 },
    },
    .{
        .name = "Quarry",
        .description = "Advanced mineral production",
        .productionDuration = 3,
        .yield = .{ .minerals = 50 },
    },
    .{
        .name = "Sky Port", // fka pyrocore
        .description = "Produces lots of gold",
        .productionDuration = 3,
        .yield = .{ .gold = 15 },
    },
    .{
        .name = "Gravity Stone",
        .description = "...",
        .productionDuration = 1,
        .yield = .{},
        .locked = true,
    },
    .{
        .name = "Mountainshell",
        .description = "...",
        .productionDuration = 1,
        .yield = .{},
        .locked = true,
    },
    .{
        .name = "Insanity Lab",
        .description = "...",
        .productionDuration = 1,
        .yield = .{},
        .locked = true,
    },
    .{
        .name = "Obelisk",
        .description = "PONDER THE OBELISK",
        .productionDuration = 5,
        .yield = .{ .gold = 1000 },
        .locked = true,
    },
};

pub const Building = struct {
    name: [:0]const u8,
    description: [:0]const u8,
    productionDuration: f32,
    yield: Resources,
    locked: bool = false,
};

pub const PlacedBuilding = struct {
    archetypeIdx: usize,
    elapsedProductionTime: f32 = 0,
    productionDurationModifier: f32 = 0,
    yieldModifier: Resources = .{},

    pub fn archetype(self: *const PlacedBuilding) Building {
        return buildings[self.archetypeIdx];
    }

    pub fn productionDuration(self: *const PlacedBuilding) f32 {
        return self.archetype().productionDuration + self.productionDurationModifier;
    }

    pub fn yield(self: *const PlacedBuilding) Resources {
        return self.archetype().yield.add(self.yieldModifier);
    }

    pub fn produce(self: *PlacedBuilding) void {
        main.handleMessage(.{ .buildingProduced = .{
            .building = self,
            .yield = self.yield(),
        } });

        self.elapsedProductionTime = 0;
    }
};

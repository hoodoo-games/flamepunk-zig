const std = @import("std");
const rl = @import("raylib");
const main = @import("main.zig");
const aug = @import("augments.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Vector2 = rl.Vector2;
const Texture2D = rl.Texture2D;

var buildingBtnTex: Texture2D = undefined;
var buildingBtnLockedTex: Texture2D = undefined;
var demolishBtnTex: Texture2D = undefined;
var coinTex: Texture2D = undefined;
var augmentCardTex: Texture2D = undefined;

fn pointInRect(point: Vector2, rect: rl.Rectangle) bool {
    const offset = point.subtract(.{ .x = rect.x, .y = rect.y });
    return offset.x >= 0 and offset.x < rect.width and offset.y >= 0 and offset.y < rect.height;
}

pub fn init(_: Allocator) void {
    buildingBtnTex = rl.loadTexture("./assets/sprites/building_btn.png") catch unreachable;
    buildingBtnLockedTex = rl.loadTexture("./assets/sprites/building_btn_locked.png") catch unreachable;
    demolishBtnTex = rl.loadTexture("./assets/sprites/demolish_btn.png") catch unreachable;
    coinTex = rl.loadTexture("./assets/sprites/coin.png") catch unreachable;
    augmentCardTex = rl.loadTexture("./assets/sprites/augment_card.png") catch unreachable;
}

pub fn deinit() void {}

pub fn draw() void {
    drawHUD();
}

fn drawHUD() void {
    if (main.augmentSelectOpen) {
        drawAugmentSelectMenu();
    } else {
        drawConstructionMenu();
    }

    drawGoldQuota();
}

fn drawConstructionMenu() void {
    const screen = main.screenSize().scale(1 / main.PX_SCALE);
    const padding = 5;
    const origin = Vector2{ .x = 5, .y = screen.y - 3 * (32 + padding) };

    for (0..3) |y| {
        for (0..3) |x| {
            const pos = (Vector2{
                .x = @as(f32, @floatFromInt(x)) * (32 + padding),
                .y = @as(f32, @floatFromInt(y)) * (32 + padding),
            }).add(origin).scale(main.PX_SCALE);

            drawBuildingBtn(x + y * 3, pos);
        }
    }

    drawDemolishButton(origin.add(.{ .x = 3 * (32 + padding), .y = 2 * (32 + padding) }).scale(main.PX_SCALE));
}

fn drawBuildingBtn(archetypeIdx: usize, pos: Vector2) void {
    const src: rl.Rectangle = .{ .x = 0, .y = 0, .width = 32, .height = 32 };

    const dest: rl.Rectangle = .{
        .x = pos.x,
        .y = pos.y,
        .width = 32 * main.PX_SCALE,
        .height = 32 * main.PX_SCALE,
    };

    const hovered = pointInRect(rl.getMousePosition(), dest);
    const lmbDown = hovered and rl.isMouseButtonDown(.left);
    const selected = if (main.selectedBuilding()) |idx| idx == archetypeIdx else false;

    if (hovered and rl.isMouseButtonReleased(.left)) main.selectBuilding(archetypeIdx);

    const building = main.building(archetypeIdx);

    rl.drawTexturePro(
        if (building.locked) buildingBtnLockedTex else buildingBtnTex,
        src,
        dest,
        .{ .x = 0, .y = 0 },
        0,
        if (lmbDown) .gray else if (hovered) .light_gray else if (selected) .orange else .white,
    );

    if (hovered) {
        rl.drawText(
            if (building.locked) "???" else building.name,
            @intFromFloat(pos.x),
            @intFromFloat(pos.y - 10 * main.PX_SCALE),
            6 * main.PX_SCALE,
            .white,
        );
    }
}

fn drawDemolishButton(pos: Vector2) void {
    const src: rl.Rectangle = .{ .x = 0, .y = 0, .width = 32, .height = 32 };

    const dest: rl.Rectangle = .{
        .x = pos.x,
        .y = pos.y,
        .width = 32 * main.PX_SCALE,
        .height = 32 * main.PX_SCALE,
    };

    const hovered = pointInRect(rl.getMousePosition(), dest);
    const lmbDown = hovered and rl.isMouseButtonDown(.left);

    const selected = switch (main.placementMode) {
        .demolish => true,
        else => false,
    };

    if (hovered and rl.isMouseButtonReleased(.left)) main.placementMode = .demolish;

    rl.drawTexturePro(
        demolishBtnTex,
        src,
        dest,
        .{ .x = 0, .y = 0 },
        0,
        if (lmbDown) .gray else if (hovered) .light_gray else if (selected) .orange else .white,
    );
}

fn drawGoldQuota() void {
    const screen = main.screenSize().scale(1 / main.PX_SCALE);
    const origin = Vector2{ .x = screen.x - 125, .y = screen.y - 15 };

    const src: rl.Rectangle = .{ .x = 0, .y = 0, .width = 10, .height = 10 };
    const dest: rl.Rectangle = .{
        .x = origin.x * main.PX_SCALE,
        .y = origin.y * main.PX_SCALE,
        .width = 10 * main.PX_SCALE,
        .height = 10 * main.PX_SCALE,
    };

    rl.drawTexturePro(
        coinTex,
        src,
        dest,
        .{ .x = 0, .y = 0 },
        0,
        .white,
    );

    var buf: [32]u8 = .{0} ** 32;
    const str = std.fmt.bufPrintZ(&buf, "{d:.0} / {d:.0}", .{
        main.resources.gold,
        main.goldQuota(),
    }) catch unreachable;

    rl.drawText(
        str,
        @intFromFloat(origin.x * main.PX_SCALE + 40),
        @intFromFloat(origin.y * main.PX_SCALE),
        10 * main.PX_SCALE,
        .white,
    );
}

var augmentBuf: [3]usize = .{undefined} ** 3;

fn drawAugmentSelectMenu() void {
    const screen = main.screenSize().scale(1 / main.PX_SCALE);
    const padding = 10;
    const origin = Vector2{ .x = screen.x / 2 - (2 * (56 + padding) / 2), .y = screen.y / 2 };

    rl.drawRectangle(
        0,
        0,
        rl.getScreenWidth(),
        rl.getScreenHeight(),
        .{ .r = 0, .g = 0, .b = 0, .a = 175 },
    );

    rl.drawText(
        "SELECT AN AUGMENT",
        @intFromFloat((screen.x / 2 - 55) * main.PX_SCALE),
        @intFromFloat((screen.y / 2 - 60) * main.PX_SCALE),
        10 * main.PX_SCALE,
        .orange,
    );

    const qty = @min(3, aug.getRandomAugments(&augmentBuf));
    const qtyInv: f32 = @floatFromInt(3 - qty);
    for (0.., augmentBuf) |i, aIdx| {
        drawAugmentCard(aIdx, origin.add(.{ .x = (@as(f32, @floatFromInt(i)) + qtyInv * 0.5) * (56 + padding), .y = 0 }));
    }
}

fn drawAugmentCard(augmentIdx: usize, pos: Vector2) void {
    const src: rl.Rectangle = .{ .x = 0, .y = 0, .width = 56, .height = 78 };
    const dest: rl.Rectangle = .{
        .x = (pos.x - 56 / 2) * main.PX_SCALE,
        .y = (pos.y - 78 / 2) * main.PX_SCALE,
        .width = 56 * main.PX_SCALE,
        .height = 78 * main.PX_SCALE,
    };

    const hovered = pointInRect(rl.getMousePosition(), dest);
    const lmbDown = hovered and rl.isMouseButtonDown(.left);

    if (hovered and rl.isMouseButtonReleased(.left)) main.selectAugment(augmentIdx);

    const augment = main.getAugment(augmentIdx);

    rl.drawTexturePro(
        augmentCardTex,
        src,
        dest,
        .{ .x = 0, .y = 0 },
        0,
        if (lmbDown) .gray else if (hovered) .light_gray else .white,
    );

    if (hovered) {
        rl.drawText(
            augment.name,
            @intFromFloat(dest.x),
            @intFromFloat(dest.y + 80 * main.PX_SCALE),
            6 * main.PX_SCALE,
            .white,
        );
    }
}

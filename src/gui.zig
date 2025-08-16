const std = @import("std");
const rl = @import("raylib");
const state = @import("state.zig");
const aug = @import("augments.zig");
const utils = @import("utils.zig");

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const Vector2 = rl.Vector2;
const Texture2D = rl.Texture2D;

var buildingBtnTex: Texture2D = undefined;
var buildingBtnLockedTex: Texture2D = undefined;
var demolishBtnTex: Texture2D = undefined;
var coinTex: Texture2D = undefined;
var augmentCardTex: Texture2D = undefined;
var augmentBadgeTex: Texture2D = undefined;

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
    augmentBadgeTex = rl.loadTexture("./assets/sprites/augment_badge.png") catch unreachable;
}

pub fn deinit() void {}

pub fn draw() void {
    drawHUD();
}

fn drawHUD() void {
    if (state.isAugmentSelectOpen()) {
        drawAugmentSelectMenu();
    } else {
        drawConstructionMenu();
    }

    drawGoldQuota();
    drawAugments();
}

fn drawConstructionMenu() void {
    const screen = utils.screenSize().scale(1 / utils.PX_SCALE);
    const padding = 5;
    const origin = Vector2{ .x = 5, .y = screen.y - 3 * (32 + padding) };

    for (0..3) |y| {
        for (0..3) |x| {
            const pos = (Vector2{
                .x = @as(f32, @floatFromInt(x)) * (32 + padding),
                .y = @as(f32, @floatFromInt(y)) * (32 + padding),
            }).add(origin).scale(utils.PX_SCALE);

            drawBuildingBtn(x + y * 3, pos, origin.add(.{
                .x = 4 * (32 + padding) + 5,
                .y = 2 * (32 + padding),
            }));
        }
    }

    drawDemolishButton(origin.add(.{ .x = 3 * (32 + padding), .y = 2 * (32 + padding) }).scale(utils.PX_SCALE));
}

fn drawBuildingBtn(archetypeIdx: usize, pos: Vector2, detailsOrigin: Vector2) void {
    const src: rl.Rectangle = .{ .x = 0, .y = 0, .width = 32, .height = 32 };

    const dest: rl.Rectangle = .{
        .x = pos.x,
        .y = pos.y,
        .width = 32 * utils.PX_SCALE,
        .height = 32 * utils.PX_SCALE,
    };

    const hovered = pointInRect(rl.getMousePosition(), dest);
    const lmbDown = hovered and rl.isMouseButtonDown(.left);
    const selected = if (state.getSelectedBuilding()) |idx| idx == archetypeIdx else false;

    if (hovered and rl.isMouseButtonReleased(.left)) state.selectBuilding(archetypeIdx);

    const building = state.getBuilding(archetypeIdx);

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
            @intFromFloat((detailsOrigin.x) * utils.PX_SCALE),
            @intFromFloat((detailsOrigin.y) * utils.PX_SCALE),
            6 * utils.PX_SCALE,
            .white,
        );

        if (!building.locked) {
            rl.drawText(
                building.description,
                @intFromFloat((detailsOrigin.x) * utils.PX_SCALE),
                @intFromFloat((detailsOrigin.y + 10) * utils.PX_SCALE),
                6 * utils.PX_SCALE,
                .white,
            );

            var strBuf: [64:0]u8 = .{0} ** 64;
            _ = std.fmt.bufPrintZ(
                &strBuf,
                "PRICE  --  Minerals: {d:.0}, Gas: {d:.0}",
                .{ building.price.minerals, building.price.gas },
            ) catch unreachable;

            rl.drawText(
                &strBuf,
                @intFromFloat((detailsOrigin.x) * utils.PX_SCALE),
                @intFromFloat((detailsOrigin.y + 20) * utils.PX_SCALE),
                6 * utils.PX_SCALE,
                .white,
            );

            strBuf = .{0} ** 64;
            _ = std.fmt.bufPrintZ(
                &strBuf,
                "YIELD  --  Minerals: {d:.0}, Gas: {d:.0}, Gold: {d:.0}",
                .{ building.yield.minerals, building.yield.gas, building.yield.gold },
            ) catch unreachable;

            rl.drawText(
                &strBuf,
                @intFromFloat((detailsOrigin.x) * utils.PX_SCALE),
                @intFromFloat((detailsOrigin.y + 27) * utils.PX_SCALE),
                6 * utils.PX_SCALE,
                .white,
            );
        }
    }
}

fn drawDemolishButton(pos: Vector2) void {
    const src: rl.Rectangle = .{ .x = 0, .y = 0, .width = 32, .height = 32 };

    const dest: rl.Rectangle = .{
        .x = pos.x,
        .y = pos.y,
        .width = 32 * utils.PX_SCALE,
        .height = 32 * utils.PX_SCALE,
    };

    const hovered = pointInRect(rl.getMousePosition(), dest);
    const lmbDown = hovered and rl.isMouseButtonDown(.left);

    const selected = switch (state.placementMode) {
        .demolish => true,
        else => false,
    };

    if (hovered and rl.isMouseButtonReleased(.left)) state.placementMode = .demolish;

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
    const screen = utils.screenSize().scale(1 / utils.PX_SCALE);
    const origin = Vector2{ .x = screen.x - 125, .y = screen.y - 15 };

    const src: rl.Rectangle = .{ .x = 0, .y = 0, .width = 10, .height = 10 };
    const dest: rl.Rectangle = .{
        .x = origin.x * utils.PX_SCALE,
        .y = origin.y * utils.PX_SCALE,
        .width = 10 * utils.PX_SCALE,
        .height = 10 * utils.PX_SCALE,
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
        state.getResources().gold,
        state.getGoldQuota(),
    }) catch unreachable;

    rl.drawText(
        str,
        @intFromFloat(origin.x * utils.PX_SCALE + 40),
        @intFromFloat(origin.y * utils.PX_SCALE),
        10 * utils.PX_SCALE,
        .white,
    );
}

fn drawAugmentSelectMenu() void {
    const screen = utils.screenSize().scale(1 / utils.PX_SCALE);
    const padding = 5;

    const origin = Vector2{ .x = screen.x / 2, .y = screen.y / 2 };

    rl.drawRectangle(
        0,
        0,
        rl.getScreenWidth(),
        rl.getScreenHeight(),
        .{ .r = 0, .g = 0, .b = 0, .a = 175 },
    );

    rl.drawText(
        "SELECT AN AUGMENT",
        @intFromFloat((screen.x / 2 - 55) * utils.PX_SCALE),
        @intFromFloat((screen.y / 2 - 60) * utils.PX_SCALE),
        10 * utils.PX_SCALE,
        .orange,
    );

    const h: f32 = @floatFromInt(augmentCardTex.height);

    // const qty = @min(3, state.augmentSelectionPool.len);
    // const qtyInv: f32 = @floatFromInt(3 - qty);
    for (0.., state.augmentSelectionPool) |i, a| {
        if (a) |idx| {
            drawAugmentCard(idx, origin.add(.{
                .x = 0,
                .y = @as(f32, @floatFromInt(i)) * (h + padding),
            }));
        }
    }
}

fn drawAugmentCard(augmentIdx: usize, pos: Vector2) void {
    const w: f32 = @floatFromInt(augmentCardTex.width);
    const h: f32 = @floatFromInt(augmentCardTex.height);

    const src: rl.Rectangle = .{ .x = 0, .y = 0, .width = w, .height = h };

    const dest: rl.Rectangle = .{
        .x = (pos.x - w / 2) * utils.PX_SCALE,
        .y = (pos.y - h / 2) * utils.PX_SCALE,
        .width = w * utils.PX_SCALE,
        .height = h * utils.PX_SCALE,
    };

    const hovered = pointInRect(rl.getMousePosition(), dest);
    const lmbDown = hovered and rl.isMouseButtonDown(.left);

    if (hovered and rl.isMouseButtonReleased(.left)) state.selectAugment(augmentIdx);

    const augment = state.getAugment(augmentIdx);

    rl.drawTexturePro(
        augmentCardTex,
        src,
        dest,
        .{ .x = 0, .y = 0 },
        0,
        if (lmbDown) .gray else if (hovered) .light_gray else .white,
    );

    rl.drawText(
        augment.name,
        @intFromFloat(dest.x + 42 * utils.PX_SCALE),
        @intFromFloat(dest.y + 8 * utils.PX_SCALE),
        6 * utils.PX_SCALE,
        .white,
    );

    rl.drawText(
        augment.description,
        @intFromFloat(dest.x + 42 * utils.PX_SCALE),
        @intFromFloat(dest.y + 18 * utils.PX_SCALE),
        4 * utils.PX_SCALE,
        .white,
    );
}

fn drawAugments() void {
    const screen = utils.screenSize().scale(1 / utils.PX_SCALE);

    const w: f32 = @floatFromInt(augmentBadgeTex.width);
    const h: f32 = @floatFromInt(augmentBadgeTex.height);

    for (0.., state.activeAugments.items) |i, a| {
        const src: rl.Rectangle = .{ .x = 0, .y = 0, .width = w, .height = h };

        const dest: rl.Rectangle = .{
            .x = (screen.x - w / 2 - 200 + (@as(f32, @floatFromInt(i)) * (w / 2))) * utils.PX_SCALE,
            .y = 5 * utils.PX_SCALE,
            .width = w * utils.PX_SCALE,
            .height = h * utils.PX_SCALE,
        };

        const hovered = pointInRect(rl.getMousePosition(), .{
            .x = dest.x,
            .y = dest.y,
            .width = if (i == state.activeAugments.items.len - 1) dest.width else dest.width / 2,
            .height = dest.height,
        });

        rl.drawTexturePro(
            augmentBadgeTex,
            src,
            dest,
            .{ .x = 0, .y = 0 },
            0,
            if (hovered) .light_gray else .white,
        );

        if (hovered) {
            rl.drawText(
                a.name,
                @intFromFloat((screen.x - 200 - w / 2) * utils.PX_SCALE),
                @intFromFloat(40 * utils.PX_SCALE),
                5 * utils.PX_SCALE,
                .white,
            );

            rl.drawText(
                a.description,
                @intFromFloat((screen.x - 200 - w / 2) * utils.PX_SCALE),
                @intFromFloat(50 * utils.PX_SCALE),
                4 * utils.PX_SCALE,
                .white,
            );
        }
    }
}

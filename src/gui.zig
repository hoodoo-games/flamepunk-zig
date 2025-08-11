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
    if (state.isAugmentSelectOpen()) {
        drawAugmentSelectMenu();
    } else {
        drawConstructionMenu();
    }

    drawGoldQuota();

    // drawTextBox(rl.getFontDefault() catch unreachable, "Hello textbox", .{
    //     .x = 0,
    //     .y = 0,
    //     .width = 400,
    //     .height = 200,
    // }, 30, 1, true, .white);
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

            drawBuildingBtn(x + y * 3, pos);
        }
    }

    drawDemolishButton(origin.add(.{ .x = 3 * (32 + padding), .y = 2 * (32 + padding) }).scale(utils.PX_SCALE));
}

fn drawBuildingBtn(archetypeIdx: usize, pos: Vector2) void {
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
            @intFromFloat(pos.x),
            @intFromFloat(pos.y - 10 * utils.PX_SCALE),
            6 * utils.PX_SCALE,
            .white,
        );
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
        @intFromFloat((screen.x / 2 - 55) * utils.PX_SCALE),
        @intFromFloat((screen.y / 2 - 60) * utils.PX_SCALE),
        10 * utils.PX_SCALE,
        .orange,
    );

    const qty = @min(3, state.augmentSelectionPool.len);
    const qtyInv: f32 = @floatFromInt(3 - qty);
    for (0.., state.augmentSelectionPool) |i, a| {
        if (a) |idx| {
            drawAugmentCard(idx, origin.add(.{ .x = (@as(f32, @floatFromInt(i)) + qtyInv * 0.5) * (56 + padding), .y = 0 }));
        }
    }
}

fn drawAugmentCard(augmentIdx: usize, pos: Vector2) void {
    const src: rl.Rectangle = .{ .x = 0, .y = 0, .width = 56, .height = 78 };
    const dest: rl.Rectangle = .{
        .x = (pos.x - 56 / 2) * utils.PX_SCALE,
        .y = (pos.y - 78 / 2) * utils.PX_SCALE,
        .width = 56 * utils.PX_SCALE,
        .height = 78 * utils.PX_SCALE,
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

    if (hovered) {
        rl.drawText(
            augment.name,
            @intFromFloat(dest.x),
            @intFromFloat(dest.y + 80 * utils.PX_SCALE),
            6 * utils.PX_SCALE,
            .white,
        );
    }
}

// fn drawTextBox(
//     font: rl.Font,
//     text: [:0]const u8,
//     rec: rl.Rectangle,
//     fontSize: f32,
//     spacing: f32,
//     wordWrap: bool,
//     tint: rl.Color,
// ) void {
//     const length = rl.textLength(text); // Total length in bytes of the text, scanned by codepoints in loop

//     var textOffsetY: i32 = 0; // Offset between lines (on line break '\n')
//     var textOffsetX: f32 = 0.0; // Offset X to next character to draw

//     const scaleFactor: f32 = fontSize / @as(f32, @floatFromInt(font.baseSize)); // Character rectangle scaling factor

//     // Word/character wrapping mechanism variables
//     var measureMode: bool = wordWrap;

//     var startLine: i32 = -1; // Index where to begin drawing (where a line begins)
//     var endLine: i32 = -1; // Index where to stop drawing (where a line ends)
//     var lastk: i32 = -1; // Holds last value of the character position

//     var i: usize = 0;
//     var k: i32 = 0;
//     while (i < length) {
//         // Get next codepoint from byte string and glyph index in font
//         var codepointByteCount: i32 = 0;
//         const codepoint = rl.getCodepoint(text[i.. :0], &codepointByteCount);
//         const index: usize = @intCast(rl.getGlyphIndex(font, codepoint));

//         // NOTE: Normally we exit the decoding sequence as soon as a bad byte is found (and return 0x3f)
//         // but we need to draw all of the bad bytes using the '?' symbol moving one byte
//         if (codepoint == 0x3f) codepointByteCount = 1;
//         i += (@as(usize, @intCast(codepointByteCount - 1)));

//         var glyphWidth: f32 = 0;
//         if (codepoint != '\n') {
//             glyphWidth = if (font.glyphs[index].advanceX == 0)
//                 font.recs[index].width * scaleFactor
//             else
//                 @as(f32, @floatFromInt(font.glyphs[index].advanceX)) * scaleFactor;

//             if (i + 1 < length) glyphWidth = glyphWidth + spacing;
//         }

//         // NOTE: When wordWrap is ON we first measure how much of the text we can draw before going outside of the rec container
//         // We store this info in startLine and endLine, then we change states, draw the text between those two variables
//         // and change states again and again recursively until the end of the text (or until we get outside of the container)
//         // When wordWrap is OFF we don't need the measure state so we go to the drawing state immediately
//         // and begin drawing on the next line before we can get outside the container
//         if (measureMode) {
//             // TODO: There are multiple types of spaces in UNICODE, maybe it's a good idea to add support for more
//             // Ref: http://jkorpela.fi/chars/spaces.html
//             if ((codepoint == ' ') or (codepoint == '\t') or (codepoint == '\n')) endLine = @intCast(i);

//             if ((textOffsetX + glyphWidth) > rec.width) {
//                 endLine = if (endLine < 1) @intCast(i) else endLine;
//                 if (i == endLine) endLine -= codepointByteCount;
//                 if ((startLine + codepointByteCount) == endLine) endLine = (@as(i32, @intCast(i)) - codepointByteCount);

//                 measureMode = !measureMode;
//             } else if ((i + 1) == length) {
//                 endLine = @intCast(i);
//                 measureMode = !measureMode;
//             } else if (codepoint == '\n') measureMode = !measureMode;

//             if (!measureMode) {
//                 textOffsetX = 0;
//                 i = @intCast(startLine);
//                 glyphWidth = 0;

//                 // Save character position when we switch states
//                 const tmp = lastk;
//                 lastk = k - 1;
//                 k = tmp;
//             }
//         } else {
//             if (codepoint == '\n') {
//                 if (!wordWrap) {
//                     textOffsetY += @intFromFloat(@as(f32, @floatFromInt(font.baseSize + @divFloor(font.baseSize, 2))) * scaleFactor);
//                     textOffsetX = 0;
//                 }
//             } else {
//                 if (!wordWrap and ((textOffsetX + glyphWidth) > rec.width)) {
//                     textOffsetY += @intFromFloat(@as(f32, @floatFromInt(font.baseSize + @divFloor(font.baseSize, 2))) * scaleFactor);
//                     textOffsetX = 0;
//                 }

//                 // When text overflows rectangle height limit, just stop drawing
//                 if ((textOffsetY + font.baseSize * scaleFactor) > rec.height) break;

//                 // Draw current character glyph
//                 if ((codepoint != ' ') and (codepoint != '\t')) {
//                     rl.drawTextCodepoint(
//                         font,
//                         codepoint,
//                         (Vector2){ rec.x + textOffsetX, rec.y + textOffsetY },
//                         fontSize,
//                         tint,
//                     );
//                 }
//             }

//             if (wordWrap and (i == endLine)) {
//                 textOffsetY += (font.baseSize + font.baseSize / 2) * scaleFactor;
//                 textOffsetX = 0;
//                 startLine = endLine;
//                 endLine = -1;
//                 glyphWidth = 0;
//                 k = lastk;

//                 measureMode = !measureMode;
//             }
//         }

//         if ((textOffsetX != 0) || (codepoint != ' ')) textOffsetX += glyphWidth; // avoid leading spaces
//         k += 1;
//     }
// }

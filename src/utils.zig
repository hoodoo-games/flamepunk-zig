const rl = @import("raylib");

const Vector2 = rl.Vector2;

pub const PX_SCALE: f32 = 3;

pub fn screenSize() Vector2 {
    return .{ .x = @floatFromInt(rl.getScreenWidth()), .y = @floatFromInt(rl.getScreenHeight()) };
}

pub fn halfScreenSize() Vector2 {
    return screenSize().scale(0.5);
}

/// Gets the number of variants for an enum
pub fn enumLen(t: type) usize {
    return @typeInfo(t).@"enum".fields.len;
}

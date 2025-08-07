const std = @import("std");

/// Converts radians to degrees
pub fn degrees(rad: f32) f32 {
    return rad * 180 / std.math.pi;
}

/// Converts degrees to radians
pub fn radians(deg: f32) f32 {
    return deg * std.math.pi / 180;
}

const std = @import("std");
const hexL = std.fmt.fmtSliceHexLower;
const bPrint = std.fmt.bufPrint;

//const Pango = @This();

pub const Color = struct {
    red: u8 = 0x00,
    blue: u8 = 0x00,
    green: u8 = 0x00,
    alpha: ?u8 = null,
    buffer: [9]u8 = [_]u8{'#'} ++ [_]u8{'0'} ** 8,
    len: usize = 7,

    pub const Red = Color{
        .red = 0xff,
        .buffer = [_]u8{'#'} ++ [_]u8{'f'} ** 2 ++ [_]u8{'0'} ** 6,
    };

    pub fn red(self: *Color, r: u8) !void {
        self.red = r;
        try bPrint(self.buffer[1..3], "{}", hexL(self.red));
    }

    pub fn green(self: *Color, g: u8) !void {
        self.green = g;
        try bPrint(self.buffer[3..5], "{}", hexL(self.green));
    }

    pub fn blue(self: *Color, b: u8) !void {
        self.blue = b;
        try bPrint(self.buffer[5..7], "{}", hexL(self.blue));
    }

    pub fn format(self: Color, comptime _: []const u8, _: std.fmt.FormatOptions, out: anytype) !void {
        _ = try out.write(self.buffer[0..self.len]);
    }
};

pub fn Pango(comptime other: type) type {
    return struct {
        color: ?Color,
        other: other,

        const Self = @This();

        pub fn init(thing: other, color: ?Color) Self {
            return Self{
                .color = color,
                .other = thing,
            };
        }

        pub fn format(self: Self, comptime _: []const u8, _: std.fmt.FormatOptions, out: anytype) !void {
            if (self.color == null) return try out.print("{}", .{self.other});
            return try out.print("<span color=\"{}\">{text}</span>", .{ self.color.?, self.other });
        }
    };
}

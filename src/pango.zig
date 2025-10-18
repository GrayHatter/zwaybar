const std = @import("std");
const hexL = std.fmt.fmtSliceHexLower;
const bPrint = std.fmt.bufPrint;

//const Pango = @This();

pub const Color = struct {
    r: u8 = 0x00,
    g: u8 = 0x00,
    b: u8 = 0x00,
    a: ?u8 = null,
    buffer: [9]u8 = [_]u8{'#'} ++ [_]u8{'0'} ** 8,
    len: usize = 7,

    pub const Red = Color{
        .r = 0xff,
        .buffer = "#ff000000".*,
    };

    pub const Green = Color{
        .g = 0xff,
        .buffer = "#00ff0000".*,
    };

    pub const Blue = Color{
        .b = 0xff,
        .buffer = "#0000ff00".*,
    };

    pub const Orange = Color{
        .r = 0xff,
        .g = 0xff,
        .buffer = "#ffa50000"[0..].*,
    };

    pub fn red(self: *Color, r: u8) !void {
        self.r = r;
        try bPrint(self.buffer[1..3], "{}", hexL(self.r));
    }

    pub fn green(self: *Color, g: u8) !void {
        self.g = g;
        try bPrint(self.buffer[3..5], "{}", hexL(self.g));
    }

    pub fn blue(self: *Color, b: u8) !void {
        self.b = b;
        try bPrint(self.buffer[5..7], "{}", hexL(self.b));
    }

    pub fn format(self: Color, out: *std.Io.Writer) !void {
        _ = try out.write(self.buffer[0..self.len]);
    }
};

pub fn Pango(Other: type) type {
    return struct {
        color: ?Color,
        other: Other,

        const Self = @This();

        pub fn init(thing: Other, color: ?Color) Self {
            return Self{
                .color = color,
                .other = thing,
            };
        }

        pub fn format(self: Self, out: *std.Io.Writer) !void {
            const other = if (comptime @hasDecl(Other, "alt")) std.fmt.alt(self.other, .alt) else self.other;
            if (self.color == null) return try out.print("{f}", .{other});
            return try out.print("<span color=\"{f}\">{f}</span>", .{ self.color.?, other });
        }
    };
}

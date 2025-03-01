const std = @import("std");
const Pango = @import("pango.zig");
const toBytes = std.mem.toBytes;

const DELAY = 10;

const Battery = @This();

updated: i64 = 0,
current: usize = 0,
powered: bool = false,
wide: bool = true,
name: []const u8 = "battery",

pub fn init() !Battery {
    var bat = Battery{};
    try bat.update(1);
    return bat;
}

fn readBat(self: *Battery) !void {
    var file = try std.fs.openFileAbsolute("/sys/class/power_supply/BAT1/capacity", .{});
    defer file.close();
    var buffer: [10]u8 = undefined;
    const count = try file.read(&buffer);
    self.current = try std.fmt.parseInt(usize, buffer[0 .. count - 1], 10);
}

fn readPowerd(self: *Battery) !void {
    var file = try std.fs.openFileAbsolute("/sys/class/power_supply/ACAD/online", .{});
    defer file.close();
    var buffer: [1]u8 = undefined;
    const count = try file.read(&buffer);
    if (count == 0) return;

    switch (buffer[0]) {
        '0' => self.powered = false,
        '1' => self.powered = true,
        else => @panic("unexpected value from ACAD"),
    }
}

pub fn click(bat: *Battery, m: u8) void {
    if (m == 1) bat.wide = !bat.wide;
}

pub fn update(self: *Battery, i: i64) !void {
    if (self.updated > i) return;

    self.updated = i + DELAY;
    try self.readBat();
    try self.readPowerd();
}

pub fn ttl(self: Battery) ![]u8 {
    const ttlbuf = struct {
        var buf: [12]u8 = undefined;
    };

    const time: usize = (240 *| self.current) / 100;
    return try std.fmt.bufPrint(&ttlbuf.buf, "{}h{}m", .{ time / 60, time % 60 });
}

pub fn gfx(self: Battery) []u8 {
    const gfxl = struct {
        var b: [30]u8 = undefined;
    };
    var fill: usize = self.current;
    var index: usize = 0;
    for (gfxl.b[0..]) |*b| b.* = ' ';
    //count -|= 1;
    while (fill >= 10) : (fill -|= 10) {
        gfxl.b[index..][0..3].* = "⣿".*;
        index += 3;
    }
    if (index == 30) return gfxl.b[0..];
    gfxl.b[index..][0..3].* = switch (@as(u4, @truncate(fill % 10))) {
        0 => "   ".*,
        1 => "⡀".*,
        2 => "⡄".*,
        3 => "⡆".*,
        4...5 => "⡇".*,
        6 => "⣇".*,
        7 => "⣧".*,
        8...9 => "⣷".*,
        10...15 => unreachable,
    };
    return gfxl.b[0..];
}

test gfx {
    const zero = Battery{ .current = 0 };
    const five = Battery{ .current = 5 };

    _ = zero.gfx();
    _ = five.gfx();
}

fn color(self: Battery) ?Pango.Color {
    return switch (self.current) {
        0...15 => Pango.Color.Red,
        16...30 => Pango.Color.Orange,
        95...100 => Pango.Color.Green,
        else => null,
    };
}

pub fn format(self: Battery, comptime fmt: []const u8, _: std.fmt.FormatOptions, out: anytype) !void {
    if (std.mem.eql(u8, fmt, "pango")) {
        const p = Pango.Pango(Battery).init(self, self.color());
        return out.print("{}", .{p});
    }

    if (self.wide) {
        if (self.powered) {
            if (self.current > 97) {
                try out.print("Charged", .{});
                return;
            } else {
                try out.print("Charging", .{});
            }
        } else {
            try out.print("Battery", .{});
        }
    }

    if (self.current == 69) return out.print(" NICE!", .{});
    const time: []u8 = try self.ttl();
    const bar: []u8 = self.gfx();
    return out.print(" {}% [{s}] {s}", .{ self.current, bar, time });
}

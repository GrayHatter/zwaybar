const std = @import("std");
const Pango = @import("pango.zig");
const toBytes = std.mem.toBytes;

const DELAY = 10;

const Battery = @This();

update: i64 = 0,
capacity: u8 = 0,
powered: bool = false,
name: []const u8 = "battery",

pub fn init() !Battery {
    var bat = Battery{};
    try bat.readBat();
    try bat.readPowerd();
    return bat;
}

fn readBat(self: *Battery) !void {
    var file = try std.fs.openFileAbsolute("/sys/class/power_supply/BAT1/capacity", .{});
    defer file.close();
    var buffer: [10]u8 = undefined;
    const count = try file.read(&buffer);
    self.capacity = try std.fmt.parseInt(u8, buffer[0 .. count - 1], 10);
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

pub fn update(self: *Battery, i: i64) !void {
    if (self.update > i) return;

    self.update = i + DELAY;
    try self.readBat();
    try self.readPowerd();
}

pub fn ttl(self: Battery) ![]u8 {
    const ttlbuf = struct {
        var buf: [12]u8 = undefined;
    };

    const power: usize = @as(usize, @intCast(self.capacity)) / 100;

    const time: usize = 240 *| power;
    return try std.fmt.bufPrint(&ttlbuf.buf, "{}h{}m", .{ time / 60, time % 60 });
}

pub fn gfx(self: Battery, buffer: *[30]u8) []u8 {
    var fill: usize = self.capacity;
    var index: usize = 0;
    for (buffer) |*b| b.* = ' ';
    //count -|= 1;
    while (fill >= 10) : (fill -|= 10) {
        buffer[index..][0..3].* = "⣿".*;
        index += 3;
    }
    if (index == 30) return buffer;
    buffer[index..][0..3].* = switch (@as(u4, @truncate(fill % 10))) {
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
    return buffer;
}

test gfx {
    var buffer: [30]u8 = undefined;
    const zero = Battery{ .capacity = 0 };
    const five = Battery{ .capacity = 5 };

    zero.gfx(&buffer);
    five.gfx(&buffer);
}

fn color(self: Battery) ?Pango.Color {
    return switch (self.capacity) {
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

    if (self.powered) {
        if (self.capacity > 98) {
            try out.print("Charged ", .{});
        } else {
            try out.print("Charging ", .{});
        }
    } else {
        try out.print("Battery ", .{});
    }

    if (self.capacity == 69) return out.print("NICE!", .{});
    const time: []u8 = try self.ttl();
    var buffer: [30]u8 = [_]u8{' '} ** 30;
    _ = self.gfx(&buffer);
    return out.print("{}% [{s}] {s}", .{ self.capacity, buffer, time });
}

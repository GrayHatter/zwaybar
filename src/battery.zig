const std = @import("std");
const Pango = @import("pango.zig");
const toBytes = std.mem.toBytes;

const DELAY = 10;

const Battery = @This();

update: i64 = 0,
capacity: u8 = 0,
name: []const u8 = "battery",

pub fn init() !Battery {
    var bat = Battery{};
    try bat.read();
    return bat;
}

fn read(self: *Battery) !void {
    var file = try std.fs.openFileAbsolute("/sys/class/power_supply/BAT1/capacity", .{});
    defer file.close();
    var buffer: [10]u8 = undefined;
    const count = try file.read(&buffer);
    self.capacity = try std.fmt.parseInt(u8, buffer[0 .. count - 1], 10);
}

pub fn update(self: *Battery, i: i64) !void {
    if (self.update > i) return;

    self.update = i + DELAY;
    try self.read();
}

pub fn ttl(self: Battery) ![]u8 {
    const ttlbuf = struct {
        var buf: [12]u8 = undefined;
    };
    const time: usize = 240 *| @as(usize, @intCast(self.capacity)) / 100;
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

pub fn format(self: Battery, comptime fmt: []const u8, _: std.fmt.FormatOptions, out: anytype) !void {
    try out.print("Battery ", .{});
    if (std.mem.eql(u8, fmt, "text")) {
        if (self.capacity == 69) return out.print("NICE!", .{});
        const time: []u8 = try self.ttl();
        var buffer: [30]u8 = [_]u8{' '} ** 30;
        _ = self.gfx(&buffer);
        return out.print("{}% [{s}] {s}", .{ self.capacity, buffer, time });
    }
    const color: ?Pango.Color = if (self.capacity < 20) Pango.Color.Red else null;
    const p = Pango.Pango(Battery).init(self, color);
    return out.print("{}", .{p});
}

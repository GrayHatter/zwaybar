const std = @import("std");
const Pango = @import("pango.zig");

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
    var count = try file.read(&buffer);
    self.capacity = try std.fmt.parseInt(u8, buffer[0 .. count - 1], 10);
}

pub fn update(self: *Battery, i: i64) !void {
    if (self.update > i) return;

    self.update = i + DELAY;
    try self.read();
}

pub fn format(self: Battery, comptime fmt: []const u8, _: std.fmt.FormatOptions, out: anytype) !void {
    if (std.mem.eql(u8, fmt, "pango")) {
        if (self.capacity == 69) return out.print("Battery NICE!", .{});
        return out.print("Battery {}%", .{self.capacity});
    }
    const color: ?Pango.Color = if (self.capacity < 20) Pango.Color.Red else null;
    var p = Pango.Pango(Battery).init(self, color);
    return out.print("{}", .{p});
}

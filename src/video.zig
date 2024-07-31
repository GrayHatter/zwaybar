const std = @import("std");
const Main = @import("main.zig");
const Click = Main.Click;
const Body = Main.Body;

pub const Backlight = struct {
    name: []const u8 = "backlight",
    instance: []const u8 = "backlight_0",
    next_update: i64 = 0,
    current: u32 = 0,
    max: u32 = 0,

    pub fn init() !Backlight {
        var bl = Backlight{};
        try bl.read(true);
        return bl;
    }

    pub fn read(self: *Backlight, both: bool) !void {
        var file = try std.fs.openFileAbsolute("/sys/class/backlight/amdgpu_bl1/brightness", .{});
        defer file.close();
        var buffer: [10]u8 = undefined;
        var count = try file.read(&buffer);
        self.current = try std.fmt.parseInt(u32, buffer[0 .. count - 1], 10);
        if (!both) return;

        file.close();
        file = try std.fs.openFileAbsolute("/sys/class/backlight/amdgpu_bl1/max_brightness", .{});
        count = try file.read(&buffer);
        self.max = try std.fmt.parseInt(u32, buffer[0 .. count - 1], 10);
    }

    pub fn update(self: *Backlight, t: i64) !void {
        if (self.next_update > t) return;
        self.next_update = t + 10;
        try self.read(false);
    }

    var bl_buffer: [1024]u8 = undefined;
    pub fn json(self: Backlight) !Body {
        return Body{
            .full_text = try std.fmt.bufPrint(&bl_buffer, "{}", .{self}),
            .name = "backlight",
            .instance = "backlight_0",
        };
    }

    pub fn change(self: *Backlight, delta: isize) !void {
        var goal: [0x20]u8 = undefined;
        self.current = @min(self.max, @max(self.current +| delta, 1));
        const out = try std.fmt.bufPrint(&goal, "{}", .{self.current});
        var file = try std.fs.openFileAbsolute(
            "/sys/class/backlight/amdgpu_bl1/brightness",
            .{ .mode = .read_write },
        );
        defer file.close();
        try file.writeAll(out);
    }

    pub fn click(self: *Backlight, clk: Click) !void {
        if (clk.button == 4) {
            try self.change(if (self.current < 16) 1 else 4);
        } else if (clk.button == 5) {
            try self.change(if (self.current < 16) -1 else -4);
        } else return;
    }

    pub fn format(self: Backlight, comptime _: []const u8, _: std.fmt.FormatOptions, out: anytype) !void {
        const pct = self.current * 100 / self.max;
        return out.print("Light {}%", .{pct});
    }
};

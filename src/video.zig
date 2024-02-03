const std = @import("std");
const Click = @import("main.zig").Click;

pub const Backlight = struct {
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

    pub fn click(self: *Backlight, clk: Click) !void {
        var goal: [0x20]u8 = undefined;
        var out: []u8 = undefined;
        if (clk.button == 4) {
            self.current = @min(255, @max(self.current +| 4, 1));
            out = try std.fmt.bufPrint(&goal, "{}", .{self.current});
        } else if (clk.button == 5) {
            self.current = @min(255, @max(self.current -| 4, 1));
            out = try std.fmt.bufPrint(&goal, "{}", .{self.current});
        } else return;
        var file = try std.fs.openFileAbsolute(
            "/sys/class/backlight/amdgpu_bl1/brightness",
            .{ .mode = .read_write },
        );
        defer file.close();
        try file.writeAll(out);
    }

    pub fn format(self: Backlight, comptime _: []const u8, _: std.fmt.FormatOptions, out: anytype) !void {
        const pct = self.current * 100 / self.max;
        return out.print("BL {}%", .{pct});
    }
};

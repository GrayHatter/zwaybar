const std = @import("std");
const DateTime = @import("datetime.zig");
const Video = @import("video.zig");
const Battery = @import("battery.zig");

const Header = struct {
    version: usize = 1,
    click_events: bool = true,
    cont_signal: usize = 18,
    stop_signal: usize = 19,
};

const Body = struct {
    full_text: ?[]const u8 = null,
    short_text: ?[]u8 = null,
    color: ?[]u8 = null,
    background: ?[]u8 = null,
    border: ?[]u8 = null,
    border_top: ?usize = null,
    border_bottom: ?usize = null,
    border_left: ?usize = null,
    border_right: ?usize = null,
    min_width: ?[]u8 = null,
    @"align": ?[]u8 = null,
    // Did you know... neither name nor instance is optional if you want click
    // events? Because I didn't know, and I read the man and everything. :<
    name: []const u8,
    instance: []const u8,
    urgent: bool = false,
    separator: bool = true,
    separator_block_width: ?usize = null,
    markup: ?[]const u8 = null,
};

const Click = struct {
    name: []u8,
    instance: []u8,
    x: isize = 0,
    y: isize = 0,
    button: u8,
    event: usize = undefined,
    relative_x: isize = 0,
    relative_y: isize = 0,
    width: isize = 0,
    height: isize = 0,
};

fn dateOffset(os: i16) DateTime {
    return DateTime.nowOffset(@as(isize, os) * 60 * 60);
}

var date_buffer: [1024]u8 = undefined;
fn date() anyerror!Body {
    return Body{
        .full_text = try std.fmt.bufPrint(&date_buffer, "{}", .{dateOffset(-8)}),
        .name = "datetime",
        .instance = "datetime_0",
    };
}

var bl_buffer: [1024]u8 = undefined;
fn bl() !Body {
    return Body{
        .full_text = try std.fmt.bufPrint(&bl_buffer, "{}", .{try Video.Backlight.init()}),
        .name = "backlight",
        .instance = "backlight_0",
    };
}

var bat_buffer: [1024]u8 = undefined;
fn battery() !Body {
    var bat = try Battery.init();
    //try bat.update(std.time.timestamp());
    return Body{
        .full_text = try std.fmt.bufPrint(&bat_buffer, "{}", .{bat}),
        .markup = "pango",
        .name = "battery",
        .instance = "battery_0",
    };
}

const build_error = Body{
    .full_text = "error building this complication",
    .name = "ERROR",
    .instance = "ERROR0",
};

const Builder = *const fn () anyerror!Body;

var buffer: [0xffffff]u8 = undefined;
pub fn main() !void {
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    var a = fba.allocator();

    var stdin = std.io.getStdIn();
    _ = stdin;

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var header = Header{};
    const opt = .{ .emit_null_optional_fields = false };
    try std.json.stringify(header, opt, stdout);
    _ = try bw.write("\n[");
    try bw.flush(); // don't forget to flush!

    const builders = [_]Builder{
        bl,
        battery,
        date,
    };
    const list = try a.alloc(Body, builders.len + 1);
    defer a.free(list);

    const err_mask = std.os.POLL.ERR | std.os.POLL.NVAL | std.os.POLL.HUP;
    var buf: [2048]u8 = undefined;
    var poll_fd = [_]std.os.pollfd{.{
        .fd = 0,
        .events = std.os.POLL.IN,
        .revents = undefined,
    }};

    while (true) {
        std.time.sleep(1_000_000_000);

        _ = std.os.poll(&poll_fd, 0) catch unreachable;
        var amt: usize = 0;
        if (poll_fd[0].revents & std.os.POLL.IN != 0) {
            amt = std.os.read(0, &buf) catch unreachable;
            std.debug.print("--debug-- {any}\n", .{buf[0..amt]});
            _ = std.json.parseFromSlice(Click, a, buf[0..amt], .{}) catch |err| switch (err) {
                error.UnexpectedEndOfInput => unreachable, // Might be unreachable, but might also be valid.
                else => {
                    std.debug.print("JSON parse error ({})\n", .{err});
                    continue;
                },
            };
            //defer a.free(click);
        } else if (poll_fd[0].revents & err_mask != 0) {
            unreachable;
        } else {
            std.debug.print("--debug-- nothing\n", .{});
        }

        for (list[0..builders.len], builders) |*l, func| {
            l.* = func() catch |err| backup: {
                std.debug.print("Error {} when attempting to try {}\n", .{ err, func });
                break :backup build_error;
            };
        }

        list[builders.len] = Body{ .full_text = buf[0..amt], .name = "", .instance = "" };

        try std.json.stringify(list, opt, stdout);
        _ = try bw.write(",\n");
        try bw.flush(); // don't forget to flush!
    }
}

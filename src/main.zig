const std = @import("std");
const Allocator = std.mem.Allocator;

const DateTime = @import("datetime.zig");
const Video = @import("video.zig");
const Battery = @import("battery.zig");
const Mouse = @import("mouse.zig");

const Header = struct {
    version: usize = 1,
    click_events: bool = true,
    cont_signal: usize = 18,
    stop_signal: usize = 19,
};

pub const Body = struct {
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

pub const Click = struct {
    name: []u8,
    instance: []u8,
    button: u8,
    event: usize = 0,
    x: isize = 0,
    y: isize = 0,
    relative_x: isize = 0,
    relative_y: isize = 0,
    width: isize = 0,
    height: isize = 0,
    scale: ?isize = 0,
};

fn dateOffset(os: i16) DateTime {
    return DateTime.nowOffset(@as(isize, os) * 60 * 60);
}

var date_buffer: [1024]u8 = undefined;
fn date(_: ?Click) anyerror!Body {
    return Body{
        .full_text = try std.fmt.bufPrint(&date_buffer, "{}", .{dateOffset(-7)}),
        .name = "datetime",
        .instance = "datetime_0",
    };
}

var bl_handle: ?Video.Backlight = null;
var bl_buffer: [1024]u8 = undefined;
fn bl(click: ?Click) !Body {
    if (bl_handle) |*handle| {
        if (click) |clk| {
            var dir: ?Mouse.Button = null;
            try handle.click(clk);
            if (clk.button == 4 or clk.button == 5) {
                dir = if (clk.button == 4) .up else .down;
                return Body{
                    .full_text = try std.fmt.bufPrint(&bl_buffer, "{}", .{handle}),
                    .name = "backlight",
                    .instance = "backlight_0",
                };
            }
        }
        try handle.update(std.time.timestamp());
        return handle.json();
    } else {
        bl_handle = try Video.Backlight.init();
        return bl(click);
    }
}

var bat_buffer: [1024]u8 = undefined;
fn battery(_: ?Click) !Body {
    const bat = try Battery.init();
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

fn builder(name: []const u8, build: BldFn, click: ClkFn) anyerror!type {
    _ = click;
    _ = build;
    _ = name;
}

const Builder = struct {
    build: BldFn,
    click: ClkFn,
};

const BldFn = *const fn (?Click) anyerror!Body;
const ClkFn = *const fn (?Click) anyerror!Body;

fn toClick(a: Allocator, str: []const u8) !Click {
    var parsed = std.json.parseFromSlice(Click, a, str, .{}) catch |err| switch (err) {
        //error.UnexpectedEndOfInput => unreachable, // Might be unreachable, but might also be valid.
        else => {
            std.debug.print("JSON parse error ({})\n", .{err});
            return error.Unknown;
        },
    };
    defer parsed.deinit();
    return parsed.value;
}

test toClick {
    const a = std.testing.allocator;
    //_ = try toClick(a, "{}");
    _ = try toClick(a,
        \\
        \\{
        \\    "name": "blerg",
        \\    "instance": "blerg_0",
        \\    "button": 1,
        \\    "event": 0,
        \\    "x": 0,
        \\    "y": 0,
        \\    "relative_x": 0,
        \\    "relative_y": 0,
        \\    "width": 0,
        \\    "height": 0
        \\}
        \\
    );
}

var buffer: [0xffffff]u8 = undefined;
pub fn main() !void {
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    var a = fba.allocator();

    const stdin = std.io.getStdIn();
    _ = stdin;

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    const header = Header{};
    const opt = .{ .emit_null_optional_fields = false };
    try std.json.stringify(header, opt, stdout);
    _ = try bw.write("\n[");
    try bw.flush(); // don't forget to flush!

    const builders = [_]BldFn{
        bl,
        battery,
        date,
    };
    //var list: [builders.len + 1]Body = undefined;
    var list: []Body = try a.alloc(Body, builders.len + 1);

    const err_mask = std.posix.POLL.ERR | std.posix.POLL.NVAL | std.posix.POLL.HUP;
    var buf: [0x5000]u8 = undefined;
    var str: []const u8 = buf[0..0];
    var poll_fd = [_]std.posix.pollfd{.{
        .fd = 0,
        .events = std.posix.POLL.IN,
        .revents = undefined,
    }};

    while (true) {
        var miss: usize = 1;
        list.len = builders.len;

        for (0..100) |_| {
            if (std.posix.poll(&poll_fd, 10) catch unreachable > 0) {
                miss = 0;
                break;
            }
        } else {
            miss = @min(20, miss +| 1);
        }
        var click: ?Click = null;
        const parsed: ?std.json.Parsed(Click) = null;
        if (poll_fd[0].revents & std.posix.POLL.IN != 0) {
            const amt = std.posix.read(0, &buf) catch unreachable;
            std.debug.assert(amt <= buf.len);
            const start: usize = if (amt > 1 and buf[0] == ',') 1 else 0;
            str = buf[start..amt];
            if (std.mem.indexOf(u8, str, "\n")) |i| {
                str = buf[start .. i + 1];
            }

            std.debug.print("--debug-- {any}\n", .{buf[0..amt]});
            click = toClick(a, str) catch |err| switch (err) {
                else => brk: {
                    const ending = try std.fmt.bufPrint(buf[amt..], " && {}", .{err});
                    str = &buf;
                    str.len = amt + ending.len;
                    list.len = builders.len + 1;
                    break :brk null;
                },
            };
        } else if (poll_fd[0].revents & err_mask != 0) {
            unreachable;
        } else {
            std.debug.print("--debug-- nothing\n", .{});
        }

        if (parsed) |prs| {
            click = prs.value;
        }

        for (list[0..builders.len], builders) |*l, func| {
            l.* = func(click) catch |err| backup: {
                std.debug.print("Error {} when attempting to try {}\n", .{ err, func });
                break :backup build_error;
            };
        }

        if (list.len > builders.len) {
            // json error maybe? print debugging
            list[builders.len] = Body{ .full_text = str, .name = "debug", .instance = "debug" };
        }

        try std.json.stringify(list, opt, stdout);
        _ = try bw.write(",\n");
        try bw.flush(); // don't forget to flush!
    }
}

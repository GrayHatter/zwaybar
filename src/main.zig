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
    name: ?[]u8 = null,
    instance: ?[]u8 = null,
    urgent: bool = false,
    separator: bool = true,
    separator_block_width: ?usize = null,
    markup: ?[]const u8 = null,
};

fn dateOffset(os: i16) DateTime {
    return DateTime.nowOffset(@as(isize, os) * 60 * 60);
}

var date_buffer: [1024]u8 = undefined;
fn date() anyerror!Body {
    return Body{
        .full_text = try std.fmt.bufPrint(&date_buffer, "{}", .{dateOffset(-8)}),
    };
}

var bl_buffer: [1024]u8 = undefined;
fn bl() !Body {
    return Body{
        .full_text = try std.fmt.bufPrint(&bl_buffer, "{}", .{try Video.Backlight.init()}),
    };
}

var bat_buffer: [1024]u8 = undefined;
fn battery() !Body {
    var bat = try Battery.init();
    //try bat.update(std.time.timestamp());
    return Body{
        .full_text = try std.fmt.bufPrint(&bat_buffer, "{}", .{bat}),
        .markup = "pango",
    };
}

const build_error = Body{
    .full_text = "error building this complication",
};

const Builder = *const fn () anyerror!Body;

var buffer: [0xffffff]u8 = undefined;
pub fn main() !void {
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    var a = fba.allocator();

    var stdin = std.io.getStdIn().reader();
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
    const list = try a.alloc(Body, builders.len);
    defer a.free(list);

    while (true) {
        std.time.sleep(1_000_000_000);

        var some_in: [1024]u8 = undefined;
        _ = some_in;
        //const count = try stdin.read(&some_in);
        //std.debug.print("some in '{s}'\n", .{some_in[0..count]});

        for (list, builders) |*l, func| {
            l.* = func() catch |err| backup: {
                std.debug.print("Error {} when attempting to try {}\n", .{ err, func });
                break :backup build_error;
            };
        }

        try std.json.stringify(list, opt, stdout);
        _ = try bw.write(",\n");
        try bw.flush(); // don't forget to flush!
    }
}

const std = @import("std");

const Header = struct {
    version: usize = 1,
    click_events: bool = true,
    cont_signal: usize = 18,
    stop_signal: usize = 19,
};

const Body = struct {
    full_text: ?[]u8 = null,
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

var date_buffer: [1024]u8 = undefined;
fn date() Body {
    return Body{
        .full_text = std.fmt.bufPrint(&date_buffer, "{}", .{std.time.timestamp()}) catch unreachable,
    };
}

fn build(a: std.mem.Allocator) ![]Body {
    const list = try a.alloc(Body, 1);
    for (list) |*l|
        l.* = Body{};
    list[0] = date();
    return list;
}

pub fn main() !void {
    var buffer: [0xffff]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    var a = fba.allocator();
    var header = Header{};

    const opt = .{ .emit_null_optional_fields = false };

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try std.json.stringify(header, opt, stdout);

    _ = try bw.write("\n[");

    while (true) {
        var list = try build(a);
        defer a.free(list);

        try std.json.stringify(list, opt, stdout);
        _ = try bw.write(",\n");
        try bw.flush(); // don't forget to flush!
        std.time.sleep(1_000_000_000);
    }
}

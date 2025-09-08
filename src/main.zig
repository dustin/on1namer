const std = @import("std");
const on1 = @import("on1namer_lib");

fn rename1(alloc: std.mem.Allocator, _: *std.fs.Dir, base: []const u8, year: u16) !void {
    const newName = try std.fmt.allocPrint(alloc, "{d}/{s}", .{ year, base });
    defer alloc.free(newName);
    std.debug.print("    {s} -> {s}\n", .{ base, newName });
    // try dir.rename(base, newName);
}

fn rename(alloc: std.mem.Allocator, dir: *std.fs.Dir, on1file: []const u8, fi: *on1.FileInfo) !void {
    const newName = try std.fmt.allocPrint(alloc, "{d}", .{fi.year});
    defer alloc.free(newName);
    dir.makeDir(newName) catch {};

    try rename1(alloc, dir, on1file, fi.year);
    for (fi.files) |file| {
        try rename1(alloc, dir, file, fi.year);
    }
}

fn FormatSlice(comptime fmt: []const u8) type {
    return struct {
        things: []const []const u8 = undefined,

        pub fn format(self: @This(), w: *std.Io.Writer) std.Io.Writer.Error!void {
            try w.writeAll("[");
            for (self.things, 0..) |s, i| {
                if (i > 0) try w.writeAll(", ");
                try w.print(fmt, .{s});
            }
            try w.writeAll("]");
        }
    };
}

fn formatSlice(comptime fmt: []const u8, things: anytype) FormatSlice(fmt) {
    return FormatSlice(fmt){ .things = things };
}

fn findFiles(alloc: std.mem.Allocator, dir: *std.fs.Dir) !void {
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (!std.mem.eql(u8, std.fs.path.extension(entry.name), ".on1")) {
            continue;
        }

        std.debug.print("opening file: {s}\n", .{entry.name});

        var j = on1.parseFile(alloc, dir, entry.name);
        if (j) |*e| {
            defer e.deinit(alloc);
            try rename(alloc, dir, entry.name, e);
            // std.debug.print("{s}", .{entry.name});
            std.debug.print("Parsed file: {s}: {f} ({d})\n", .{ entry.name, formatSlice("{s}", e.files), e.year });
        } else |err| {
            std.debug.print("Failed to parse file: {s}: {}\n", .{ entry.name, err });
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }
    const allocator = gpa.allocator();

    var args = std.process.argsAlloc(allocator) catch return;
    defer std.process.argsFree(allocator, args);

    for (args[1..]) |arg| {
        std.debug.print("Opening dir {s}\n", .{arg});
        var dir = try std.fs.openDirAbsolute(arg, .{ .iterate = true, .access_sub_paths = true });
        defer dir.close();

        try findFiles(allocator, &dir);
    }
}

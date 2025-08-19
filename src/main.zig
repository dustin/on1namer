//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

pub fn findFiles(alloc: std.mem.Allocator, dir: *std.fs.Dir) !void {
    var walker = try dir.walk(alloc);
    defer walker.deinit();

    while (try walker.next()) |entry| {
        if (entry.kind != .file) {
            continue;
        }
        // src/main.zig:13:28: error: no field or member function named 'ends_with' in '[:0]const u8'

        if (!std.mem.eql(u8, std.fs.path.extension(entry.path), ".on1")) {
            continue;
        }

        std.debug.print("opening file: {s}\n", .{entry.path});

        var j = on1.parseFile(alloc, dir, entry.path);
        if (j) |*e| {
            defer e.deinit(alloc);
            std.debug.print("Parsed file: {s}: {s} ({d})\n", .{ entry.path, e.files, e.year });
        } else |err| {
            std.debug.print("Failed to parse file: {s}: {}\n", .{ entry.path, err });
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

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const on1 = @import("on1namer_lib");

//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

pub const FileInfo = struct {
    files: []const []const u8,
    year: u16,

    pub fn deinit(self: *FileInfo, alloc: std.mem.Allocator) void {
        for (self.files) |file| {
            alloc.free(file);
        }
        alloc.free(self.files);
        self.files = undefined;
        self.year = 0;
    }
};

const maxYear = 10000;

pub fn parseFile(alloc: std.mem.Allocator, dir: *std.fs.Dir, path: []const u8) !FileInfo {
    var arena = try alloc.create(std.heap.ArenaAllocator);
    defer alloc.destroy(arena);
    arena.* = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const al = arena.allocator();

    const file = try dir.openFile(path, .{});
    defer file.close();
    var buf: [1024]u8 = undefined;
    var reader = file.reader(&buf);
    const ri = &reader.interface;
    var jr = std.json.Scanner.Reader.init(al, ri);
    const val = try std.json.parseFromTokenSourceLeaky(std.json.Value, al, &jr, .{});

    const photos = val.object.get("photos").?.object;
    if (photos.count() == 0) {
        return error.NoEntry;
    }

    var year: u16 = maxYear;
    var names = try std.ArrayList([]const u8).initCapacity(alloc, 2);
    errdefer names.deinit(alloc);
    var seen = std.StringHashMap(void).init(al); // arena will kill this

    var it = photos.iterator();
    while (it.next()) |entry| {
        const o = entry.value_ptr.*.object;
        const name = o.get("name").?.string;
        if ((try seen.getOrPut(name)).found_existing) continue;

        const dupName = try alloc.dupe(u8, name);
        errdefer alloc.free(dupName);
        try names.append(alloc, dupName);
        if (o.get("metadata").?.object.get("CaptureDate")) |captured| {
            const y = try std.fmt.parseInt(u16, captured.string[captured.string.len - 4 ..], 10);
            if (y < year) {
                year = y;
            }
        }
    }

    if (year < maxYear and names.items.len > 0) {
        return FileInfo{
            .files = try names.toOwnedSlice(alloc),
            .year = year,
        };
    } else {
        for (names.items) |name| {
            alloc.free(name);
        }
        return error.NoInfo;
    }

    return error.NoEntry;
}

test "parse typical" {
    var dir = std.fs.cwd();

    var someVal = try parseFile(std.testing.allocator, &dir, "samples/IMG_0006.on1");
    defer someVal.deinit(std.testing.allocator);
    try std.testing.expectEqual(1, someVal.files.len);
    try std.testing.expectEqualStrings("IMG_0006.dng", someVal.files[0]);
    try std.testing.expectEqual(2025, someVal.year);
}

test "parse nodate" {
    var dir = std.fs.cwd();
    try std.testing.expectError(error.NoInfo, parseFile(std.testing.allocator, &dir, "samples/abyss.on1"));
}

test "parse multi-file" {
    var dir = std.fs.cwd();
    var someVal = try parseFile(std.testing.allocator, &dir, "samples/IMG_1648.on1");
    defer someVal.deinit(std.testing.allocator);
    try std.testing.expectEqual(2, someVal.files.len);
    try std.testing.expectEqualStrings("IMG_1648.CR3", someVal.files[0]);
    try std.testing.expectEqualStrings("IMG_1648.DNG", someVal.files[1]);
    try std.testing.expectEqual(2022, someVal.year);
}

test "parse with duplicate files" {
    var dir = std.fs.cwd();
    var someVal = try parseFile(std.testing.allocator, &dir, "samples/IMG_2173.on1");
    defer someVal.deinit(std.testing.allocator);
    try std.testing.expectEqual(1, someVal.files.len);
    try std.testing.expectEqualStrings("IMG_2173.CR3", someVal.files[0]);
    try std.testing.expectEqual(2022, someVal.year);
}

//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

const FileInfo = struct {
    name: []const u8,
    year: u16,

    pub fn deinit(self: *FileInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        self.name = "";
        self.year = 0;
    }
};

pub fn parseFile(alloc: std.mem.Allocator, path: []const u8) !FileInfo {
    var arena = try alloc.create(std.heap.ArenaAllocator);
    defer alloc.destroy(arena);
    arena.* = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const al = arena.allocator();

    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const reader = file.reader();
    var jr = std.json.reader(al, reader);
    const val = try std.json.parseFromTokenSourceLeaky(std.json.Value, al, &jr, .{});

    const photos = val.object.get("photos").?.object;
    if (photos.count() > 1) {
        return error.TooManyPhotos;
    }

    var it = photos.iterator();
    if (it.next()) |entry| {
        const o = entry.value_ptr.*.object;
        const name = o.get("name").?.string;
        const captured = o.get("metadata").?.object.get("CaptureDate").?.string;
        return FileInfo{
            .name = try alloc.dupe(u8, name),
            .year = try std.fmt.parseInt(u16, captured[captured.len - 4 ..], 10),
        };
    }

    return error.NoEntry;
}

test "parse sample" {
    var someVal = try parseFile(std.testing.allocator, "samples/IMG_0006.on1");
    defer someVal.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("IMG_0006.dng", someVal.name);
    try std.testing.expectEqual(2025, someVal.year);
}

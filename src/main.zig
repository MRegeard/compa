const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const Args = std.process.Args;

const compa = @import("compa");

const Init = struct {
    pub const Options = struct {
        force: bool = false
    };
    pub fn run(gpa: Allocator, opts: Options) !void {
        _ = gpa;
        std.debug.print("Init: force = {any}\n", .{opts.force});
    }
};

const Fetch = struct {
    pub const Options = struct {
        url: []const u8 = ""
    };
    pub fn run(io: Io, opts: Options) !void {
        _ = io;
        std.debug.print("Fetch: url = {s}\n", .{opts.url});
    }
};

const Version = struct {
    pub const Options = struct {};
    pub fn run() !void {
        std.debug.print("Version\n", .{});
    }
};

const Context = struct {
    gpa: Allocator,
    io: Io,
};

const commands: [3]compa.Command = .{
    .{ .name = "init", .handler = Init },
    .{ .name = "fetch", .handler = Fetch },
    .{ .name = "version", .handler = Version },
};


pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;
    const args = init.minimal.args;

    const App = compa.Compa(Context, &commands);
    const parsed = try App.parse(allocator, args);
    try App.run(parsed, .{ .gpa = allocator, .io = io });
}

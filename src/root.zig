const std = @import("std");
const Attributes = std.builtin.Type.UnionField.Attributes;
const Args = std.process.Args;
const Io = std.Io;
const Allocator = std.mem.Allocator;

pub const Command = struct {
    name: []const u8,
    handler: type,
};

pub fn Compa(comptime Context: type, comptime commands: []const Command) type {
    const cmds_len: usize = commands.len;
    return struct {
        pub const Tag = blk: {
            const TagType: type = @Int(.unsigned, commands.len);
            var names: [cmds_len][]const u8 = undefined;
            var values: [cmds_len]TagType = undefined;
            for (commands, 0..) |cmd, i| {
                names[i] = cmd.name;
                values[i] = i;
            }
            const n = names;
            const v = values;
            break :blk @Enum(TagType, .exhaustive, &n, &v);
        };

        pub const Parsed = blk: {
            var field_names: [cmds_len][]const u8 = undefined;
            var field_types: [cmds_len]type = undefined;
            var field_attrs: [cmds_len]Attributes = undefined;
            for (commands, 0..) |cmd, i| {
                field_names[i] = cmd.name;
                field_types[i] = Payload(cmd);
                field_attrs[i] = .{};
            }
            const n = field_names;
            const t = field_types;
            const a = field_attrs;
            break :blk @Union(.auto, Tag, &n, &t, &a);
        };

        fn Payload(comptime command: Command) type {
            return struct {
                // parseOption here
                options: command.handler.Options,
                pub fn run(self: @This()) anyerror!void {
                    _ = self;
                    return command.handler.run();
                }
            };
        }

        pub fn parse(allocator: Allocator, args: Args) !Parsed {
            var arg_it = try args.iterateAllocator(allocator);
            defer arg_it.deinit();
            _ = arg_it.skip();
            if (arg_it.next()) |arg| {
                const tag = std.meta.stringToEnum(Tag, arg) orelse return error.UnknownCommand;
                return switch (tag) {
                    inline else => |t| blk: {
                        const cmd = commands[@intFromEnum(t)];
                        var options: cmd.handler.Options = .{};
                        _ = &options;
                        break :blk @unionInit(Parsed, @tagName(t), .{ .options = options });
                    },
                };
            }
            return error.MissingCommand;
        }

        pub fn run(parsed: Parsed, ctx: Context) !void {
            switch (parsed) {
                inline else => |payload, tag| {
                    const handler = commands[@intFromEnum(tag)].handler;
                    try call(handler, ctx, payload.options);
                },
            }
        }

        fn call(comptime handler: type, ctx: Context, opts: handler.Options) !void {
            const F = @TypeOf(handler.run);
            var args: std.meta.ArgsTuple(F) = undefined;
            inline for (@typeInfo(F).@"fn".params, 0..) |param, i| {
                const T = param.type orelse @compileError("Generic parameters not supported in run.");
                args[i] = if (T == handler.Options) opts else fromContext(T, ctx);
            }
            return @call(.auto, handler.run, args);
        }

        fn fromContext(comptime T: type, ctx: Context) T {
            const fields = @typeInfo(Context).@"struct".fields;
            comptime var found: ?[]const u8 = null;
            inline for (fields) |f| {
                if (f.type == T) {
                    if (found != null) @compileError("Ambiguous: several context fields of type " ++ @typeName(T));
                    found = f.name;
                }
            }
            const name = found orelse @compileError("No context field of type " ++ @typeName(T) ++ " to pass to run.");
            return @field(ctx, name);
        }
    };
}

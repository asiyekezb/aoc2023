const std = @import("std");
const bufIter = @import("./buf-iter.zig");
const util = @import("./util.zig");
const gridMod = @import("./grid.zig");
const dirMod = @import("./dir.zig");
const queue = @import("./queue.zig");

const Coord = dirMod.Coord;

const assert = std.debug.assert;

// alternative with arena allocator:
// pub fn main(in_allocator: std.mem.Allocator, args: []const [:0]u8) anyerror!void {
//     var arena = std.heap.ArenaAllocator.init(in_allocator);
//     defer arena.deinit();
//     var allocator = arena.allocator();

const State = struct {
    pos: Coord,
    prev: ?*State,
};

fn hasVisited(state: *State, pos: Coord) bool {
    if (state.pos.x == pos.x and state.pos.y == pos.y) {
        return true;
    }
    if (state.prev) |prev| {
        return hasVisited(prev, pos);
    }
    return false;
}

fn nextStates(gr: gridMod.GridResult, state: *State, nextBuf: []*State) ![]*State {
    const pos = state.pos;
    const grid = gr.grid;
    const cur = grid.get(pos);
    _ = cur;
    const allocator = grid.allocator;
    var i: usize = 0;

    for (dirMod.DIRS) |d| {
        const np = pos.move(d);
        const next = grid.get(np) orelse '#';
        if (next == '#') {
            continue; // blocked
        }
        // if ((cur == '>' and d != .right) or
        //     (cur == '<' and d != .left) or
        //     (cur == '^' and d != .up) or
        //     (cur == 'v' and d != .down))
        // {
        //     continue;
        // }
        if (hasVisited(state, np)) {
            continue;
        }
        var statePtr = try allocator.create(State);
        statePtr.* = State{
            .pos = np,
            .prev = state,
        };
        nextBuf[i] = statePtr;
        i += 1;
    }
    return nextBuf[0..i];
}

fn pathLen(state: *State) usize {
    if (state.prev) |prev| {
        return 1 + pathLen(prev);
    }
    return 0;
}

fn find(allocator: std.mem.Allocator, start: Coord, end: Coord, gr: gridMod.GridResult) !void {
    var fringe = queue.Queue(*State).init(allocator);
    var initState = State{ .pos = start, .prev = null };
    try fringe.enqueue(&initState);

    var nextsBuf: [4]*State = undefined;

    while (fringe.dequeue()) |statePtr| {
        var nexts = try nextStates(gr, statePtr, &nextsBuf);
        for (nexts) |next| {
            if (next.pos.x == end.x and next.pos.y == end.y) {
                std.debug.print("Reached finish in {d} steps.\n", .{pathLen(next)});
            } else {
                try fringe.enqueue(next);
            }
        }
    }
}

fn countChoices(gr: gridMod.GridResult) !std.ArrayList(Coord) {
    const grid = gr.grid;
    var num: usize = 0;
    var numChoices: usize = 0;
    var numForced: usize = 0;
    var numJunctions: usize = 0;
    var nodes = std.ArrayList(Coord).init(grid.allocator);
    for (1..gr.maxX) |x| {
        for (1..gr.maxY) |y| {
            var numNexts: usize = 0;
            const p = Coord{ .x = @intCast(x), .y = @intCast(y) };
            if (grid.get(p) == '#') {
                continue;
            }
            num += 1;
            for (dirMod.DIRS) |d| {
                const np = p.move(d);
                if (grid.get(np) != '#') {
                    numNexts += 1;
                }
            }
            if (numNexts == 0) {
                std.debug.print("isolated! {any}\n", .{p});
            } else if (numNexts == 1) {
                std.debug.print("dead end! {any}\n", .{p});
            } else if (numNexts == 2) {
                // std.debug.print("forced: {any}", .{p});
                numForced += 1;
            } else if (numNexts == 3) {
                numChoices += 1;
            } else {
                numJunctions += 1;
            }
            if (numNexts >= 3) {
                try nodes.append(p);
            }
        }
    }

    std.debug.print("num squares: {d}\n", .{num});
    std.debug.print("forced: {d}, choice: {d}, junction: {d}\n", .{ numForced, numChoices, numJunctions });

    return nodes;
}

pub fn main(in_allocator: std.mem.Allocator, args: []const [:0]u8) anyerror!void {
    var arena = std.heap.ArenaAllocator.init(in_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const filename = args[0];
    var gr = try gridMod.readGrid(allocator, filename, 'x');
    var grid = gr.grid;
    var maxX = gr.maxX;
    var maxY = gr.maxY;
    defer grid.deinit();

    const start = Coord{ .x = 1, .y = 0 };
    const end = Coord{ .x = @intCast(maxX - 1), .y = @intCast(maxY) };
    // std.debug.print("1,0: {?c}\n", .{grid.get(start)});
    // std.debug.print("1,0: {?c}\n", .{grid.get(start)});

    assert(grid.get(start) == '.');
    assert(grid.get(end) == '.');

    var nodes = try countChoices(gr);
    try nodes.append(start);
    try nodes.append(end);
    defer nodes.deinit();

    std.debug.print("# nodes: {d}\n", .{nodes.items.len});

    // try find(allocator, start, end, gr);

    // std.debug.print("part 1: {d}\n", .{sum1});
    // std.debug.print("part 2: {d}\n", .{sum2});
}

const expectEqualDeep = std.testing.expectEqualDeep;
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;

test "sample test" {
    try expectEqualDeep(true, true);
}

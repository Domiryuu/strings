const std = @import("std");

pub fn main() !void {

    //allocator for command line arguments
    const alloc = std.heap.page_allocator;
    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();

    //handel command line arguments
    //remove first which is invoked program
    _ = args.next();
    while (args.next()) |arg| {
        try stringify(arg);
    }
}

fn stringify(filename: []const u8) !void {

    //setup buffered writer
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    errdefer std.debug.print("\nError: parsing file.\n", .{});

    var string_representation: [4]u8 = undefined;
    var byte_length: u3 = undefined;
    try stdout.print("File: {s}\n", .{filename});

    var file = try std.fs.cwd().openFile(filename, .{});
    const file_size = (try file.stat()).size;
    const allocator = std.heap.page_allocator;
    const file_buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(file_buffer);
    _ = try file.readAll(file_buffer);
    var index: usize = 0;
    scan: while (index < file_buffer.len) {
        byte_length = 0;
        if (file_buffer[index] > 126) {
            //ok lets check if its even possably UTF-8
            if (file_buffer[index] > 0b10000000) {
                if (file_buffer[index] & 0b11100000 == 0b11100000) { //4byte
                    //out of bounds?
                    if (file_buffer[index] > 0b11110100) {
                        index += 1;
                        continue :scan;
                    }
                    byte_length = 4;
                    string_representation[0] = file_buffer[index];
                    for (1..byte_length - 1) |b| {
                        //out of bounds?
                        if (file_buffer[index + 1] > 0b10001111) {
                            index += 1;
                            continue :scan;
                        }
                        if (file_buffer[index + b] & 0b10000000 == 0b10000000) {
                            string_representation[b] = file_buffer[index + b];
                        } else {
                            //broken or invalid utf-8 character
                            index += 1;
                            continue :scan;
                        }
                        try stdout.print("{s}", .{string_representation[0..byte_length]});
                        index += byte_length - 1;
                    }
                } else {
                    if (file_buffer[index] & 0b11000000 == 0b11000000) { //3byte
                        byte_length = 3;
                        string_representation[0] = file_buffer[index];
                        for (1..byte_length - 1) |b| {
                            if (file_buffer[index + b] & 0b10000000 == 0b10000000) {
                                string_representation[b] = file_buffer[index + b];
                            } else {
                                //broken or invalid utf-8 character
                                index += 1;
                                continue :scan;
                            }
                            try stdout.print("{s}", .{string_representation[0..byte_length]});
                            index += byte_length - 1;
                        } else { //2byte
                            if (file_buffer[index] & 0b10000000 == 0b10000000) {
                                byte_length = 2;
                                string_representation[0] = file_buffer[index];
                                for (1..byte_length - 1) |b| {
                                    if (file_buffer[index + b] & 0b10000000 == 0b10000000) {
                                        string_representation[b] = file_buffer[index + b];
                                    } else {
                                        //broken or invalid utf-8 character
                                        index += 1;
                                        continue :scan;
                                    }
                                    try stdout.print("{s}", .{string_representation[0..byte_length]});
                                    index += byte_length - 1;
                                }
                            } else {
                                //invalid utf-8
                                index += 1;
                                continue :scan;
                            }
                        }
                    }
                } //not utf-8 or ascii, insert new line. go to next u8 and continue checking file.
                try stdout.print("\n", .{});
                index += 1;
                continue :scan;
            }
        } else {
            //ASCII printable character
            switch (file_buffer[index]) {
                '\n' => {
                    try stdout.print("\n", .{});
                },
                '\t' => {
                    try stdout.print("\t", .{});
                },

                else => {
                    if (file_buffer[index] > 31) {
                        try stdout.print("{c}", .{file_buffer[index]});
                        index += 1;
                        continue;
                    } else {
                        // try stdout.print("\n", .{});
                    }
                },
            }
        }
        index += 1;
    }
    try stdout.print("\n", .{});
    try bw.flush();
}

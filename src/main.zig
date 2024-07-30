const std = @import("std");
const assert = std.debug.assert;
const Vm = @import("vm.zig");
const Instruction = Vm.Instruction;

pub const Cpu = Vm.Cpu(.{
    .stack_size = 256,
    .pc_register = 0,
    .sp_register = 1,
});

pub var Memory: [4096]u64 = undefined;

fn set_memory(cpu: *Cpu.Self, addr: u64, data: u64) !void {
    _ = cpu;
    if (Memory.len <= addr) {
        return Vm.MemoryIOError.MemoryOutOfBounds;
    }
    Memory[addr] = data;
}

fn get_memory(cpu: *Cpu.Self, addr: usize) !usize {
    _ = cpu;
    if (Memory.len <= addr) {
        return Vm.MemoryIOError.MemoryOutOfBounds;
    }
    return Memory[addr];
}

// get char behavior (read)
pub fn read() !u8 {
    const in = std.io.getStdIn();
    const ch = in.reader().readByte() catch |e| {
        std.debug.print("Error: {}\n", .{e});
        return Vm.IoFnError.IoReadAccessError;
    };

    return ch;
}

pub fn write(data: u8) !void {
    const out = std.io.getStdOut();
    out.writer().writeByte(data) catch |e| {
        std.debug.print("Error: {}\n", .{e});
        return Vm.IoFnError.IoWriteAccessError;
    };
}

pub fn io_fn(cpu: Cpu.Self, fd: usize) !Vm.IoFuncs {
    _ = cpu;
    switch (fd) {
        0 => return Vm.IoFuncs.new_read(&read),
        1 => return Vm.IoFuncs.new_write(&write),
        else => return Vm.IoFnError.IoFunctionDoesntExist,
    }
}

pub fn main() !void {
    var cpu = Cpu{};
    cpu.flags |= @intFromEnum(Vm.Flags.Running);
    cpu.set_memory = &set_memory;
    cpu.get_memory = &get_memory;
    cpu.get_io = &io_fn;

    Memory[0] = Instruction.Nop.inst2num();

    // hand made: for loop
    // int x(r4) = 1;
    // for (int y(reg 3) = 0; y < 10; y++) {
    //     x += y;
    // }
    // thats the goal of the program bellow

    const offset = write_loop(
        u64,
        &Memory,
        1,
        3, // y (r3)
        10, // 10
        4, // x (r4)
        1, // y++
        &l1,
    );

    Memory[offset] = Instruction.Halt.inst2num();

    cpu.run();

    assert(cpu.registers[5] == 45); // x (from outside the for loop)
    assert(cpu.registers[3] == 10); // i (from the for loop)
    assert(cpu.registers[4] == 10); // 10 (from the for loop)

    // clear the memory
    Memory = undefined;

    // reset the pc
    cpu.registers[Cpu.Pc] = 0;
    cpu.flags |= @intFromEnum(Vm.Flags.Running);

    // Clear r3
    Memory[0] = Vm.Inst.new(
        Instruction.Movi,
        3, // r3
        0, // imm
        0, // N/A
    ).to_instruction();

    // Set r3 to the desired fd (out for printing)
    Memory[1] = Vm.Inst.new(
        Instruction.Movi,
        3, // r3
        1, // imm
        0, // N/A
    ).to_instruction();

    // Load the address of the string "Hello, World!" into r4
    Memory[2] = Vm.Inst.new(
        Instruction.Movi,
        4, // r4
        5, // addr
        0, // N/A
    ).to_instruction();

    // syscall to print the string
    Memory[3] = Vm.Inst.new(
        Instruction.Syscall,
        0, // N/A
        0, // N/A
        0, // N/A
    ).to_instruction();

    Memory[4] = Instruction.Halt.inst2num(); // Halt (/* no args */)

    // load the string "\tHello, World!\n" into memory
    write_string(u64, &Memory, 5, "\tHello, World!\n");

    cpu.run();
}

fn write_string(comptime T: type, mem: []T, offset: usize, data: []const u8) void {
    var i: usize = 0;
    for (data) |c| {
        mem[offset + i] = @intCast(c);
        i += 1;
    }
    mem[offset + i] = 0;
}

fn l1(mem: []u64, offset: usize, iter_reg: u16) usize {
    // add the iter_reg to r4
    mem[offset] = Vm.Inst.new(
        Instruction.Add,
        5, // r0
        @intCast(iter_reg), // r1
        0, // N/A
    ).to_instruction();

    return offset + 1;
}

pub inline fn write_loop(
    comptime T: type,
    mem: []T,
    offset: usize,
    iter_reg: u16,
    iter_max: u16,
    iter_max_reg: u16,
    iter_inc: u16,
    inside_loop: *const fn (mem: []T, offset: usize, iter_reg: u16) usize,
) usize {
    // set the iter_reg to 0
    mem[offset] = Vm.Inst.new(
        Instruction.Movi,
        iter_reg, // r0
        0, // imm
        0, // N/A
    ).to_instruction();

    // set the iter_max_reg to `iter_max`
    mem[offset + 1] = Vm.Inst.new(
        Instruction.Movi,
        iter_max_reg, // r0
        iter_max, // imm
        0, // N/A
    ).to_instruction();

    // loop start

    const ioffset = inside_loop(mem, offset + 2, iter_reg);

    // loop end

    mem[ioffset] = Vm.Inst.new(
        Instruction.Addi,
        iter_reg, // r0
        iter_inc, // imm
        0, // N/A
    ).to_instruction();

    mem[ioffset + 1] = Vm.Inst.new(
        Instruction.Blt,
        iter_reg, // r0
        iter_max_reg, // r1
        @intCast(offset + 2), // lt addr
    ).to_instruction();

    return ioffset + 2;
}

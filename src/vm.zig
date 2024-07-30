const std = @import("std");

/// An enum for the cpu flags
pub const Flags = enum(u16) {
    Running = (1 << 0),
    Carry = (1 << 1),
    Zero = (1 << 2),
    Negative = (1 << 3),
    Overflow = (1 << 4),
    Interrupt = (1 << 5),
};

pub const Config = struct {
    // The size of the cpu stack
    stack_size: ?usize = null,
    // The register index that holds the program counter
    pc_register: ?usize = null,
    // The register index that holds the stack pointer
    sp_register: ?usize = null,
};

pub const IoFnError = error{
    IoReadError,
    IoReadAccessError,
    IoWriteError,
    IoWriteAccessError,
    IoFunctionDoesntExist,
};

/// A union that represents a function that can read from and write to some "memory"
pub const IoFuncs = union(enum) {
    Read: *const fn () IoFnError!u8, // basically: getchar()
    Write: *const fn (u8) IoFnError!void, // basically: putchar()

    pub fn new_read(r_fn: *const fn () IoFnError!u8) IoFuncs {
        return .{ .Read = r_fn };
    }

    pub fn new_write(w_fn: *const fn (u8) IoFnError!void) IoFuncs {
        return .{ .Write = w_fn };
    }
};

/// A virtual Cpu (a VM) that can run a program (an array of Instruction)
pub fn Cpu(comptime config: Config) type {
    return struct {
        pub const Self = @This();

        pub const stack_size = if (config.stack_size == null) {
            @compileError("stack_size must be provided");
        } else if (config.stack_size.? == 0) {
            @compileError("stack_size must be greater than 0");
        } else if (config.stack_size) |size| size;

        /// The program counter, defaults to reg 0
        pub const Pc: usize = if (config.pc_register) |pc| pc else 0;
        /// The Stack Pointer, defaults to reg 1
        pub const Sp: usize = if (config.sp_register) |sp| sp else 1;

        /// Flags that control the behavior of the CPU
        flags: u16 = 0,

        /// the general purpose registers
        registers: [16]usize = undefined,

        /// The stack
        stack: [stack_size]usize = undefined,

        /// a function ptr that allows for dynamic read access to some "memory" provided by another user (dev)
        get_memory: ?*const fn (*Self, usize) MemoryIOError!usize = null,
        /// a function ptr that allows for dynamic write access to some "memory" provided by another user (dev)
        set_memory: ?*const fn (*Self, usize, usize) MemoryIOError!void = null,

        /// a function ptr that allows for dynamic read access to some "io" provided by another user (dev)
        /// sig: fn ( cpu : *Cpu, fd : usize ) IoFuncs
        /// fd: file descriptor
        /// returns: a IoFuncs union that contains either a read or write function
        ///          that can be used to perform the requested io operations presumably.
        get_io: ?*const fn (Self, usize) IoFnError!IoFuncs = null,

        pub fn get_flag(self: Self, flag: Flags) bool {
            return (self.flags & @intFromEnum(flag)) != 0;
        }

        pub fn run(self: *Self) void {
            std.debug.print("Running...\n", .{});
            while (self.get_flag(Flags.Running)) {
                const inst = Inst.from((self.get_memory orelse break)(self, self.registers[Self.Pc]) catch |err| {
                    std.debug.print("Error: {}\n\tThis means that the pc value has surpassed the length of the provided memory\n\tHave you tried adding a halt instruction to your program?\n", .{err});
                    break;
                });
                switch (inst.decoded.opcode) {
                    // Nop
                    Instruction.Nop.inst2num() => {
                        std.debug.print("Nop\n", .{});
                        self.registers[Self.Pc] += 1;
                    },
                    // Add (r0, r1) /* 2 args (not directly accessed rather indexed to from a portion of the instruction) */
                    Instruction.Add.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const r1 = inst.decoded.args[1];

                        std.debug.print("Add r0: {}, r1: {}\n", .{ r0, r1 });

                        self.registers[r0] += self.registers[r1];

                        std.debug.print("Output: {}\n", .{self.registers[r0]});

                        self.registers[Self.Pc] += 1;
                    },
                    // Sub (r0, r1) /* 2 args */
                    Instruction.Sub.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const r1 = inst.decoded.args[1];

                        std.debug.print("Sub r0: {}, r1: {}\n", .{ r0, r1 });

                        self.registers[r0] -= self.registers[r1];

                        self.registers[Self.Pc] += 1;
                    },
                    // Mul (r0, r1) /* 2 args */
                    Instruction.Mul.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const r1 = inst.decoded.args[1];

                        std.debug.print("Mul r0: {}, r1: {}\n", .{ r0, r1 });

                        self.registers[r0] *= self.registers[r1];

                        self.registers[Self.Pc] += 1;
                    },
                    // Div (r0, r1) /* 2 args */
                    Instruction.Div.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const r1 = inst.decoded.args[1];

                        std.debug.print("Div r0: {}, r1: {}\n", .{ r0, r1 });

                        self.registers[r0] /= self.registers[r1];

                        self.registers[Self.Pc] += 1;
                    },
                    // Addi (r0, imm) /* 2 args */
                    Instruction.Addi.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const imm = inst.decoded.args[1];

                        std.debug.print("Addi r0: {}, imm: {}\n", .{ r0, imm });

                        self.registers[r0] += imm;

                        std.debug.print("Output: {}\n", .{self.registers[r0]});

                        self.registers[Self.Pc] += 1;
                    },
                    // Subi (r0, imm) /* 2 args */
                    Instruction.Subi.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const imm = inst.decoded.args[1];

                        std.debug.print("Subi r0: {}, imm: {}\n", .{ r0, imm });

                        self.registers[r0] -= imm;

                        std.debug.print("Output: {}\n", .{self.registers[r0]});

                        self.registers[Self.Pc] += 1;
                    },
                    // Muli (r0, imm) /* 2 args */
                    Instruction.Muli.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const imm = inst.decoded.args[1];

                        std.debug.print("Muli r0: {}, imm: {}\n", .{ r0, imm });

                        self.registers[r0] *= imm;

                        std.debug.print("Output: {}\n", .{self.registers[r0]});

                        self.registers[Self.Pc] += 1;
                    },
                    // Divi (r0, imm) /* 2 args */
                    Instruction.Divi.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const imm = inst.decoded.args[1];

                        std.debug.print("Divi r0: {}, imm: {}\n", .{ r0, imm });

                        self.registers[r0] /= imm;

                        std.debug.print("Output: {}\n", .{self.registers[r0]});

                        self.registers[Self.Pc] += 1;
                    },
                    // Mov (r0, r1) /* 2 args */
                    Instruction.Mov.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const r1 = inst.decoded.args[1];

                        std.debug.print("Mov r0: {}, r1: {}\n", .{ r0, r1 });

                        self.registers[r0] = self.registers[r1];

                        std.debug.print("Output: {}\n", .{self.registers[r0]});

                        self.registers[Self.Pc] += 1;
                    },
                    // Movi (r0, imm) /* 2 args */
                    Instruction.Movi.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const imm = inst.decoded.args[1];

                        std.debug.print("Movi r0: {}, imm: {}\n", .{ r0, imm });

                        self.registers[r0] = imm;

                        std.debug.print("Output: {}\n", .{self.registers[r0]});

                        self.registers[Self.Pc] += 1;
                    },
                    // Load (r0, addr) /* 2 args */
                    Instruction.Load.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const addr = inst.decoded.args[1];

                        std.debug.print("Load r0: {}, addr: {}\n", .{ r0, addr });

                        self.registers[r0] = (self.get_memory orelse break)(self, addr) catch |err| {
                            std.debug.print("Error: {}\n\tThis means that the addr value has surpassed the length of the provided memory\n", .{err});
                            break;
                        };

                        std.debug.print("Loaded: {}\n", .{self.registers[r0]});

                        self.registers[Self.Pc] += 1;
                    },
                    // Store (r0, addr) /* 2 args */
                    Instruction.Store.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const addr = inst.decoded.args[1];

                        std.debug.print("Store r0: {}, addr: {}\n", .{ r0, addr });

                        _ = (self.set_memory orelse break)(self, addr, self.registers[r0]) catch |err| {
                            std.debug.print("Error: {}\n\tThis means that the address value has surpassed the length of the provided memory\n", .{err});
                            break;
                        };

                        std.debug.print("Stored: {}\n", .{self.registers[r0]});

                        self.registers[Self.Pc] += 1;
                    },
                    // Beq (r0, r1, addr) /* 3 args */
                    Instruction.Beq.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const r1 = inst.decoded.args[1];
                        const addr = inst.decoded.args[2];

                        std.debug.print("Beq r0: {}, r1: {}, addr: {}\n", .{ r0, r1, addr });

                        if (self.registers[r0] == self.registers[r1]) {
                            self.registers[Self.Pc] = addr;
                        } else {
                            self.registers[Self.Pc] += 1;
                        }
                    },
                    // Bne (r0, r1, addr) /* 3 args */
                    Instruction.Bne.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const r1 = inst.decoded.args[1];
                        const addr = inst.decoded.args[2];

                        std.debug.print("Bne r0: {}, r1: {}, addr: {}\n", .{ r0, r1, addr });

                        if (self.registers[r0] != self.registers[r1]) {
                            self.registers[Self.Pc] = addr;
                        } else {
                            self.registers[Self.Pc] += 1;
                        }
                    },
                    // Blt (r0, r1, addr) /* 3 args */
                    Instruction.Blt.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const r1 = inst.decoded.args[1];
                        const addr = inst.decoded.args[2];

                        std.debug.print("Blt r0: {}, r1: {}, addr: {}\n", .{ r0, r1, addr });

                        if (self.registers[r0] < self.registers[r1]) {
                            self.registers[Self.Pc] = addr;
                        } else {
                            self.registers[Self.Pc] += 1;
                        }
                    },
                    // Bgt (r0, r1, addr) /* 3 args */
                    Instruction.Bgt.inst2num() => {
                        const r0 = inst.decoded.args[0];
                        const r1 = inst.decoded.args[1];
                        const addr = inst.decoded.args[2];

                        std.debug.print("Bgt r0: {}, r1: {}, addr: {}\n", .{ r0, r1, addr });

                        if (self.registers[r0] > self.registers[r1]) {
                            self.registers[Self.Pc] = addr;
                        } else {
                            self.registers[Self.Pc] += 1;
                        }
                    },
                    // Jmp (addr) /* 1 args */
                    Instruction.Jmp.inst2num() => {
                        const addr = inst.decoded.args[0];

                        std.debug.print("Jmp addr: {}\n", .{addr});

                        self.registers[Self.Pc] = addr;
                    },
                    // JmpR (r0) /* 1 args */
                    Instruction.JmpR.inst2num() => {
                        const r0 = inst.decoded.args[0];

                        std.debug.print("JmpR r0: {}\n", .{r0});

                        self.registers[Self.Pc] = self.registers[r0];
                    },
                    // Halt
                    Instruction.Halt.inst2num() => {
                        std.debug.print("Halt\n", .{});
                        self.flags &= ~@intFromEnum(Flags.Running);
                    },
                    // Syscall
                    Instruction.Syscall.inst2num() => {
                        std.debug.print("Syscall\n", .{});

                        if (self.get_io) |io| {
                            const iofn = io(self.*, self.registers[3]) catch |err| {
                                std.debug.print("Error: {}\n", .{err});
                                break;
                            };
                            switch (iofn) {
                                IoFuncs.Read => {
                                    std.debug.print("Read\n", .{});

                                    // data ptr is in r4
                                    const data_ptr = self.registers[4];
                                    const data = (iofn.Read)() catch |err| {
                                        std.debug.print("Error: {}\n", .{err});
                                        break;
                                    };

                                    _ = (self.set_memory orelse break)(self, data_ptr, @intCast(data)) catch |err| {
                                        std.debug.print("Error: {}\n", .{err});
                                        break;
                                    };

                                    std.debug.print("Read: {}\n", .{data});
                                },
                                IoFuncs.Write => {
                                    std.debug.print("Write\n", .{});

                                    // data ptr is in r4, and is used to index into the memory to get the real data
                                    var data_ptr = self.registers[4];
                                    var data = (self.get_memory orelse break)(self, data_ptr) catch |err| {
                                        std.debug.print("Error: {}\n", .{err});
                                        break;
                                    };

                                    // loop until we reach a null byte
                                    while (data != 0) {
                                        (iofn.Write)(@truncate(data)) catch |err| {
                                            std.debug.print("Error: {}\n", .{err});
                                            break;
                                        };

                                        data_ptr += 1;
                                        data = (self.get_memory orelse break)(self, data_ptr) catch |err| {
                                            std.debug.print("Error: {}\n", .{err});
                                            break;
                                        };
                                    }
                                },
                            }
                        } else {
                            std.debug.print("Error: IO Disabled / No IO function provided\n", .{});
                        }

                        self.registers[Self.Pc] += 1;
                    },
                    else => {
                        std.debug.print("Unknown instruction: {}\n", .{inst.decoded.opcode});
                        // self.registers[Self.Pc] += 1;
                        @panic("Error: Unknown instruction");
                    },
                }
            }
        }
    };
}

pub const MemoryIOError = error{
    MemoryOutOfBounds,
};

pub const Instruction = enum(u16) {
    Nop = 0,
    // Reg. Arithmetic
    Add,
    Sub,
    Mul,
    Div,
    // Immediate Arithmetic
    Addi,
    Subi,
    Muli,
    Divi,
    // Move
    Mov,
    Movi,
    // Load/Store
    Load,
    Store,
    // Branch
    Beq,
    Bne,
    Blt,
    Bgt,
    // Jump
    Jmp,
    JmpR, // jump register
    // Halt
    Halt,
    // Syscall
    Syscall,

    pub fn inst2num(self: Instruction) comptime_int {
        return @intFromEnum(self);
    }
};

pub const Inst = extern union {
    inst: u64,
    decoded: extern struct { opcode: u16, args: [3]u16 },

    pub fn from(self: usize) Inst {
        return .{ .inst = self };
    }

    pub fn new(opcode: Instruction, r0: u16, r1: u16, r2: u16) Inst {
        return .{ .decoded = .{ .opcode = @intFromEnum(opcode), .args = .{ r0, r1, r2 } } };
    }

    pub fn to_instruction(self: Inst) u64 {
        // should basically cast self.decoded's data to self.inst
        return self.inst;
    }
};

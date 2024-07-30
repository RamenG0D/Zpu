
# VM using zig

This is a simple VM of sorts written in zig. It is a capable of using both stack and heap style memory, and can run simple programs.
It is still a work in progress, and is not yet capable of running complex programs.

It also does not have a Assembler or Compiler of any kind yet, so you have to the Instructions into a memory buffer yourself.

## Example

[Main](./src/main.zig)
is an example of a program that has a for loop and makes use of a syscall to print a string.

## Instructions

The VM has a set of instructions that it can run. They are as follows:

- `HALT` - Stops the VM
- `ADD` - Adds together two register values and stores the result in the first register
- `SUB` - Subtracts the second register from the first register and stores the result in the first register
- `MUL` - Multiplies two register values and stores the result in the first register
- `DIV` - Divides the first register by the second register and stores the result in the first register
- `MOV` - Moves a value from one register to another
- `JMP` - Jumps to a specific address
- `BEQ` - Branches to a specific address if the two registers are equal
- `BNE` - Branches to a specific address if the two registers are not equal
- `BLT` - Branches to a specific address if the first register is less than the second register
- `BGT` - Branches to a specific address if the first register is greater than the second register
- `BLE` - Branches to a specific address if the first register is less than or equal to the second register
- `BGE` - Branches to a specific address if the first register is greater than or equal to the second register

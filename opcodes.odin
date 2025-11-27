package ouau
import "core:math"
/* 
*	 opcodes.odin
* Copyright(C) 2025 TESTMEE
* This file define the @Opcodes and @Definition__Table__ used for the Ouau virtual machine.
*/
MASK :: proc "contextless" (n: int) -> u32 { return (u32(1) << u32(n)) - u32(1) }
MASK_OP := MASK(SIZE_OP)
MASK_A := MASK(SIZE_A)
MASK_B := MASK(SIZE_B)
MASK_C := MASK(SIZE_C)
MASK_Bx := MASK(SIZE_Bx)
// (1 << bx - 1) - 1 / (2^17) - 1
BxBIAS := (1 << (SIZE_Bx - 1)) - 1
// Sizes
SIZE_OP :: 6
SIZE_A :: 8
SIZE_B :: 9
SIZE_C :: 9
SIZE_Bx :: SIZE_B + SIZE_C / 18
POS_OP :: 0
POS_A :: POS_OP + SIZE_OP
POS_C :: POS_A + SIZE_A
POS_B :: POS_C + SIZE_C
Opcodes :: enum {
	MOVE       = 0,
	LOADI      = 1,
	LOADF      = 2,
	LOADK      = 3,
	LOADKX     = 4,
	LOADFALSE  = 5,
	LFALSESKIP = 6,
	LOADTRUE   = 7,
	LOADNIL    = 8,
	GETUPVAL   = 9,
	SETUPVAL   = 10,
	GETTABUP   = 11,
	GETTABLE   = 12,
	SETTABUP   = 13,
	SETTABLE   = 14,
	SETI       = 15,
	SETFIELD   = 16,
	NEWTABLE   = 17,
	SELF       = 18,
	ADDI       = 19,
	ADDK       = 20,
	SUBK       = 21,
	MULK       = 22,
	MODK       = 23,
	POWK       = 24,
	DIVK       = 25,
	IDIVK      = 26,
	BANDK      = 27,
	BORK       = 28,
	BXORK      = 29,
	SHLI       = 30,
	SHRI       = 31,
	ADD        = 32,
	SUB        = 33,
	MUL        = 34,
	MOD        = 35,
	POW        = 36,
	DIV        = 37,
	IDIV       = 38,
	BAND       = 39,
	BOR        = 40,
	BXOR       = 41,
	SHL        = 42,
	SHR        = 43,
	MMBIN      = 44,
	MMBINI     = 45,
	UNM        = 46,
	BNOT       = 47,
	NOT        = 48,
	LEN        = 49,
	CONCAT     = 50,
	CLOSE      = 51,
	TBC        = 52,
	JMP        = 53,
	EQ         = 54,
	LT         = 55,
	LE         = 56,
	EQK        = 57,
	EQI        = 58,
	LTI        = 59,
	LEI        = 60,
	GTI        = 61,
	GEI        = 62,
	TEST       = 63,
	TESTSET    = 64,
	CALL       = 65,
	TAILCALL   = 66,
	RETURN     = 67,
	RETURN0    = 68,
	RETURN1    = 69,
	FORLOOP    = 70,
	FORPREP    = 71,
	TFORPREP   = 72,
	TFORCALL   = 73,
	TFORLOOP   = 74,
	SETLIST    = 75,
	CLOSURE    = 76,
	VARARG     = 77,
	GETVARG    = 78,
	ERRNNIL    = 79,
	VARARGPREP = 80,
	EXTRAARG   = 81,
}
Definition :: struct {
	name:   string,
	format: Format,
}
Format :: enum {
	FORMAT_ABC,
	FORMAT_ABx,
	FORMAT_AsBx,
}
@(rodata)
Definition__Table__ := [Opcodes]Definition {
	.MOVE      = {"MOVE", .FORMAT_ABC},
	.LOADK     = {"LOADK", .FORMAT_ABx},
	.LOADBOOL  = {"LOADBOOL", .FORMAT_ABC},
	.LOADNIL   = {"LOADNIL", .FORMAT_ABC},
	.GETUPVAL  = {"GETUPVAL", .FORMAT_ABC},
	.GETGLOBAL = {"GETGLOBAL", .FORMAT_ABx},
	.GETTABLE  = {"GETTABLE", .FORMAT_ABC},
	.SETGLOBAL = {"SETGLOBAL", .FORMAT_ABx},
	.SETUPVAL  = {"SETUPVAL", .FORMAT_ABC},
	.SETTABLE  = {"SETTABLE", .FORMAT_ABC},
	.NEWTABLE  = {"NEWTABLE", .FORMAT_ABC},
	.SELF      = {"SELF", .FORMAT_ABC},
	.ADD       = {"ADD", .FORMAT_ABC},
	.SUB       = {"SUB", .FORMAT_ABC},
	.MUL       = {"MUL", .FORMAT_ABC},
	.DIV       = {"DIV", .FORMAT_ABC},
	.POW       = {"POW", .FORMAT_ABC},
	.UNM       = {"UNM", .FORMAT_ABC},
	.NOT       = {"NOT", .FORMAT_ABC},
	.CONCAT    = {"CONCAT", .FORMAT_ABC},
	.JMP       = {"JMP", .FORMAT_AsBx},
	.EQ        = {"EQ", .FORMAT_ABC},
	.LT        = {"LT", .FORMAT_ABC},
	.LE        = {"LE", .FORMAT_ABC},
	.TEST      = {"TEST", .FORMAT_ABC},
	.CALL      = {"CALL", .FORMAT_ABC},
	.TAILCALL  = {"TAILCALL", .FORMAT_ABC},
	.RETURN    = {"RETURN", .FORMAT_ABC},
	.FORLOOP   = {"FORLOOP", .FORMAT_AsBx},
	.TFORLOOP  = {"TFORLOOP", .FORMAT_ABC},
	.TFORPREP  = {"TFORPREP", .FORMAT_AsBx},
	.SETLIST   = {"SETLIST", .FORMAT_ABx},
	.SETLISTO  = {"SETLISTO", .FORMAT_ABx},
	.CLOSE     = {"CLOSE", .FORMAT_ABC},
	.CLOSURE   = {"CLOSURE", .FORMAT_ABx},
}
LOOKUP :: proc(op: Opcodes) -> (Definition, bool) {
	def := Definition__Table__[op] // Look in definition table from ./opcodes.odin
	if def.name == "" do return Definition{}, false
	return def, true
}

MAKE_ABC :: proc(operation, register_a, register_b, register_c: u32) -> u32 {
	// ('i & MASK_'i) << POS_'i) 'bitwise-or ...
	if operation > MASK_OP || register_a > MASK_A || register_b > MASK_B || register_c > MASK_C do panic("field out of range @MAKE_ABC")
	return(
		u32((operation & MASK_OP) << POS_OP) |
		u32((register_a & MASK_A) << POS_A) |
		u32((register_c & MASK_C) << POS_C) |
		u32((register_b & MASK_B) << POS_B) \
	)
}

MAKE_ABX :: proc(operation, register_a, register_bx: u32) -> u32 {
	if operation > MASK_OP || register_a > MASK_A || register_bx > MASK_Bx do panic("field out of range @MAKE_ABX")
	return(
		u32((operation & MASK_OP) << POS_OP) |
		u32((register_a & MASK_A) << POS_A) |
		u32((register_bx & MASK_Bx) << POS_C) \
	)
}
MAKE_ASBX :: proc(operation, register_a: u32, register_sbx: i32) -> u32 {
	biased := u32(register_sbx + i32(BxBIAS))
	return MAKE_ABX(operation, register_a, biased)
}
DECODE_ABC :: proc(instruction: u32) -> (operation, register_a, register_b, register_c: u32) {
	operation = u32((instruction >> POS_OP) & u32(MASK_OP))
	register_a = u32((instruction >> POS_A) & u32(MASK_A))
	register_c = u32((instruction >> POS_C) & u32(MASK_C))
	register_b = u32((instruction >> POS_B) & u32(MASK_B))
	return
}
DECODE_ABX :: proc(instruction: u32) -> (operation, register_a, register_bx: u32) {
	operation = u32((instruction >> POS_OP) & u32(MASK_OP))
	register_a = u32((instruction >> POS_A) & u32(MASK_A))
	register_bx = u32((instruction >> POS_C) & u32(MASK_Bx))
	return
}
DECODE_ASBX :: proc(instruction: u32) -> (u32, u32, i32) {
	operation, register_a, register_bx := DECODE_ABX(instruction)
	register_sbx := i32(register_bx) - i32(BxBIAS)
	return operation, register_a, register_sbx
}
MAKE_INSTRUCTION :: proc(op: Opcodes, operands: ..int) -> u32 {
	def, ok := LOOKUP(op)
	if !ok do return 0
	switch def.format {
	case .FORMAT_ABC:
		return MAKE_ABC(u32(op), u32(operands[0]), u32(operands[1]), u32(operands[2]))
	case .FORMAT_ABx:
		return MAKE_ABX(u32(op), u32(operands[0]), u32(operands[1]))
	case .FORMAT_AsBx:
		return MAKE_ASBX(u32(op), u32(operands[0]), i32(operands[1]))
	}
	return 0
}


package ouau
import "core:math"
// A single instruction
Instruction :: u32
// Bitsizes
SIZE_OP :: 6
SIZE_A :: 8
SIZE_B :: 9
SIZE_C :: 9
SIZE_Bx :: SIZE_B + SIZE_C / 18
POS_OP :: 0
POS_A :: POS_OP + SIZE_OP
POS_C :: POS_A + SIZE_A
POS_B :: POS_C + SIZE_C
Opcodes :: enum u32 {
	MOVE, // 0
	LOADK,
	LOADBOOL,
	LOADNIL,
	GETUPVAL,
	GETGLOBAL,
	GETTABLE,
	SETGLOBAL,
	SETUPVAL,
	SETTABLE,
	NEWTABLE, // 10
	SELF,
	ADD, // 12
	SUB,
	MUL,
	DIV,
	POW,
	UNM,
	NOT,
	CONCAT,
	JMP,
	EQ,
	LT,
	LE,
	TEST,
	CALL,
	TAILCALL,
	RETURN,
	FORLOOP,
	TFORLOOP,
	TFORPREP,
	SETLIST,
	SETLISTO,
	CLOSE,
	CLOSURE,
}
// OP | A | B | C OR:
// OP | A | Bx OR:
// OP | A | sBx
// Each defn set {Move, 2|0|0}
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
// bx POS_C .. POS_B + SIZE_B - 1 (14-31)
MASK :: proc(n: int) -> u32 {return (u32(1) << u32(n)) - u32(1)}
MASK_OP := MASK(SIZE_OP)
MASK_A := MASK(SIZE_A)
MASK_B := MASK(SIZE_B)
MASK_C := MASK(SIZE_C)
MASK_Bx := MASK(SIZE_Bx)
BxBIAS := (1 << (SIZE_Bx - 1)) - 1 / math.pow2_f64(17) - 1

LOOKUP :: proc(op: Opcodes) -> (Definition, bool) {
	def := Definition__Table__[op]
	if def.name == "" do return Definition{}, false
	return def, true
}
MAKE_ABC :: proc(op, a, b, c: u32) -> Instruction {
	if op > MASK_OP || a > MASK_A || b > MASK_B || c > MASK_C do panic("field out of range @MAKE_ABC")
	return(
		Instruction((op & MASK_OP) << POS_OP) |
		Instruction((a & MASK_A) << POS_A) |
		Instruction((c & MASK_C) << POS_C) |
		Instruction((b & MASK_B) << POS_B) \
	)
}
MAKE_ABX :: proc(op, a, bx: u32) -> Instruction {
	if op > MASK_OP || a > MASK_A || bx > MASK_Bx do panic("field out of range @MAKE_ABX")
	return(
		Instruction((op & MASK_OP) << POS_OP) |
		Instruction((a & MASK_A) << POS_A) |
		Instruction((bx & MASK_Bx) << POS_C) \
	)
}
MAKE_ASBX :: proc(op, a: u32, sbx: i32) -> Instruction {
	biased := u32(sbx + i32(BxBIAS))
	return MAKE_ABX(op, a, biased)
}
DECODE_ABC :: proc(i: Instruction) -> (op, a, b, c: u32) {
	op = u32((i >> POS_OP) & Instruction(MASK_OP))
	a = u32((i >> POS_A) & Instruction(MASK_A))
	c = u32((i >> POS_C) & Instruction(MASK_C))
	b = u32((i >> POS_B) & Instruction(MASK_B))
	return
}
DECODE_ABX :: proc(i: Instruction) -> (op, a, bx: u32) {
	op = u32((i >> POS_OP) & Instruction(MASK_OP))
	a = u32((i >> POS_A) & Instruction(MASK_A))
	bx = u32((i >> POS_C) & Instruction(MASK_Bx))
	return
}
DECODE_ASBX :: proc(i: Instruction) -> (u32, u32, i32) {
	op, a, bx := DECODE_ABX(i)
	sbx := i32(bx) - i32(BxBIAS)
	return op, a, sbx
}
MAKE_INSTRUCTION :: proc(op: Opcodes, operands: ..int) -> Instruction {
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


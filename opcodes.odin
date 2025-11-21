package ouau
import "core:encoding/endian"
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
Opcodes :: enum byte {
	MOVE,
	LOADK,
	LOADBOOL,
	LOADNIL,
	GETUPVAL,
	GETGLOBAL,
	GETTABLE,
	SETGLOBAL,
	SETUPVAL,
	SETTABLE,
	NEWTABLE,
	SELF,
	ADD,
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
	name:  string,
	width: Format,
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
// MAKE_INSTRUCTION :: proc(
// 	allocator := context.allocator,
// 	op: Opcodes,
// 	operands: ..int,
// ) -> (i: Instructions) {
// 	def, ok := LOOKUP(op)
// 	if !ok do return nil
// 	inst_len := 1
// 	if len(def.width) > 0 {
// 		for w in def.width {
// 			inst_len += w
// 		}
// 	}
// 	i, err := make(Instructions, 0, allocator)
// 	ensure(err == nil)
// 	errr := resize(&instruction, inst_len)
// 	ensure(errr == nil)
// 	instruction[0] = u8(op)
// 	offset := 1
// 	for o, i in operands {
// 		width := def.width[i]
// 		switch width {
// 		case 3:
// 		case 2:
// 		case 1:
// 		}
// 	}
// 	return
// }


package ouau
/* opcodes.odin
* Copyright(C) 2025 TESTMEE
* This file define the @Opcodes and @Definition__Table__ used for the Ouau virtual machine.
*/
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
	MOVE      = 0,
	LOADK     = 1,
	LOADBOOL  = 2,
	LOADNIL   = 3,
	GETUPVAL  = 4,
	GETGLOBAL = 5,
	GETTABLE  = 6,
	SETGLOBAL = 7,
	SETUPVAL  = 8,
	SETTABLE  = 9,
	NEWTABLE  = 10,
	SELF      = 11,
	ADD       = 12,
	SUB       = 13,
	MUL       = 14,
	DIV       = 15,
	POW       = 16,
	UNM       = 17,
	NOT       = 18,
	CONCAT    = 19,
	JMP       = 20,
	EQ        = 21,
	LT        = 22,
	LE        = 23,
	TEST      = 24,
	CALL      = 25,
	TAILCALL  = 26,
	RETURN    = 27,
	FORLOOP   = 28,
	TFORLOOP  = 29,
	TFORPREP  = 30,
	SETLIST   = 31,
	SETLISTO  = 32,
	CLOSE     = 33,
	CLOSURE   = 34,
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


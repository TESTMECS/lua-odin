# Ouau Goals:
- Nicely commented, easy to read just like the lua source.
- Incremental GC, and Register Based Virtual Machine for learning purposes.
- `luac -l` should produce similar output to `ouau -l`. Not full compatability because...
# difference from lua
|lua| ouau|
|---| --- |
|bnot: '~21->22' | bnot: '!21->22' |
|a=1| global a = 1|
- Errors are values. In Lua they are only gotten through `pcall` or `xpcall`.
- To make Error handling easier, introduce two new operators:
- `${}` is the error operator, it creates a new error value tagged with a table.
- `^` is the error propagation operator, it returns the error value from the stack.
- TESTTYPE is a new opcode, it is like TEST but it checks the type of the value, used for this error handling but also for type checking tables, numbers, floats, etc.
## Reasons
- `~` is both a prefix and binary operator, lua doesn't use `!` so we use it to disambiguate this.  
- `global` makes globals much more explicit than `a=1` in lua. Can use the same parsing rules and easier to differentiate where the variable should be put.


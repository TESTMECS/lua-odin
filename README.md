# difference from lua
|lua| ouau|
|---| --- |
|bnot: '~21->22' | bnot: '!21->22' |
|a=1| global a = 1 |
# Example:
```ouau
-- blocks
do
	local a = 1
	local b = 2
	local c = a * b
	print(c)
end
-- closures
local function add(a, b)
	return a + b
end
print(add(1, 2)) -- 3
--
function addr(a,b)
	return add(a,b) + add(a,b)
end
print(addr(1,2)) -- 6
-- Tables
local a = {1,2,3}
print(a[1])
--
local b = {"a"=1, "b"=2}
print(b["a"])
-- Scopes
global a = 1
function foo()
	local a = 2
	print(a)
end
foo() -- 2
print(a) -- 1
-- For 
local step_two = 0
for i = 1, 10, 2 do
	step_two = step_two + i
end
print(step_test) -- 25 
-- while
local b = 0
while true do
	b = b + 1
	break
end
print(b) -- 1
-- repeat
local c = 0
repeat
	c = c + 1
until c == 2
print(c) -- 2
```
# Justfile:
```just
default:
	@just --list
# commit and push

# just build the binary
alias b := build
build:
	odin build . -out:lua-odin.build

# start the repl
alias re := repl
repl:
	odin run . -- repl 

# test parser functions
test_parser_name := "test_varargs"
test_parser:
	odin test ./test_parser -define:ODIN_TEST_NAMES={{test_parser_name}}

# test eval functions
test_eval_name := "test_varargs"
test_eval:
	odin test ./test_eval -define:ODIN_TEST_NAMES={{test_eval_name}}

# test a .ouau file
test_file_dir := "./examples"
test_file_name := "scope.ouau"
alias tf := test-file
test-file:
	odin run . -- file {{test_file_dir}}/{{test_file_name}}

# print ast for a .ouau file
alias ast := ast-file
ast-file:
	odin run . -- ast {{test_file_dir}}/{{test_file_name}}
```
# TODO:
- Local
- Typechecking. 
- Prettier errors. 
- Fixing tables parsing.
- Fixing Anon Function Declarations.




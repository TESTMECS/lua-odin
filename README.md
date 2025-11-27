# difference from lua
|lua| ouau|
|---| --- |
|bnot: '~21->22' | bnot: '!21->22' |
|a=1| global a = 1|
# Example:
```ouau
do
	local a = 1
	local b = 2
	local c = a + b
	print(c)
end
local function add(a, b)
	return a + b
end
print(add(1, 2)) -- 3
function addr(a,b)
	return add(a,b) + add(a,b)
end
print(addr(1,2)) -- 6
```
# Justfile:
```just
default:
	@just --list
# commit and push
alias cp := commit-push
commit-push MSG:
	git add . && git commit -m "{{MSG}}" && git push
# just build the binary
alias b := build
build:
	odin build . -out:lua-odin.build
# clean the builds	
alias c := clean
clean:
	rm *.build && rm *.bin
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
# Status:
- Opcodes are copied but not implemented. I'm not sure how to do this.


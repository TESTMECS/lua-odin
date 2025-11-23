default:
	@just --list

alias cp := commit-push
commit-push MSG:
	git add . && git commit -m "{{MSG}}" && git push

test_dir := "test_parser" 
alias t := test
test:
	odin test {{test_dir}}

alias b := build
build:
	odin build .
	
alias re := repl
repl:
	odin run . -- repl 

test_file_dir := "./examples"
test_file_name := "test.ouau"
alias tf := test-file
test-file:
	odin run . -- file {{test_file_dir}}/{{test_file_name}}

test_compiler_name := "test_local"
test_compiler:
	odin test ./test_compiler -define:ODIN_TEST_NAMES={{test_compiler_name}}

test_function:
	odin test ./test_compiler -define:ODIN_TEST_NAMES=test_function

test_parser_name := "test_functions"
test_parser:
	odin test ./test_parser -define:ODIN_TEST_NAMES={{test_parser_name}}



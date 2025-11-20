test_dir := "test_parser"
alias cp := commit-push
commit-push MSG:
	git add . && git commit -m "{{MSG}}" && git push

alias t := test
test:
	odin test {{test_dir}}

alias b := build
build:
	odin build .
	
alias re := repl
repl:
	odin run . -- repl 

# difference from lua
|lua| ouau|
|---| --- |
|bnot: '~21->22' | bnot: '!21->22' |
|a=1| global a = 1|
## Reasons
- `~` is both a prefix and binary operator, lua doesn't use `!` so we use it to disambiguate this.  
- `global` makes globals much more explicit than `a=1` in lua. Can use the same parsing rules and easier to differentiate where the variable should be put.
# Status
- Working on compiler



set pagination off
set debuginfod enabled off
break process
break calculate
run
info args
continue
backtrace
info args
next
info locals
print &result
x/4gx $sp
up
info args
down
info args
continue

set pagination off
set confirm off
set debuginfod enabled off
break prime
break damage
run
next
set $previous_slot = &previous
set $previous_value = previous
printf "PRIME_SLOT=%p TARGET=%p\n", &previous, previous
x/10gx $sp-16
continue
printf "DAMAGE_SLOT=%p POINTER=%p\n", &pointer, pointer
print &pointer == $previous_slot
print pointer == $previous_value
x/10gx $sp-16
backtrace
info args
up
info args
print value
down
next
up
print value
down
continue

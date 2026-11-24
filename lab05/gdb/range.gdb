set pagination off
set debuginfod enabled off
break emit if index >= 1 && index <= 3
commands
  silent
  printf "LAB05 range index=%lu value=%ld\n", index, value
  continue
end
run 1 9 2 > /dev/null

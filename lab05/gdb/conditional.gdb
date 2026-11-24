set pagination off
set debuginfod enabled off
break emit if index % 2 == 0
commands
  silent
  printf "LAB05 even index=%lu value=%ld\n", index, value
  backtrace 2
  continue
end
run 1 9 2 > /dev/null

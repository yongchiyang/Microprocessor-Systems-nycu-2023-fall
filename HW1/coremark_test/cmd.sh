#under coremark repo:
#gcc -O2 -pg -fno-inline-small-functions -o coremark.exe core_list_join.c core_main.c core_matrix.c core_state.c core_util.c posix/core_portme.c -Iposix -I. -DFLAGS_STR='"-Wall -O2 -DPERFORMANCE_RUN=1 -DITERATIONS=0 "'

gcc -O2 -pg -fno-inline-small-functions -o coremark.exe core_list_join.c core_main.c core_matrix.c core_state.c core_util.c core_portme.c -DFLAGS_STR='"-Wall -O2  -DUSE_CLOCK=1 -DITERATIONS=0 "'

./coremark.exe

gprof ./coremark.exe gmon.out > profile.txt

gprof2dot profile.txt | dot -Tsvg -o coremark.svg


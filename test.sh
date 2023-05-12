#!/bin/bash
# Linux amdgpu Radeon VRAM Swapping Test
#
# In theory all test results should/could have roughly similar speeds.
# However in practice (Linux 6.1, open-source amdgpu driver) tests
# 5 and 6 have a lot worse performance especially when an eGPU enclosure
# is used.
#
# It seems that the Linux amdgpu driver:
#
# 1. Uses system memory (GTT) when VRAM is full (as expected)
# 2. Never moves objects allocated on GTT back to VRAM? Neither
# when VRAM becomes available again, nor based on actual usage.
# (unexpected)

PATH=$(dirname $0):$PATH

check_available_cmds() {
	local cmds="tail head grep sed seq glxinfo radeontop memtest_vulkan"
	local cmd

	for cmd in $cmds; do
		command -v "$cmd" &> /dev/null || {
			echo "Error: Could not find command \"$cmd\", exiting"
			return 1
		}
	done

	return 0
}

check_available_cmds || exit 1


VRAM_MB="$(glxinfo | grep '^[ ]*Video memory: .*MB$' | sed 's/.*: \([0-9]*\)MB/\1/')"
NUM_CHUNKS=10

if [ -z "${VRAM_MB}" ]; then
	echo "Error: Could not detect VRAM size"
	exit 1
fi

CHUNK_SIZE=$(( ${VRAM_MB} / (${NUM_CHUNKS}-2) ))

get_vram_gtt_usage() {
	local output=$(radeontop -d - -l 1 | tail -n1 | grep "^[0-9]*\.[0-9]*:.*vram.*gtt")
	local vram=$(echo "$output" | sed "s/.*vram \([^,]*\),.*/\1/")
	local gtt=$(echo "$output" | sed "s/.*gtt \([^,]*\),.*/\1/")

	echo "VRAM: $vram, GTT: $gtt"
}

run_cmd_bg() {
	local cmd="$1"
	local match="$2"
	local nth="$3"
	local action="$4"
	local line

	coproc bgfd { exec $cmd; }

	echo "$bgfd_PID"
	echo "/dev/fd/${bgfd[0]}"

	[ -z "$nth" ] && nth=1

	local i=1
	while read line; do
		if echo "$line" | grep -q "$match"; then
			while [ "$i" -ge "$nth" ]; do
				[ -n "$action" ] && eval $action

				shift 2
				nth="$3"
				action="$4"

				[ -z "$nth" ] && break
			done

			[ -z "$nth" ] && break
			i=$(($i + 1))
		fi
	done < /dev/fd/${bgfd[0]}

	echo "$line"

}

# Run in sub-shell, to avoid:
# "./test.sh: line 24: warning: execute_coproc: coproc [289329:bgfd] still exists"
run_cmd_match_stop() {
	local action="$4"
	local argn="$(($#-1))"

	( run_cmd_bg "$@" "${!argn}" "kill -s STOP \$bgfd_PID" )
}

run_cmd_match_term() {
	local action="$4"
	local argn="$(($#-1))"

	( run_cmd_bg "$@" "${!argn}" "kill -s TERM \$bgfd_PID" )
}

terminate_subprocesses() {
	local bgpids="$1"
	local curpid

	for curpid in $bgpids; do
		kill -s TERM $curpid
		kill -s CONT $curpid
	done
}

test1() {
	local out

	echo "### Starting 1st test: baseline, small ###"
	echo "Running benchmark on one chunk of ${CHUNK_SIZE}MB of VRAM..."
	out="$(run_cmd_match_term "memtest_vulkan 1 $((${CHUNK_SIZE}*1024*1024))" "Passed .* seconds" 3 "get_vram_gtt_usage")"
	echo "Result:"
	echo "$out" | tail -n +3 | sed 's/^/    /'
	echo ""
}

test2() {
	local out

	echo "### Starting 2nd test: baseline, full ###"
	echo "Running benchmark on all available VRAM..."
	out="$(run_cmd_match_term "memtest_vulkan 1" "Passed .* seconds" 3 "get_vram_gtt_usage")"
	echo "Result:"
	echo "$out" | tail -n +3 | sed 's/^/    /'
	echo ""
}

test3() {
	local out
	local bgpids=""

	echo "### Starting 3rd test: Half clogged VRAM ###"
	echo "Clogging VRAM with idle / SIGSTOP'ed processes,"
	echo "allocating $(((${NUM_CHUNKS}-2)/2)) chunks of size ${CHUNK_SIZE}MB:"
	for i in `seq 1 $(((${NUM_CHUNKS}-2)/2))`; do
		bgpids="$(run_cmd_match_stop "memtest_vulkan 1 $((${CHUNK_SIZE}*1024*1024))" "Passed .* seconds" 1 "" | head -n1) $bgpids"
		echo "... $(($i * ${CHUNK_SIZE}))MB allocated --- usage: $(get_vram_gtt_usage)"
	done
	echo "Running benchmark on one chunk of ${CHUNK_SIZE}MB of VRAM..."
	out="$(run_cmd_match_term "memtest_vulkan 1 $((${CHUNK_SIZE}*1024*1024))" "Passed .* seconds" 3 "get_vram_gtt_usage")"
	terminate_subprocesses "$bgpids"
	echo "Result:"
	echo "$out" | tail -n +3 | sed 's/^/    /'
	echo ""
}

test4() {
	local out
	local bgpids=""

	echo "### Starting 4th test: 3/4 clogged VRAM ###"
	echo "Clogging VRAM with idle / SIGSTOP'ed processes,"
	echo "allocating $(((${NUM_CHUNKS}-2)/4*3)) chunks of size ${CHUNK_SIZE}MB:"
	for i in `seq 1 $(((${NUM_CHUNKS}-2)/4*3))`; do
		bgpids="$(run_cmd_match_stop "memtest_vulkan 1 $((${CHUNK_SIZE}*1024*1024))" "Passed .* seconds" 1 "" | head -n1) $bgpids"
		echo "... $(($i * ${CHUNK_SIZE}))MB allocated --- usage: $(get_vram_gtt_usage)"
	done
	echo "Running benchmark on one chunk of ${CHUNK_SIZE}MB of VRAM..."
	out="$(run_cmd_match_term "memtest_vulkan 1 $((${CHUNK_SIZE}*1024*1024))" "Passed .* seconds" 3 "get_vram_gtt_usage")"
	terminate_subprocesses "$bgpids"
	bgpids=""
	echo "Result:"
	echo "$out" | tail -n +3 | sed 's/^/    /'
	echo ""
}

test5() {
	local out
	local bgpids=""

	echo "### Starting 5th test: Fully clogged VRAM ###"
	echo "Clogging VRAM with idle / SIGSTOP'ed processes,"
	echo "allocating ${NUM_CHUNKS} chunks of size ${CHUNK_SIZE}MB:"
	for i in `seq 1 ${NUM_CHUNKS}`; do
		bgpids="$(run_cmd_match_stop "memtest_vulkan 1 $((${CHUNK_SIZE}*1024*1024))" "Passed .* seconds" 1 "" | head -n1) $bgpids"
		echo "... $(($i * ${CHUNK_SIZE}))MB allocated --- usage: $(get_vram_gtt_usage)"
	done
	echo "Running benchmark on one chunk of ${CHUNK_SIZE}MB of VRAM..."
	out="$(run_cmd_match_term "memtest_vulkan 1 $((${CHUNK_SIZE}*1024*1024))" "Passed .* seconds" 3 "get_vram_gtt_usage")"
	terminate_subprocesses "$bgpids"
	echo "Result:"
	echo "$out" | tail -n +3 | sed 's/^/    /'
	echo ""
}

test6() {
	local out
	local bgpids=""

	echo "### Starting 6th test: Temporarily fully clogged VRAM ###"
	echo "Clogging VRAM with idle / SIGSTOP'ed processes,"
	echo "allocating ${NUM_CHUNKS} chunks of size ${CHUNK_SIZE}MB:"
	for i in `seq 1 ${NUM_CHUNKS}`; do
		bgpids="$(run_cmd_match_stop "memtest_vulkan 1 $((${CHUNK_SIZE}*1024*1024))" "Passed .* seconds" 1 "" | head -n1) $bgpids"
		echo "... $(($i * ${CHUNK_SIZE}))MB allocated --- usage: $(get_vram_gtt_usage)"
	done
	echo "Starting benchmark process stopped"
	echo "Killing clogging processes"
	echo "Continuing benchmark process"
	echo "Running benchmark on one chunk of ${CHUNK_SIZE}MB of VRAM..."
	action="kill -s STOP \$bgfd_PID; terminate_subprocesses \"$bgpids\"; kill -s CONT \$bgfd_PID"
	out="$(run_cmd_match_term "memtest_vulkan 1 $((${CHUNK_SIZE}*1024*1024))" "Passed .* seconds" 1 "$action" 4 "get_vram_gtt_usage")"
	#terminate_subprocesses "$bgpids"
	echo "Result:"
	echo "$out" | tail -n +3 | sed 's/^/    /'
	echo ""
}

GPU="$(run_cmd_match_term "memtest_vulkan 1 $((${CHUNK_SIZE}*1024*1024))" "^Standard 5-minute test of 1: " 1 "" | tail -n1 | sed "s/Standard 5-minute test of 1: //")"

echo "GPU: $GPU"
echo "Detected VRAM size: ${VRAM_MB}MB"
echo ""

test1
test2
test3
test4
test5
test6

echo "End of benchmarking, exiting"
exit 0

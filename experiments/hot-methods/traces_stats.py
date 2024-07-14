#!/usr/bin/env python3
#
# Output unique traces statistics
# Usage: python3 traces_stats.py <path-to-unique-traces>
# This script will print out the following info
# number of traces, number of unique traces, number of events, average events per trace
#
import os
import sys


if len(sys.argv) != 2:
    print('Usage: python3 traces_stats.py <path-to-unique-traces>')
    exit(1)

traces_path = sys.argv[1]

if not os.path.exists(traces_path):
    print('Cannot find traces file {}'.format(traces_path))
    exit(1)

header = False

number_of_traces = 0
number_of_unique_traces = 0
number_of_events = 0

with open(traces_path) as f:
    for line in f.readlines():
        if not header:
            # Skip the first line
            header = True
            continue
        
        line = line.strip()
        if line:
            # Example line:
            # 4 [next~1, next~2]
            # Everytime we see a line, we add 1 to number_of_unique_traces, add frequency to number_of_traces, add number of events * frequency to number_of_events
            number_of_unique_traces += 1
            number_of_trace = int(line.split(' ')[0])
            number_of_traces += number_of_trace
            number_of_events += int(len(line.split(', '))) * number_of_trace

print("{},{},{},{}".format(number_of_traces, number_of_unique_traces, number_of_events, 0 if number_of_traces == 0 else number_of_events / number_of_traces))

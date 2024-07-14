#!/usr/bin/env python3
#
# Given instrumentation log in ${OUTPUT_DIR}/${project}/logs/ctw/${project}.log, return instrumentation time
# To calculate instrumentation time, we measure time to instrument and monitor project
# then we subtract time to monitor project
# Usage: python3 check_time_and_test.py <log-file>
#
import os
import sys
from datetime import datetime

if len(sys.argv) != 2:
    print('-1')
    exit()


if not os.path.exists(sys.argv[1]):
    print('-1')
    exit()


times = []
monitor_e2e = ''

with open(sys.argv[1], 'r') as f:
    for line in f.readlines():
        line = line.strip()
        if 'Finished at:' in line:
            times.append(line.rpartition(' ')[2])
        elif 'Finished monitor_project in' in line:
            monitor_e2e = line.split(' ')[-2]


if len(times) < 4 or monitor_e2e == '':
    print('-1')
    exit()

try:
    monitor_e2e = int(monitor_e2e)/1000
except:
    print('-1')
    exit()

t1 = datetime.strptime(times[-2], '%Y-%m-%dT%H:%M:%SZ').timestamp()
t2 = datetime.strptime(times[-1], '%Y-%m-%dT%H:%M:%SZ').timestamp()

print(round(t2-t1-monitor_e2e, 3))

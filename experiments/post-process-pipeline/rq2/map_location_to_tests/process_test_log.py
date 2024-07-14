#!/usr/bin/env python3
import os
import re
import sys
from collections import defaultdict

if len(sys.argv) < 4 or not os.path.isdir(sys.argv[1]) or not os.path.isdir(sys.argv[2]):
    print('Usage: python3 process_test_log.py <project-output-dir> <traces-project-output-dir> <project-name>')
    exit(1)

if not os.path.isfile(os.path.join(sys.argv[1], sys.argv[3], 'logs', 'test.log')):
    print('cannot find test.log')
    exit(1)

if not os.path.isfile(os.path.join(sys.argv[2], sys.argv[3], 'projects', sys.argv[3], '.all-traces', 'locations.txt')):
    print('cannot find locations.txt')
    exit(1)


def open_location():
    long_to_short = {}
    with open(os.path.join(sys.argv[2], sys.argv[3], 'projects', sys.argv[3], '.all-traces', 'locations.txt')) as f:
        header = False
        for line in f.readlines():
            line = line.strip()
            if not header:
                header = True
                continue
            short_location, _, long_location = line.partition(' ')
            long_to_short[long_location] = short_location
    return long_to_short

def open_test_log(long_to_short):
    location_to_test = defaultdict(set)
    output = []

    with open(os.path.join(sys.argv[1], sys.argv[3], 'logs', 'test.log')) as f:
        for line in f:
            line = line.strip()
            if line:
                if 'is executed in test method' in line:
                    match = re.match('line (\d+) of (.*) is executed in test method: (.*)', line)
                    if match:
                        line = match.group(1)
                        path = match.group(2).replace('/', '.')
                        test = match.group(3)
                        location_to_test[path + ':' + line].add(test)

    for location, test in location_to_test.items():
        # Map location to short location
        path, _, linenum = location.partition(':')
        found = False
        for long_location in long_to_short.keys():
            if path in long_location and ':{})'.format(linenum) in long_location:
                print('location: ({}) {} has {} tests'.format(long_to_short[long_location], location, len(test)))
                output.append('{},{},{}\n'.format(long_to_short[long_location], len(test), location))
                found = True
                break
        if not found:
            print('location: (UNKNOWN) {} has {} tests'.format(location, len(test)))
            output.append('-1,{},{}\n'.format(len(test), location))

    if output:
        with open(os.path.join(sys.argv[2], sys.argv[3], 'projects', sys.argv[3], '.all-traces', 'location-to-tests.txt'), 'w') as f:
            f.writelines(output)

long_to_short = open_location()
open_test_log(long_to_short)

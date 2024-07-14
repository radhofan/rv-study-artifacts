#! /usr/bin/python3
#
# Find hot methods
# Usage: python3 hot_methods_locator.py <path-to-project> [inspect-method]
# If inspect-method is not given, then the script will find all hot methods in path-to-project
# If it is given, then the script will output the stats of the given hot method
# It includes # of events and traces in hot method,
# test and number of related traces in that test (at least 1 event in the trace is in hot method),
# and test and number of isolated related traces in that test (all events in the trace are in hot method).
#
import os
import re
import csv
import sys
from pathlib import Path
from collections import defaultdict


REDUCED = False

def get_all_traces(project_path):
    # Load unique traces and map into memory
    path = Path(os.path.join(project_path, '.all-traces'))
    if not os.path.isdir(path):
        traces_lines, map_lines = get_traces_from_dir(project_path)
        if traces_lines is not None and map_lines is not None:
            return {'tests': traces_lines}, {'tests': map_lines}
        return {}, {}
    
    tests = [directory for directory in path.iterdir() if directory.is_dir()]
    
    # Only care about reduced tests
    if REDUCED:
        with open(os.path.join(project_path, 'reduced_tests.txt')) as f:
            reduced_tests = [test.strip() for test in f.readlines()]
        tests = [test for test in tests if test.name in reduced_tests]
        
    traces = {}	# {test: [frequency, trace]}
    location_map = {} # {test: [location]}
    
    for test in tests:
        traces_lines, map_lines = get_traces_from_dir(test)
        if traces_lines is not None and map_lines is not None:
            traces[test.name] = traces_lines
            location_map[test.name] = map_lines
    return traces, location_map


def get_traces_from_dir(dir):
    unique_traces_file = os.path.join(dir, 'unique-traces.txt')
    locations_file = os.path.join(dir, 'locations.txt')
    if os.path.isfile(unique_traces_file) and os.path.isfile(locations_file):
        with open(unique_traces_file) as f:
            traces_started = False
            traces_lines = []
            for line in f.readlines():
                line = line.strip();
                if traces_started:
                    if line:
                        traces_lines.append(line)
                    else:
                        # Empty line means it is EOF
                        break
                elif line == '=== UNIQUE TRACES ===':
                    traces_started = True
        with open(locations_file) as f:
            map_started = False
            map_lines = []
            for line in f.readlines():
                line = line.strip();
                if map_started:
                    if line:
                        map_lines.append(line)
                    else:
                        # Empty line means it is EOF
                        break
                elif line == '=== LOCATION MAP ===':
                    map_started = True
        return traces_lines, map_lines
    return None, None


def process_traces(tests_traces_str, tests_locations_str):
    # tests_traces_str: Given {test: [frequency, trace]}, return {test: [counters]}
    tests_traces_counters = {}  # {test: {event: frequency}}
    tests_traces= {}            # {test: [(events, frequency)]}
    total_events = 0
    total_traces = 0
    
    for test, traces_str in tests_traces_str.items():
        # test: test name
        # traces_str: [trace_str1, trace_str2, ...]
        counters = {}   # {event: frequency}
        traces = []     # [(events, frequency)]
        for trace_str in traces_str:
            # For example, if trace_str is "2 [next~1, next~1, next~1, next~1, next~2]",
            # add {next~1: 8, next~2: 2} to result
            match = re.match('^(\d+) \[(.*)\]$', trace_str)
            if match and match.group(2):
                # Non-empty events
                frequency = int(match.group(1))
                events = match.group(2).split(', ')
                traces.append((events, frequency))
                total_traces += frequency
                
                for event in events:
                    counters[event] = counters.get(event, 0) + frequency
                    total_events += frequency
        tests_traces_counters[test] = counters
        tests_traces[test] = traces

    # tests_locations_str: Given {test: [location]}, return {test: {location id: line location}}
    for test, locations_str in tests_locations_str.items():
        result = {}
        for location_str in locations_str:
            id, _, line = location_str.partition(' ')
            result[id] = line
        tests_locations_str[test] = result

    print('Total {} events and {} traces'.format(total_events, total_traces))
    return tests_traces_counters, tests_locations_str, tests_traces


def hot_methods(tests_traces_counters, tests_locations_str):
    method_to_frequency = {}    # {method, event frequency}
    method_to_test = {}

    for test, counters in tests_traces_counters.items():
        # test: test name
        # counters: {event: frequency}
        location_id_to_line = tests_locations_str[test]     # {location id: line}
        for event, counter in counters.items():
            # event (i.e., next~1, create~2)
            event_name, _, id = event.partition('~')
            # event name (next, create)
            # id (1, 2)
            method = location_id_to_line.get(id, 'Unknown').split('(')[0]
            # location_id_to_line.get(id) returns package.method(class.java:line-#)
            # method is package.method
            method_to_frequency[method] = method_to_frequency.get(method, 0) + counter
#           if method == 'org.apdplat.word.util.AutoDetector.load':
#               print(test, event, counter)
            if method not in method_to_test:
                method_to_test[method] = set()
            method_to_test[method].add(test)
    
    for method_freq in sorted(method_to_frequency.items(), key=lambda x:x[1], reverse=True):
        print('{}, {}, {}'.format(method_freq[1], method_freq[0], len(method_to_test[method_freq[0]])))


def inspect_method(hot_method, tests_traces, tests_locations_str):
    related_traces_all = {}
    related_traces_isolated_all = {}
    total_number_related_events = 0
    total_number_related_traces = 0
    total_number_isolated_traces = 0
    for test, locations in tests_locations_str.items():
        # locations: {location id: line}
        related_id = set()
        for location_id, location_line in locations.items():
            if location_line.startswith(hot_method + '('):
                related_id.add(location_id)
        
        traces = tests_traces[test]
        related_traces = []
        for trace in traces:
            for event in trace[0]:
                event_name, _, id = event.partition('~')
                if id in related_id:
                    related_traces.append(trace)
                    break
        related_isolated_traces = []
        for related_trace in related_traces:
            total_number_related_traces += related_trace[1]
            # related_trace is in related_isolated_traces if all events are in related_id
            isolated = True
            for event in related_trace[0]:
                event_name, _, id = event.partition('~')
                if id not in related_id:
                    isolated = False
                else:
                    total_number_related_events += related_trace[1]

            if isolated:
                related_isolated_traces.append(related_trace)
                total_number_isolated_traces += related_trace[1]

        related_traces_all[test] = related_traces
        related_traces_isolated_all[test] = related_isolated_traces
    
    print('{},{},{}'.format(total_number_related_events, total_number_related_traces, total_number_isolated_traces))
    print('Total {} events are in hot method'.format(total_number_related_events))
    print('Total {} traces are in hot method'.format(total_number_related_traces))
    print('Total {} isolated traces are in hot method'.format(total_number_isolated_traces))
    
    # Regular related traces
    total_number_related_traces = 0
    related_tests = set()
    for test, related_traces in related_traces_all.items():
        if len(related_traces) > 0:
            total_number_related_traces += len(related_traces)
            related_tests.add(test)
            print('{} has {} related traces'.format(test, len(related_traces)))
    print('Total {} tests has total of {} unique related traces'.format(len(related_tests), total_number_related_traces))

    # Isolated related traces
    total_number_related_traces = 0
    related_tests = set()
    for test, related_traces in related_traces_isolated_all.items():
        if len(related_traces) > 0:
            total_number_related_traces += len(related_traces)
            related_tests.add(test)
            print('{} has {} isolated related traces'.format(test, len(related_traces)))
    print('Total {} tests has total of {} unique isolated related traces'.format(len(related_tests), total_number_related_traces))


def main(argv=None):
    argv = argv or sys.argv
    
    if len(argv) < 2:
        print('Usage: python3 hot_methods_locator.py <path-to-project> [inspect-method]')
        exit(1)
 
    tests_traces_str, tests_locations_str = get_all_traces(argv[1])
    tests_traces_counters, tests_locations_str, tests_traces = process_traces(tests_traces_str, tests_locations_str)
    
    if len(argv) == 2:
        hot_methods(tests_traces_counters, tests_locations_str)
    else:
        inspect_method(argv[2], tests_traces, tests_locations_str)
 

if __name__ == '__main__':
    csv.field_size_limit(sys.maxsize)
    main()

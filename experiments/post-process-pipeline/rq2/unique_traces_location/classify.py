#!/usr/bin/env python3
import os
import sys

if len(sys.argv) < 3 or not os.path.isdir(sys.argv[1]):
    print('Usage: python3 classify.py <project-dir> <project-name>')
    exit(1)

if not os.path.isfile(os.path.join(sys.argv[1], 'projects', sys.argv[2], '.all-traces', 'unique-traces.txt')):
    print('cannot find unique-traces.txt')
    exit(1)

if not os.path.isfile(os.path.join(sys.argv[1], 'projects', sys.argv[2], '.all-traces', 'locations.txt')):
    print('cannot find locations.txt')
    exit(1)
    
if not os.path.isfile(os.path.join(sys.argv[1], 'logs', 'packages.txt')):
    print('cannot find packages.txt')
    exit(1)


def open_packages():
    packages = []
    with open(os.path.join(sys.argv[1], 'logs', 'packages.txt')) as f:
        for package in f.readlines():
            package = package.strip()
            if package:
                packages.append(package)
    return packages


def open_locations(packages):
    project_location_id = set()
    
    with open(os.path.join(sys.argv[1], 'projects', sys.argv[2], '.all-traces', 'locations.txt')) as f:
        header = False
        for line in f.readlines():
            line = line.strip()
            if not header:
                header = True
                continue
            short_location, _, long_location = line.partition(' ')
            for package in packages:
                if long_location.startswith(package):
                    project_location_id.add(short_location)
                    break

    return project_location_id


def check_unique(project_location_id):
    stats = {-1: 0, 0: 0, 1: 0, 2: 0}
    stats_included_freq = {-1: 0, 0: 0, 1: 0, 2: 0}
    total = 0
    total_included_freq = 0

    with open(os.path.join(sys.argv[1], 'projects', sys.argv[2], '.all-traces', 'unique-traces.txt')) as f:
        header = False
        for line in f.readlines():
            line = line.strip()
            if not header:
                header = True
                continue

            trace_category = -1 # -1: unknown, 0: in project only, 1: in lib only, 2: mixed
            freq, _, unique_trace = line.partition(' ')
            if len(unique_trace) >= 2:
                unique_trace = unique_trace[1:-1]
            for event in unique_trace.split(', '):
                name, _, id = event.partition('~')
                if id:
                    if id in project_location_id:
                        if trace_category == -1:
                            # current category: unknown, see project, new category: project only
                            trace_category = 0
                        elif trace_category == 1:
                            # current category: lib, see project, new category: mixed
                            trace_category = 2
                            break
                    else:
                        if trace_category == -1:
                            # current category: unknown, see lib, new category: lib only
                            trace_category = 1
                        elif trace_category == 0:
                            # current category: project, see lib, new category: mixed
                            trace_category = 2
                            break
            stats[trace_category] = stats[trace_category] + 1
            stats_included_freq[trace_category] = stats_included_freq[trace_category] + int(freq)
            total += 1
            total_included_freq += int(freq)
    print('{},{},{},{},{},{},{},{},{},{}'.format(stats[-1], stats[0], stats[1], stats[2], total, stats_included_freq[-1], stats_included_freq[0], stats_included_freq[1], stats_included_freq[2], total_included_freq))

check_unique(open_locations(open_packages()))

#!/usr/bin/env python3
import os
import sys

if len(sys.argv) < 3 or not os.path.isdir(sys.argv[1]):
    print('Usage: python3 count_traces_with_events_in_loop.py <project-output-dir> <project-name>')
    exit(1)

if not os.path.isfile(os.path.join(sys.argv[1], sys.argv[2], 'projects', sys.argv[2], '.all-traces', 'unique-traces.txt')):
    print('cannot find unique-traces.txt')
    exit(1)

if not os.path.isfile(os.path.join(sys.argv[1], sys.argv[2], 'projects', sys.argv[2], '.all-traces', 'locations.txt')):
    print('cannot find locations.txt')
    exit(1)

if not os.path.isfile(os.path.join(sys.argv[1], sys.argv[2], 'projects', sys.argv[2], '.all-traces', 'locations-in-loop.txt')):
    print('cannot find locations-in-loop.txt')
    exit(1)

if not os.path.isfile(os.path.join(sys.argv[1], sys.argv[2], 'logs', 'packages.txt')):
    print('cannot find packages.txt')
    exit(1)


def open_packages():
    packages = []
    with open(os.path.join(sys.argv[1], sys.argv[2], 'logs', 'packages.txt')) as f:
        for package in f.readlines():
            package = package.strip()
            if package:
                packages.append(package)
    return packages


def open_locations(packages):
    project_location_id = set()
    
    with open(os.path.join(sys.argv[1], sys.argv[2], 'projects', sys.argv[2], '.all-traces', 'locations.txt')) as f:
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


def open_loop_locations():
    ids = set()
    with open(os.path.join(sys.argv[1], sys.argv[2], 'projects', sys.argv[2], '.all-traces', 'locations-in-loop.txt')) as f:
        for line in f.readlines():
            line = line.strip()
            if line:
                ids.add(line.partition(' ')[0])
    return ids


def check_events_location(project_location_id, loop_ids):
    unique_traces_categories = {-1: 0, 0: 0, 1: 0, 2: 0}
    traces_categories = {-1: 0, 0: 0, 1: 0, 2: 0}
    
    unique_traces_total = 0
    traces_total = 0
    
    unique_events_in_loop = 0
    events_in_loop = 0
    
    unique_events_outside_loop = 0
    events_outside_loop = 0

    with open(os.path.join(sys.argv[1], sys.argv[2], 'projects', sys.argv[2], '.all-traces', 'unique-traces.txt')) as f:
        header = False
        for line in f.readlines():
            line = line.strip()
            if not header:
                header = True
                continue

            trace_category = -1 # -1: unknown, 0: in project only, 1: in lib only, 2: mixed
            trace_category_loop = -1 # -1: unknown, 0: only in loop, 1: only outside loop, 2: mixed

            freq, _, unique_trace = line.partition(' ')
            freq = int(freq)
            if len(unique_trace) >= 2:
                unique_trace = unique_trace[1:-1]

            processed_events = []
            for event in unique_trace.split(', '):
                name, _, id = event.partition('~')
                processed_events.append((name, id))
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
                
            if trace_category == 0:
                # Only check event if trace is in project only
                for event in processed_events:
                    name, id = event
                    if id:
                        if id in loop_ids:
                            if trace_category_loop == -1:
                                # current unknown, see event in loop, new category: in loop only
                                trace_category_loop = 0
                            elif trace_category_loop == 1:
                                # current category: outside loop, see loop, new category: mixed
                                trace_category_loop = 2
        
                            unique_events_in_loop += 1
                            events_in_loop += freq
                        else:
                            if trace_category_loop == -1:
                                # current unknown, see outside loop, new category: outside
                                trace_category_loop = 1
                            elif trace_category_loop == 0:
                                # current in loop, see outside loop, new category: mixed
                                trace_category_loop = 2
                            
                            unique_events_outside_loop += 1
                            events_outside_loop += freq

                unique_traces_categories[trace_category_loop] = unique_traces_categories[trace_category_loop] + 1
                traces_categories[trace_category_loop] = traces_categories[trace_category_loop] + freq
                unique_traces_total += 1
                traces_total += freq
    print('{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}'.format(
        sys.argv[2],
        unique_traces_categories[-1], # unknown
        unique_traces_categories[0], # unique traces only have events in loop
        unique_traces_categories[1], # only have events outside loop
        unique_traces_categories[2], # mixed
        unique_traces_total, # number of unique traces in project only
        unique_events_in_loop, # number of events in loop
        unique_events_outside_loop, # number of events outside loop
        traces_categories[-1],
        traces_categories[0],
        traces_categories[1],
        traces_categories[2],
        traces_total,
        events_in_loop,
        events_outside_loop
    ))

check_events_location(open_locations(open_packages()), open_loop_locations())

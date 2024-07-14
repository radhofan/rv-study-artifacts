#!/usr/bin/env python3
#
# Check run_hot_methods_experiments.sh's output
# Usage: python3 process_traces_rq2.py <output-dir> <projects-list> [without-raw]
#
import os
import sys

if len(sys.argv) < 3 or not os.path.isdir(sys.argv[1]) or not os.path.isfile(sys.argv[2]):
   print('Usage: python3 process_traces_rq2.py <output-dir> <projects-list> [without-raw]')
   exit(1)


without_raw = len(sys.argv) == 4 and sys.argv[3] == 'true'


def check_files(output_dir, project):
  number_of_traces = -1
  number_of_unique_traces = -1

  number_of_traces_based_on_unique = 0
  number_of_unique_traces_based_on_unique = 0

  number_of_events_based_on_unique = 0
  number_of_unique_events_based_on_unique = 0

  duplicated_traces = 0
  duplicated_events = 0

  f = os.path.join(output_dir, project, 'docker.log')
  with open(f) as file:
    if 'end get_hot_methods' not in file.read():
      print('{},pipeline failed'.format(project))
      return

  f = os.path.join(output_dir, project, 'projects', project, '.all-traces', 'locations.txt')
  if not os.path.isfile(f) or os.path.getsize(f) <= 0:
    print('{},no location'.format(project))
    return
  
  f = os.path.join(output_dir, project, 'projects', project, '.all-traces', 'traces.txt')
  if not os.path.isfile(f) or os.path.getsize(f) <= 0:
    print('{},no traces'.format(project))
    return
  
  with open(f) as file:
    for line in file.readlines():
      line = line.strip()
      if 'Total number of traces' in line:
        _, _, number_of_traces = line.rpartition(' ')
      elif 'Total number of unique traces' in line:
        _, _, number_of_unique_traces = line.rpartition(' ')
  
  f = os.path.join(output_dir, project, 'projects', project, '.all-traces', 'unique-traces-noraw.txt' if without_raw else 'unique-traces.txt')
  if not os.path.isfile(f) or os.path.getsize(f) <= 0:
    print('{},no unique traces'.format(project))
    return
  
  with open(f) as file:
    header = False
    for line in file.readlines():
      line = line.strip()
      if not header:
        header = True
        continue

      if line:
        freq, _, trace = line.partition(' ')
        freq = int(freq)
        trace_length = len(trace.split(','))

        number_of_unique_traces_based_on_unique += 1
        number_of_traces_based_on_unique += freq

        number_of_unique_events_based_on_unique += trace_length
        number_of_events_based_on_unique += freq * trace_length
        
        if freq > 1:
          duplicated_traces += (freq - 1)
          duplicated_events += (freq - 1) * trace_length

  print('{},{},{},{},{},{},{},{},{}'.format(
                                            project, number_of_traces, number_of_unique_traces, number_of_traces_based_on_unique, number_of_unique_traces_based_on_unique,
                                            number_of_events_based_on_unique, number_of_unique_events_based_on_unique, duplicated_traces, duplicated_events
                                            ))


def check_all():
  print('project,number of traces,number of unique traces,number of traces based on unique file,number of unique traces based on unique file,number of events,number of unique events,duplicated traces,duplicated events')
  with open(sys.argv[2]) as file:
    for line in file.readlines():
      line = line.strip()
      if line:
        try:
          check_files(sys.argv[1], line)
        except:
          print('{},error'.format(line))

check_all()

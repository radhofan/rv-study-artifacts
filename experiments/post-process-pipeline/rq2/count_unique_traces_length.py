#!/usr/bin/env python3
#
# Count how many events the unique traces have
# Usage: python3 count_unique_traces_length.py <output-dir> <projects-list> <new-output-dir>
#
import os
import sys
from collections import defaultdict 

if len(sys.argv) < 4 or not os.path.isdir(sys.argv[1]) or not os.path.isfile(sys.argv[2]) or not os.path.isdir(sys.argv[3]):
   print('Usage: python3 count_unique_traces_length.py <output-dir> <projects-list> <new-output-dir>')
   exit(1)


def count_length(output_dir, project):
  project_data = []

  f = os.path.join(output_dir, project, 'docker.log')
  with open(f) as file:
    if 'end get_hot_methods' not in file.read():
      print('{},pipeline failed'.format(project))
      return

  f = os.path.join(output_dir, project, 'projects', project, '.all-traces', 'unique-traces.txt')
  if not os.path.isfile(f) or os.path.getsize(f) <= 0:
    print('{},no unique traces'.format(project))
    return

  total_unique_traces_length = 0
  num_unique_traces = 0
  with open(f) as file:
    header = False
    for line in file.readlines():
      line = line.strip()
      if not header:
        header = True
        continue

      if line:
        freq, _, trace = line.partition(' ')
        trace_length = len(trace.split(','))
        total_unique_traces_length += trace_length
        num_unique_traces += 1
        
        project_data.append(str(trace_length) + ',' + freq + '\n')

  print(project + ',' + str(round(total_unique_traces_length / num_unique_traces, 3)))
  return project_data


def check_all():
  with open(sys.argv[2]) as file:
    for line in file.readlines():
      line = line.strip()
      if line:
        try:
          with open(os.path.join(sys.argv[3], line + '.csv'), 'w') as f:
            f.writelines(count_length(sys.argv[1], line))
        except:
          print('{},error'.format(line))

check_all()

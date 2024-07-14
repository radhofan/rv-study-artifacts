#!/usr/bin/env python3
#
# Given locations.txt, list all short locations that are within loop
# Usage: python3 locations_within_loop.py <project-output-dir> <project-name>
#
import os
import sys
import subprocess
from collections import defaultdict

script_dir = os.path.dirname(os.path.realpath(__file__))

if len(sys.argv) < 3 or not os.path.isdir(sys.argv[1]) or not os.path.isdir(os.path.join(sys.argv[1], sys.argv[2], 'projects', sys.argv[2], '.all-traces')):
   print('Usage: python3 locations_within_loop.py <project-output-dir> <project-name>')
   exit(1)

if not os.path.isfile(os.path.join(sys.argv[1], sys.argv[2], 'projects', sys.argv[2], '.all-traces', 'locations.txt')):
  print('Cannot find locations.txt')
  exit(1)


if os.path.exists(os.path.join(sys.argv[1], sys.argv[2], 'projects', sys.argv[2], '.all-traces', 'locations-in-loop.txt')):
  exit(1)


def get_project_packages():
  packages = []
  if os.path.exists(os.path.join(sys.argv[1], sys.argv[2], 'logs', 'packages.txt')):
    with open(os.path.join(sys.argv[1], sys.argv[2], 'logs', 'packages.txt')) as f:
      for package in f.readlines():
        package = package.strip()
        if package:
          packages.append(package)
  return packages


def open_locations(packages):
  id_to_location = {}
  package_to_file_to_shorts = defaultdict(lambda: defaultdict(list))

  try:
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
            method, _, filename_linenum = long_location.partition('(')
            filename_linenum = filename_linenum.strip(')')
            
            if filename_linenum == 'Unknown Source':
              break

            filename, _, linenum = filename_linenum.partition(':')
            package = '.'.join(method.split('.')[:-2])

            if not filename.endswith('.java') or linenum == '':
              break

            id_to_location[short_location] = {'package': package, 'filename': filename, 'line': int(linenum), 'orig': line}
            package_to_file_to_shorts[package][filename].append(short_location)
            break
  except Exception as e:
    print(e)
    print('{},error in locations.txt'.format(sys.argv[2]))
    exit(1)

  return id_to_location, package_to_file_to_shorts


def main():
  packages = get_project_packages()
  id_to_location, package_to_file_to_shorts = open_locations(packages)
  line_in_loop = []

  for package in package_to_file_to_shorts.keys():
    for filename in package_to_file_to_shorts[package].keys():
      ranges = []
      try:
        proc = result = subprocess.run(['bash', 'find_file.sh', os.path.join(sys.argv[1], sys.argv[2], 'projects', sys.argv[2]), package, filename], capture_output=True, cwd=script_dir, text=True)
        for loop in proc.stdout.split('\n'):
          if '.' in loop:
            start, end = loop.split('.')
            ranges.append((int(start), int(end)))
      except:
        print('{},error in file {} and package {}'.format(sys.argv[2], filename, package))

      for short_location in package_to_file_to_shorts[package][filename]:
        # check if short_location is in a ranges
        linenum = id_to_location[short_location]['line']
        for r in ranges:
          if r[0] <= linenum <= r[1]:
            line_in_loop.append(id_to_location[short_location]['orig'])

  with open(os.path.join(sys.argv[1], sys.argv[2], 'projects', sys.argv[2], '.all-traces', 'locations-in-loop.txt'), 'w') as f:
      f.writelines([line + '\n' for line in line_in_loop])
  print('{},found {} locations in loop'.format(sys.argv[2], len(line_in_loop)))


if __name__ == "__main__":
  main()

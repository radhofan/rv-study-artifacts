#!/usr/bin/env python3
import os
import sys
from collections import defaultdict

if len(sys.argv) < 3 or not os.path.isdir(sys.argv[1]):
    print('Usage: python3 get_lines_for_files.py <project-output-dir> <project-name>')
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


def open_packages():
    packages = []
    with open(os.path.join(sys.argv[1], sys.argv[2], 'logs', 'packages.txt')) as f:
        for package in f.readlines():
            package = package.strip()
            if package:
                packages.append(package)
    return packages


def open_locations(packages):
    class_to_lines = defaultdict(list)
    
    with open(os.path.join(sys.argv[1], sys.argv[2], 'projects', sys.argv[2], '.all-traces', 'locations-in-loop.txt')) as f:
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
                    
                    filename, _, linenum = filename_linenum.partition(':')

                    if not filename.endswith('.java') or linenum == '':
                        break
                    
                    class_name = method.split('.')[-2]
                    
                    class_to_lines[class_name + '.class' + ',' + filename.replace('.java', '.class')].append(linenum)
                    break

    return class_to_lines

res = open_locations(open_packages())
for klass in res.keys():
    print('{},{}'.format(klass, ','.join(res[klass])))

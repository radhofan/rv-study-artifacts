#!/usr/bin/env python3

import os
import sys

if len(sys.argv) < 4:
    print('Usage: python3 find_changed_jars.py <old-classpath-file> <new-classpath-file> <project-name>')
    exit(1)

old_cp = sys.argv[1]
new_cp = sys.argv[2]
project_name = sys.argv[3]

if not os.path.exists(old_cp) or not os.path.exists(new_cp):
    print('Cannot classpath files')
    exit(1)

old_jar = set()
new_jar = set()

with open(old_cp) as f:
    classpath = f.read()
    for c in classpath.split(':'):
        c = c.strip()
        if c:
            if project_name not in c or 'javamop' in c or 'aspectj' in c or 'rv-monitor' in c or 'scala-lang' in c or not c.endswith('.jar'):
                continue
            old_jar.add(c)

with open(new_cp) as f:
    classpath = f.read()
    for c in classpath.split(':'):
        c = c.strip()
        if c:
            if project_name not in c or 'javamop' in c or 'aspectj' in c or 'rv-monitor' in c or 'scala-lang' in c or not c.endswith('.jar'):
                continue
            new_jar.add(c)

for jar in new_jar.difference(old_jar):
    print(jar)

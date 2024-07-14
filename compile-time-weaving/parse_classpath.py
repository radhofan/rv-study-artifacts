#!/usr/bin/env python3

import os
import sys

if len(sys.argv) < 2 or not os.path.isfile(sys.argv[1]):
    print('Usage: python3 parse_classpath.py <path-to-classpath-file>')
    exit(1)

jars = set()
with open(sys.argv[1]) as f:
    classpath = f.read().strip().replace('.jar/', '.jar:/')
    for jar in classpath.split(':'):
        jars.add(jar)

with open(sys.argv[1], 'w') as f:
    f.write(':'.join(jars))

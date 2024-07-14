#!/usr/bin/env python3

import sys

with open(sys.argv[1]) as f:
    for line in f.readlines():
        line = line.strip()
        if not line:
            continue
        line = line.split(',')[0]
        if '$' in line:
            klass = line.split('$')[0]
        else:
            klass = line.rpartition('.')[0]
        print(klass)

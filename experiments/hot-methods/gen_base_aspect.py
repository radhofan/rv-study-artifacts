#!/usr/bin/env python3
#
# Given a top5.csv, generate a BaseAspect_new.aj file that excludes hot methods
# Usage: python3 gen_base_aspect.py <csv-file> <dest-file>
# Output: a file in dest-file
#
import os
import re
import sys
import csv


def get_hot_methods(csv_path):
    if not os.path.exists(csv_path):
        return []
    
    hot_methods = []
    with open(csv_path) as f:
        reader = csv.reader(f)
        for line in reader:
            hot_methods.append(line[0])
    return hot_methods


def get_pointcut(method):
    if method.endswith('.<clinit>'):
        # static initialization block
        return None
    # match methods that contains $<number>
    if re.search('\$\d+', method):
        # anonymous
        return None

    pointcut = method.replace('$', '.')
    if pointcut.endswith('.<init>'):
        pointcut = '!withincode({})'.format(pointcut.replace('.<init>', '.new(..)'))
    else:
        pointcut = '!withincode(* {}(..))'.format(pointcut)
    return pointcut

    
def generate(csv_path, dest_path, current_pointcut):
    hot_methods = get_hot_methods(csv_path)
    
    pointcuts = current_pointcut
    skipped_methods = []
    
    for hot_method in hot_methods:
        pointcut = get_pointcut(hot_method)
        if not pointcut:
            print('Skip method {}'.format(hot_method))
            skipped_methods.append(hot_method)
        else:
            pointcuts.append(pointcut)

    if not pointcuts:
        print('Failed to generate any pointcut')
        exit(1)

    file_line = '''package mop;
/*
    Failed to generate pointcut for the following method(s):
    {}
*/
public aspect BaseAspect {{
    pointcut notwithin() :
    !within(sun..*) &&
    !within(java..*) &&
    !within(javax..*) &&
    !within(javafx..*) &&
    !within(com.sun..*) &&
    !within(org.dacapo.harness..*) &&
    !within(net.sf.cglib..*) &&
    !within(mop..*) &&
    !within(org.h2..*) &&
    !within(org.sqlite..*) &&
    !within(org.aspectj..*) &&
    !within(edu.rvpaper..*) &&
    !within(javamoprt..*) &&
    !within(rvmonitorrt..*) &&
    !within(org.junit..*) &&
    !within(junit..*) &&
    !within(java.lang.Object) &&
    !within(com.runtimeverification..*) &&
    !within(org.apache.maven.surefire..*) &&
    !within(org.mockito..*) &&
    !within(org.powermock..*) &&
    !within(org.easymock..*) &&
    !within(com.mockrunner..*) &&
    !within(org.jmock..*) &&
    !within(org.apache.maven..*) &&
    !within(org.testng..*) &&
    ({});
}}'''.format(', '.join(skipped_methods), ' && '.join(pointcuts))

    with open(dest_path, 'w') as f:
        f.write(file_line)


def main(argv=None):
    argv = argv or sys.argv
    
    if len(argv) != 3 and len(argv) != 4:
        print('Usage: python3 gen_base_aspect.py <csv-file> <dest-file> [pointcuts-file]')
        exit(1)
        
    if not os.path.isfile(argv[1]):
        print('Cannot find csv file {}'.format(argv[1]))
        exit(1)

    pointcuts = []
    if len(argv) == 4 and os.path.exists(argv[3]):
        with open(argv[3]) as f:
            for line in f.readlines():
                line = line.strip()
                if line:
                    pointcuts.append(line)

    generate(argv[1], argv[2], pointcuts)
    
    
if __name__ == '__main__':
    main()

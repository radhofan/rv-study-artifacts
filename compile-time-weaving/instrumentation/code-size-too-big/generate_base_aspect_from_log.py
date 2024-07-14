#!/usr/bin/env python3
#
# Search all methods that have code size too big error, then create a BaseAspect file to exclude them
#
import os
import re
import sys


def get_pointcut(method, classes):
    if method.endswith('.<clinit>'):
        # static initialization block
        klass = method.replace('.<clinit>', '')
        
        if klass in classes:
            # Class is loaded, cannot skip class
            return None
        else:
            klass = klass.replace('$', '.')
            return '!within({})'.format(klass)
    # match methods that contains $<number>
    if re.search('\$\d+', method):
        # anonymous, cannot handle
        return None
    
    pointcut = method.replace('$', '.')
    if pointcut.endswith('.<init>'):
        pointcut = '!withincode({})'.format(pointcut.replace('.<init>', '.new(..)'))
    else:
        pointcut = '!withincode(* {}(..))'.format(pointcut)
    return pointcut


def get_pointcut_for_class(klass, classes):
    if klass in classes:
        # Class is loaded, cannot skip class
        return None
    else:
        klass = klass.replace('$', '.')
        return '!within({})'.format(klass)


def generate(previous_attempt_log, classes, output_file):
    methods = []
    exclude_classes = []
    pointcuts = []

    with open(previous_attempt_log, 'r') as f:
        for line in f.readlines():
            line = line.strip()
            match = re.search('problem generating method (.*) : Code size too big', line)
            if match:
                found = re.sub('\$\d+', '', match.group(1))
                if found not in methods:
                    methods.append(found)
                continue

            match = re.search('when weaving type (.*)', line)
            if match:
                found = re.sub('\$\d+', '', match.group(1))
                if found not in methods:
                    exclude_classes.append(found)
                continue

            match = re.search('Unexpected problem whilst preparing bytecode for (.*)', line)
            if match:
                # example:
                # Unexpected problem whilst preparing bytecode for com.thoughtworks.qdox.parser.impl.Parser.yyparse()I
                # append `com.thoughtworks.qdox.parser.impl.Parser.yyparse` to methods
                found = re.sub('\$\d+', '', match.group(1).split('(')[0])
                if found not in methods:
                    methods.append(found)
                continue

    if not methods and not exclude_classes:
        print('Cannot find any method to skip')
        eixt(1)

    for method in methods:
        pointcut = get_pointcut(method, classes)

        if not pointcut:
            print('Cannot fix method {}'.format(method))
            eixt(1)

        pointcuts.append(pointcut)

    for exclude_class in exclude_classes:
        pointcut = get_pointcut_for_class(exclude_class, classes)
        if not pointcut:
            print('Cannot fix method {}'.format(method))
            exit(1)

        pointcuts.append(pointcut)

    file_line = '''//{}
package mop;
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
}}'''.format(' && '.join(pointcuts), ' && '.join(pointcuts))
    with open(output_file, 'w') as f:
        f.write(file_line)


def main(argv=None):
    argv = argv or sys.argv

    if len(argv) < 4:
        print('Usage: python3 generate_base_aspect_from_log.py <log> <classes> <output-base-aspect>')
        exit(1)

    previous_attempt_log = argv[1]
    classes_file = argv[2]
    output_file = argv[3]
    
    if not os.path.exists(previous_attempt_log):
        print('Cannot find log file')
        exit(1)
    
    if not os.path.exists(classes_file):
        print('Cannot find classes_file')
        exit(1)
    
    classes = set()
    with open(classes_file, 'r') as f:
        for line in f.readlines():
            line = line.strip()
            if line:
                # Ex: replace a.b.c$2 with a.b.c
                classes.add(re.sub('\$\d+', '', line))

    generate(previous_attempt_log, classes, output_file)


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
#
# Given a log, return build status, maven build time, test time, # test count, and # test failed
# Usage: python3 check_time_and_test.py <log-file>
#
import os
import re
import sys


if len(sys.argv) != 2:
  print('Usage: python3 check_time_and_test.py <log-file>')
  exit(1)
  
  
if not os.path.exists(sys.argv[1]):
  print('Cannot find log file')
  exit(1)


def convert_maven_time_to_seconds(string):
  match = re.search(r'((\d+)(\.\d*)?) s', string, re.M)
  if match:
    return round(float(match.group(1)), 2)
  match = re.search(r'(\d+):(\d+) min', string, re.M)
  if match:
    return int(match.group(1)) * 60 + int(match.group(2))
  return 0


def parse_log():
  status = 'unknown'
  tests_run = 0
  tests_failed = 0
  test_time = 0
  total_time = 0
  is_maven_summary = 0
  
  with open(sys.argv[1], 'r', errors='ignore') as f:
    for line in f.readlines():
      line = line.strip()
      match = re.search(r'Tests run: .*? Time elapsed: (.* s(ec)?)', line, re.M)
      if match:
        test_time += convert_maven_time_to_seconds(match.group(1))
        continue
      
      match = re.search(r'Tests run: (\d*), Failures: (\d*), Errors: (\d*)(, Skipped: (\d*))?', line, re.M)
      if match:
        tests_run += int(match.group(1))
        tests_failed += (int(match.group(2)) + int(match.group(3)))
        continue
      
      match = re.search(r'^Total tests run: (\d+), Failures: (\d+), Skips: (\d+)', line, re.M)
      if match:
        tests_run += int(match.group(1))
        tests_failed += int(match.group(2))
        continue

      if 'Could not find or load main class' in line:
        status = 'surefire failed'

      if 'Could not resolve dependencies' in line or 'Could not find artifact' in line or 'Could not transfer artifact' in line:
        status = 'missing dependency'
  
      if 'java.lang.OutOfMemoryError' in line:
        status = 'OOM'

      """
      [INFO] ------------------------------------------------------------------------
      [INFO] BUILD FAILURE
      [INFO] ------------------------------------------------------------------------
      [INFO] Total time:  21.179 s
      [INFO] Finished at: 2024-02-22T08:25:06Z
      [INFO] ------------------------------------------------------------------------
      """
      if '----------------------------------------------------------' in line:
        if is_maven_summary == 0:
          is_maven_summary = 1
        elif is_maven_summary == 1:
          is_maven_summary = 2
        else:
          is_maven_summary = 0
      elif is_maven_summary == 1:
        if 'BUILD SUCCESS' in line:
          if status == 'unknown':
            status = 'passed'
        elif 'BUILD FAILURE' in line:
          if status == 'unknown':
            status = 'failed'
        else:
          is_maven_summary = 0
      else:
        match = re.search(r'Total time: (.+)', line, re.I)
        if match:
          total_time += convert_maven_time_to_seconds(match.group(1))
    print('{},{},{},{},{}'.format(status, round(total_time, 3), round(test_time, 3), tests_run, tests_failed))


parse_log()

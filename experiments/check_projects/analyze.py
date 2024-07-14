#!/usr/bin/env python3
import json
import csv
import re

def check_time(path):
    with open(path, 'r') as f:
        for line in reversed(f.readlines()):
            if line.startswith('[INFO] Total time:'):
                x = line.split(' ')[4]
                if ':' in x:
                    return float(x.split(':')[0]) * 60 + int(x.split(':')[1])
                return float(x)
    return -1


def check_test_run(path):
    with open(path, 'r') as f:
        for line in reversed(f.readlines()):
            match = re.search('Tests run: (\d+),', line)
            if match:
                return match.group(1)
    return -1


def check_event_monitors(path):
    events = 0
    monitors = 0
    violations = 0
    failure = False
    started = False
    with open(path, 'r') as f:
        for line in f.readlines():
            line = line.strip()
            if 'There are test failures.' in line:
                failure = True
            if not started and line[:7] == '==start':
                started = True
            elif started and line[:5] == '==end':
                started = False
            elif started:
                if line.startswith('#monitors: '):
                    monitors += int(line.split(' ')[1])
                if line.startswith('#event'):
                    events += int(line.split(' ')[3])
                if line.startswith('#category - prop 1 - '):
                    violations += int(line.split(' ')[6])
    return events, monitors, violations, failure
    

results = []
projects = []
with open('projects.txt', 'r') as f:
    for p in f.readlines():
        if p.strip():
            projects.append(p.strip())


with open('teco-projects.json', 'r') as f:
    data = json.load(f);
    for project in projects:
        for d in data:
            if d['full_name'] == project:
                without_rv = check_time('logs/test-without-rv/{}.log'.format(d['full_name']))
                with_rv = check_time('logs/test-with-rv/{}.log'.format(d['full_name']))
                events, monitors, violations, failure = check_event_monitors('logs/test-with-rv/{}.log'.format(d['full_name']));
                results.append([
                    project,
                    d['estimate_num_test_method'],
                    check_test_run('logs/test-with-rv/{}.log'.format(d['full_name'])),
                    d['sha'],
                    d['date'],
                    without_rv,
                    with_rv,
                    with_rv / without_rv,
                    monitors,
                    events,
                    violations,
                    failure
                ])
                break

with open('stats.csv', 'w', newline='') as f:
    writer = csv.writer(f)
    for result in results:
        writer.writerow(result)

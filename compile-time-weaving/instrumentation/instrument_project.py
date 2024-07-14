#!/usr/bin/env python3
#
# Instrument project
# Given project, instrument both code and jars
#
import os
import csv
import sys
import threading
import subprocess
from multiprocessing import Pool


project_name, repo_path, log_dir, classes_file, ajc_dir, threads, project_path = "", "", "", "", "", 20, ""
classpath = ""
script_dir = os.path.dirname(os.path.realpath(__file__))
lock = threading.Lock()
failed = False


def instrument(jar):
    global lock, failed
    print('Instrumenting ' + jar)

    with lock:
        if failed:
            return (False, jar, 'already failed')

    if jar == 'source':
        status = instrument_source()
        if not status:
            with lock:
                failed = True
            return (False, jar, 'failed to instrument source')
    elif jar.endswith('jar'):
        status = instrument_jar(jar)
        if not status:
            with lock:
                failed = True
            return (False, jar, 'failed to instrument jar')
    return (True, jar, 'ok')


def instrument_source():
    status = True
    try:
        with open(os.path.join(log_dir, 'source-process.log'), 'w') as f:
            result = subprocess.run(['bash', 'instrument_source.sh', project_name, repo_path, ajc_dir, log_dir + '/source', classes_file, '', project_path],
                                stdout=f, stderr=subprocess.STDOUT, cwd=script_dir, timeout=3600)
            status = result.returncode == 0
    except Exception as e:
        status = False
    return status


def instrument_jar(jar):
    status = True
    try:
        with open(os.path.join(log_dir, jar.replace('/', '-') + '-process.log'), 'w') as f:
            jar_name = jar.split('/')[-1].rpartition('.')[0]
            result = subprocess.run(['bash', 'instrument_jar.sh', project_name, log_dir + '/' + jar_name, jar, classes_file],
                                stdout=f, stderr=subprocess.STDOUT, cwd=script_dir, timeout=3600)
            status = result.returncode == 0
    except Exception as e:
        status = False
    return status


def start():
    global classpath
    classes = ['source']
    with open(classes_file) as f:
        classpath = f.read()
        for c in classpath.split(':'):
            c = c.strip()
            if c:
                if project_name not in c or 'javamop' in c or 'aspectj' in c or 'rv-monitor' in c or 'scala-lang' in c:
                    print('Skip jar: ' + c)
                    continue
                classes.append(c)
    if not classes:
        print('Cannot find any jar to instrument')
        exit(2)

    with Pool(threads) as pool:
        res = pool.map(instrument, classes)
        with open(os.path.join(log_dir, 'report.csv'), 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerows(res)
        
        exit(3) if any([x[0] == False for x in res]) else exit(0)


def main(argv=None):
    argv = argv or sys.argv

    if len(argv) < 6:
        print('Usage: python3 instrument_project.py <project_name> <repo-path> <log-dir> <classes-file> <aspectjrt> [threads=20] [project-dir]')
        exit(1)
    
    global project_name, repo_path, log_dir, classes_file, ajc_dir, threads, project_path
    project_name = argv[1].replace('/', '-')
    repo_path = argv[2]
    log_dir = argv[3]
    classes_file = argv[4]
    ajc_dir = argv[5]
    threads = int(argv[6]) if len(argv) >= 7 else 20
    project_path = argv[7] if len(argv) >= 8 else os.path.join(script_dir, '..', 'projects', project_name)

    if not os.path.exists(project_path) or not os.path.exists(repo_path):
        print('Cannot find projects or repos directories')
        exit(1)

    if not os.path.exists(classes_file):
        print('Cannot find classes file')
        exit(1)
    
    if not os.path.exists(ajc_dir):
        print('Cannot find aspectjrt')
        exit(1)

    start()

if __name__ == '__main__':
    main()

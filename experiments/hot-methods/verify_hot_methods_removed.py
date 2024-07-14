#!/usr/bin/env python3
#
# Verify run_without_hot_methods.sh removed all hot methods
# Usage: python3 verify_hot_methods_removed.py <csv-dir> <project-dir> <projects-list>
#
import csv
import sys
import os


def get_projects(project_list):
    projects = []
    with open(project_list) as f:
        for project in f.readlines():
            project = project.strip()
            if project:
                projects.append(project)
    return projects


def verify_project(csv_file, location, project):
    hot_methods = []
    with open(csv_file, 'r') as f:
        reader = csv.reader(f)
        for row in reader:
            hot_methods.append(row[0])

    if not os.path.exists(location):
        print(project)
        print('cannot find locations.txt\n')
        return

    problems = []
    with open(location, 'r') as f:
        for line in f.readlines():
            for hot_method in hot_methods:
                if '{}('.format(hot_method) in line:
                    problems.append(hot_method)
    
    if problems:
        print(project)
        print(problems)
        print()


def verify_projects(csv_dir, project_dir, projects):
    for project in projects:
        verify_project(os.path.join(csv_dir, project, 'top5.csv'), os.path.join(project_dir, project, '.traces', 'locations.txt'), project)


def main(argv=None):
    argv = argv or sys.argv
    
    if len(argv) != 4:
        print('Usage: python3 verify_hot_methods_removed.py <csv-dir> <project-dir> <projects-list>')
        exit(1)
    
    if not os.path.exists(argv[1]) or not os.path.exists(argv[2]) or not os.path.exists(argv[3]):
        print('Usage: python3 verify_hot_methods_removed.py <csv-dir> <project-dir> <projects-list>')
        exit(2)
    
    projects = get_projects(argv[3])
    verify_projects(argv[1], argv[2], projects)


if __name__ == '__main__':
    main()

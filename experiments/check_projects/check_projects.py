#!/usr/bin/env python3
import os
import sys
import csv
import json
import shutil
import subprocess
from multiprocessing import Pool

PROJECTS_DIR = 'projects'
LOG_DIR = 'logs'
CLONE_LOG_DIR = 'clone'
COMPILE_LOG_DIR = 'compile'
TEST_LOG_DIR = 'test-without-rv'
TEST_RV_LOG_DIR = 'test-with-rv'
JAVA_AGENT_PATH = '{}/../../mop/agents/stats-agent.jar'.format(os.path.dirname(os.path.realpath(__file__)))
JAVA_EXTENSION_PATH = '{}/../../extensions/javamop-extension-1.0.jar'.format(os.path.dirname(os.path.realpath(__file__)))


def check(repo):
    clone_OK = False
    compile_OK = False
    test_without_rv_OK = False
    test_with_rv_OK = False

    try:
        clone_OK = clone(repo)
        if clone_OK:
            compile_OK = compile(repo)
            if compile_OK:
                test_without_rv_OK = test_without_rv(repo)
                if test_without_rv_OK:
                    test_with_rv_OK = test_with_rv(repo)
                    
        cleanup(repo)
        return (repo['full_name'], int(clone_OK), int(compile_OK), int(test_without_rv_OK), int(test_with_rv_OK))
    except Exception as e:
        print(e)
        return (repo.get('repo', 'unknown-repo'), -1, -1, -1, -1)


def clone(repo):
    # Clone repository
    fullname = repo['full_name']
    print('Cloning repository {}'.format(fullname))
    try:
        with open(os.path.join(LOG_DIR, CLONE_LOG_DIR, '{}.log'.format(fullname)), 'a') as f:
            # Clone repository to projects/repo-name
            result = subprocess.run(['git', 'clone', repo['url'], fullname], stdout=f, stderr=subprocess.STDOUT,
                                    cwd=PROJECTS_DIR, timeout=3*60, env={'GIT_TERMINAL_PROMPT': '0'})
            if result.returncode != 0:
                # Failed to clone repository
                f.write(str(result.returncode))
                return False

            # Reset to sha
            result = subprocess.run(['git', 'checkout', repo['sha']], stdout=f, stderr=subprocess.STDOUT,
                                    cwd=os.path.join(PROJECTS_DIR, fullname), timeout=10)
            f.write(str(result.returncode))
            return result.returncode == 0
    except subprocess.TimeoutExpired:
        print('Failed to clone repository {}'.format(repo['full_name']))
        return False;
    return False


def compile(repo):
    # Run mvn test-compile
    fullname = repo['full_name']
    print('Compiling repository {}'.format(fullname))

    local_repository = os.path.join(PROJECTS_DIR, '.mvn-{}'.format(fullname))
    try:
        with open(os.path.join(LOG_DIR, COMPILE_LOG_DIR, '{}.log'.format(fullname)), 'a') as f:
            # Compile code and test
            result = subprocess.run(['mvn', 'test-compile', '-Dmaven.repo.local={}'.format(local_repository)],
                                    stdout=f, stderr=subprocess.STDOUT, cwd=os.path.join(PROJECTS_DIR, fullname),
                                    timeout=30*60)
            f.write(str(result.returncode))
            return result.returncode == 0
    except subprocess.TimeoutExpired:
        print('Failed to compile repository {}'.format(repo['full_name']))
        return False;
    return False


def test_without_rv(repo):
    # Run mvn test
    fullname = repo['full_name']
    print('Testing repository {}'.format(fullname))

    local_repository = os.path.join(PROJECTS_DIR, '.mvn-{}'.format(fullname))
    try:
        with open(os.path.join(LOG_DIR, TEST_LOG_DIR, '{}.log'.format(fullname)), 'a') as f:
            # Run test
            result = subprocess.run(['mvn', 'test', '-Dmaven.repo.local={}'.format(local_repository)], stdout=f,
                                    stderr=subprocess.STDOUT, cwd=os.path.join(PROJECTS_DIR, fullname), timeout=30*60)
            f.write(str(result.returncode))
            return result.returncode == 0
    except subprocess.TimeoutExpired:
        print('Failed to test repository {}'.format(repo['full_name']))
        return False;
    return False


def test_with_rv(repo):
    fullname = repo['full_name']
    print('Testing (with RV) repository {}'.format(fullname))

    local_repository = os.path.join(PROJECTS_DIR, '.mvn-{}'.format(fullname))
    try:
        log_file = os.path.join(LOG_DIR, TEST_RV_LOG_DIR, '{}.log'.format(fullname))
        with open(log_file, 'a') as f:
            # Install JavaMOP agent
            result = subprocess.run(['mvn', 'install:install-file', '-Dmaven.repo.local={}'.format(local_repository),
                                    '-Dfile={}'.format(JAVA_AGENT_PATH), '-DgroupId=javamop-agent',
                                    '-DartifactId=javamop-agent', '-Dversion=1.0', '-Dpackaging=jar'], stdout=f,
                                    stderr=subprocess.STDOUT, cwd=os.path.join(PROJECTS_DIR, fullname), timeout=30)
            if result.returncode != 0:
                # Failed to install JavaMOP agent
                f.write(str(result.returncode))
                return False

            # Run test with RV
            result = subprocess.run(['mvn', 'test', '-Dmaven.repo.local={}'.format(local_repository),
                                    '-Dmaven.ext.class.path={}'.format(JAVA_EXTENSION_PATH)], stdout=f,
                                    stderr=subprocess.STDOUT, cwd=os.path.join(PROJECTS_DIR, fullname), timeout=30*60)
            if result.returncode != 0:
                f.write(str(result.returncode))
                return False

        with open(log_file, 'a') as f:
            # Verify JavaMOP agent was enabled
            result = subprocess.run(['grep', '-m1', 'URL_SetURLStreamHandlerFactory', log_file], stdout=subprocess.DEVNULL,
                                    stderr=subprocess.DEVNULL, timeout=30)
            f.write(str(result.returncode))
            return result.returncode == 0
    except subprocess.TimeoutExpired:
        print('Failed to test (with RV) repository {}'.format(repo['repo']))
        return False;
    return False


def cleanup(repo):
    fullname = repo['full_name']
    print('Cleaning up repository {}'.format(fullname))

    local_repository = os.path.join(PROJECTS_DIR, '.mvn-{}'.format(fullname))
    if os.path.isdir(local_repository):
        # Delete local repository and ignore error
        shutil.rmtree(local_repository, True)


def create_dirs():
    os.makedirs(PROJECTS_DIR, exist_ok=True)
    os.makedirs(os.path.join(LOG_DIR, CLONE_LOG_DIR), exist_ok=True)
    os.makedirs(os.path.join(LOG_DIR, COMPILE_LOG_DIR), exist_ok=True)
    os.makedirs(os.path.join(LOG_DIR, TEST_LOG_DIR), exist_ok=True)
    os.makedirs(os.path.join(LOG_DIR, TEST_RV_LOG_DIR), exist_ok=True)


def start(projects_json, threads):
    projects = []
    with open(projects_json) as f:
        projects = json.load(f)
        print('Loaded {} projects'.format(len(projects)))

    print('Start checking projects with {} threads'.format(threads))
    with Pool(threads) as pool:
        res = pool.map(check, projects)
        with open('result.csv', 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerows(res)


def main(argv=None):
    argv = argv or sys.argv

    if len(argv) != 3:
        print('Usage: python3 check_projects.py <project-json> <# of threads>')
        exit(1)

    if not os.path.isfile(argv[1]):
        print('Cannot find json file in {}'.format(argv[1]))
        exit(1)
    if not argv[2].isdigit():
        print('{} is not a valid number'.format(argv[2]))

    create_dirs()
    start(argv[1], int(argv[2]))


if __name__ == '__main__':
    main()

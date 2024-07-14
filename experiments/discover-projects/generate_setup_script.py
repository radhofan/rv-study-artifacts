#!/usr/bin/env python3

import re
import os
import sys
import yaml


workflow_file = ""


def parse_jobs(jobs):
    if not isinstance(jobs, dict):
        return []

    jobs_commands = []
    for job_name, job in jobs.items():
        if 'steps' not in job:
            continue

        commands = []
        for step in job['steps']:
            if 'run' not in step:
                continue

            command = step['run']
            if '${{' in command or '${GITHUB_' in command or '$GITHUB_' in command or '${RUNNER_' in command or '$RUNNER_' in command:
                # Cannot handle variable and environment variable
                # We don't need to break right now. If the job doesn't use maven, we won't add it to `jobs_commands`
                commands = None
                continue

            if 'mvn' in command:
                # If a job doesn't use maven, then don't add commands to jobs_commands
                jobs_commands.append(commands)
                break
        
            if commands is not None:
                commands.append(command.strip())

    # Return the first job that uses maven and contain setup command(s)
    for jobs_command in jobs_commands:
        if jobs_command is not None and len(jobs_command) > 0:
            return jobs_command
#       if jobs_commands is not None and len(jobs_command) == 0:
#           global workflow_file
#           print(workflow_file)
    return []


def parse_workflow(workflow_file):
    try:
        with open(workflow_file) as f:
            workflow = yaml.safe_load(f)
            return parse_jobs(workflow.get('jobs'))
    except:
        return []


def main(argv=None):
    argv = argv or sys.argv
    global workflow_file
    
    if len(argv) != 2:
        print('Usage: python3 generate_setup_script.py <workflow-file>')
        exit(1)
        
    workflow_file = argv[1]
    if not os.path.isfile(workflow_file):
        print('Cannot find workflow file in {}'.format(workflow_file))
        exit(1)
    
    script = parse_workflow(workflow_file)
    if len(script) > 0:
        for command in script:
            print(command)
#           pass


if __name__ == '__main__':
    main()

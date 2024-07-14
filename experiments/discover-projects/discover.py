#!/usr/bin/env python3

from datetime import datetime, timezone
import os
import sys
import time
import json
import copy
import requests
import traceback
from analyzer import analyze


GITHUB_TOKEN = ''

if not GITHUB_TOKEN:
    print('Missing GITHUB_TOKEN')
    exit(1)


workflows = []


def load_workflows():
    """
    {
        repo_name: {
            [workflows]
            pushed_at
            fork_count
            star_count
            is_template
            language
        }
    """
    try:
        with open('workflows.json', 'r') as f:
            return json.load(f)
    except:
        return {}
    
    
def save_workflows(workflows):
    print('=====\nSaving workflows.json')
    with open('workflows.json', 'w') as f:
        json.dump(workflows, f, indent=4)

        
def get_query_str(language: str, date: str):
    return """{
    rateLimit {
        limit
        cost
        remaining
        resetAt
    }
    search(
        query: "language:%s sort:updated-desc pushed:%s"
        type: REPOSITORY
        first: 100
    ) {
        repositoryCount
        nodes {
            ... on Repository {
                nameWithOwner
                url
                pushedAt
                forkCount
                stargazerCount
                isTemplate
                primaryLanguage {
                    name
                }
                isFork
                defaultBranchRef {
                    target {
                        ... on Commit {
                            history(first:1) {
                                edges {
                                    node {
                                        ... on Commit{
                                            committedDate
                                            commitUrl
                                            checkSuites(first: 10) {
                                                nodes {
                                                    conclusion
                                                    workflowRun {
                                                        url
                                                        workflow {
                                                            name
                                                            resourcePath
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                object(expression: "HEAD:.github/workflows/") {
                    ... on Tree {
                        entries {
                            name
                            object {
                                ... on Blob {
                                    text
                                    isTruncated
                                }
                            }
                        }
                    }
                }
                
                pom: object(expression: "HEAD:pom.xml") {
                    ... on Blob {
                        text
                        isTruncated
                    }
                }
            }
        }
    }
}
""" % (language, date)


def graphql(query):
    try:
        url = 'https://api.github.com/graphql'
        r = requests.post(url, headers={'Authorization': 'bearer {}'.format(GITHUB_TOKEN)}, json={'query': query})
        return r.json().get('data', None)
    except:
        return None
    
    
def process(result, language):
    global workflows
    updated = 0
    new = 0
    already_processed = 0
    try:
        if result:
            for repo in result.get('search', {}).get('nodes', []):
                if already_processed >= 5:
                    return updated, new, True

                is_new = True
                nameWithOwner = repo.get('nameWithOwner')

                if nameWithOwner in workflows:
                    is_new = False
                    if repo.get('pushedAt') == workflows[nameWithOwner]:
                        already_processed += 1
                        # If we have 5 already processed repo in a row, stop and sleep again
                        continue
                    already_processed = 0

                detail = analyze(repo, True)

                if is_new:
                    new += 1
                else:
                    updated += 1

                if is_new:
                    detail['discoveredAt'] = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')

                workflows[nameWithOwner] = detail
    except Exception as e:
        print('Exception while processing API result')
        print(repr(e))
        print(traceback.format_exc())
    return updated, new, False


def start_running():
    global workflows
    workflows = load_workflows()
    i = 0
    while True:
        try:
            current_time = int(time.time())
            date = datetime.now(timezone.utc).strftime('%Y-%m-%d')
            
            java = graphql(get_query_str('Java', date))
            
            updated_java, new_java, stopped_java = process(java, 'Java')
            
            print('{}:'.format(current_time))
            print('\tJava: {}'.format('(Stopped)' if stopped_java else ''))
            print('\t\t{} new repo'.format(new_java))
            print('\t\t{} old repo'.format(updated_java))
            
            if i % 10 == 0:
                save_workflows(workflows)
        except Exception as e:
            print('Exception in main loop:')
            print(repr(e))
            print(traceback.format_exc())
            pass
        time.sleep(60)
        i += 1
        
        
try:
    start_running()
except KeyboardInterrupt:
    print('Saving workflows.json')
    save_workflows(workflows)

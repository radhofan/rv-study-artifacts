from datetime import datetime, timezone
from analyzer import analyze
import os
import sys
import time
import json
import copy
import requests
import traceback


GITHUB_TOKEN = ''

if not GITHUB_TOKEN:
    print('Missing GITHUB_TOKEN')
    exit(1)


def get_query_str(repos):
    return """{
    rateLimit {
        limit
        cost
        remaining
        resetAt
    }
    %s
}

fragment repoDetails on Repository {
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
""" % (repos, )


def generate_repo(names):
    s = ""
    i = 0
    for name in names:
        i += 1
        owner, project = name.split('/')
        s += 'repo{}: repository(owner:"{}", name:"{}") {{\n'.format(i, owner, project)
        s += '  ...repoDetails\n'
        s += '}\n'
    
    return s


def graphql(query):
    tried = 0
    while True:
        if tried > 10:
            print('Retried 10 times...')
            return None

        try:
            url = 'https://api.github.com/graphql'
            r = requests.post(url, headers={'Authorization': 'bearer {}'.format(GITHUB_TOKEN)}, json={'query': query})
            response = r.json().get('data', None)
            if not response:
                print(r.json())
                if 'Something went wrong' in r.text:
                    print('Retry in 10 seconds...')
                    time.sleep(10)
                    tried += 1
                    continue
            return response
        except Exception as e:
            print(e)
            return None


os.makedirs(os.path.join('results'), exist_ok=True)
os.makedirs(os.path.join('responses'), exist_ok=True)
batch = 0

while os.path.exists(os.path.join('results', 'results-{}.json'.format(batch+1))):
    batch += 1

with open('repos.txt') as f:
    repos = []

    for line in f.readlines():
        line = line.strip()
        if line:
            repos.append(line)
            print(line)

        if len(repos) == 100:
            batch += 1
            print('Processing 100 repos... ({})'.format(batch))

            repos_str = generate_repo(repos)
            query_str = get_query_str(repos_str)
            result = graphql(query_str)
            details = []

            if result is None:
                print('Cannot get repo data...')
                exit(batch)

            for i in range(1, len(repos) + 1):
                try:
                    repo = result.get('repo' + str(i), None)
                    if repo:
                        detail = analyze(repo, True)
                        details.append(detail)
                except:
                    print('Unable to parse ' + repos[i-1])
                    
            with open(os.path.join('results', 'results-{}.json'.format(batch)), 'w') as f:
                json.dump(details, f, indent=2)
                
            with open(os.path.join('responses', 'responses-{}.json'.format(batch)), 'w') as f:
                json.dump(result, f, indent=2)
            
            repos = []
            time.sleep(3)

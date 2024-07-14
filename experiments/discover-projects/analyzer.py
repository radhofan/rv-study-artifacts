import os

def analyze(repo, save=False):
    files = [] if not isinstance(repo.get('object'), dict) else repo.get('object', {}).get('entries', [])
    pom_text = '' if not isinstance(repo.get('pom'), dict) else repo.get('pom', {}).get('text', None)
    
    nameWithOwner = repo.get('nameWithOwner')
    owner_repo = nameWithOwner.split('/')
    test_framework = 'unknown'
    multi_module = 'unknown'
    last_commit_date = ''
    last_commit_sha = ''
    last_workflow_status = []
    workflows_files = []

    if pom_text:
        # Is maven project
        test_framework = 'unknown'
        if '<groupId>junit</groupId>' in pom_text:
            test_framework = 'junit4'
        elif '<groupId>org.junit.jupiter</groupId>' in pom_text:
            test_framework = 'junit5'
        elif '<groupId>org.testng</groupId>' in pom_text:
            test_framework = 'testng'
            
        multi_module = False
        if '<modules>' in pom_text:
            multi_module = True

        if save:
            # Save pom.xml to file
            os.makedirs(os.path.join('pom', owner_repo[0], owner_repo[1]), exist_ok=True)
            saved_pom_file_path = os.path.join('pom', owner_repo[0], owner_repo[1], 'pom.xml')
            try:
                if not os.path.exists(saved_pom_file_path):
                    with open(saved_pom_file_path, 'w') as f:
                        f.write(pom_text)
            except Exception as e:
                print('Exception while saving pom file')
                print(repr(e))
                print(traceback.format_exc())

    if files and save:
        os.makedirs(os.path.join('workflows', owner_repo[0], owner_repo[1]), exist_ok=True)

    for file in files:
        workflow_file_name = file.get('name')
        if not '.yml' in workflow_file_name and not '.yaml' in workflow_file_name:
            continue

        workflows_files.append(workflow_file_name)
        
        if file.get('object', None) is None:
            continue

        text = None if not isinstance(file.get('object'), dict) else file.get('object', {}).get('text', None)
        if not text:
            continue

        if save:
            # Save workflow file
            saved_file_path = os.path.join('workflows', owner_repo[0], owner_repo[1], workflow_file_name)
            try:
                if not os.path.exists(saved_file_path):
                    with open(saved_file_path, 'w') as f:
                        f.write(text)
            except Exception as e:
                print('Exception while saving workflow file')
                print(repr(e))
                print(traceback.format_exc())

    if 'defaultBranchRef' in repo and 'target' in repo['defaultBranchRef'] and 'history' in repo['defaultBranchRef']['target'] and 'edges' in repo['defaultBranchRef']['target']['history']:
        commits = repo['defaultBranchRef']['target']['history'].get('edges')
        if isinstance(commits, list) and len(commits) > 0:
            commit = commits[0].get('node', {})
            last_commit_date = commit.get('committedDate', '')
            last_commit_sha = commit.get('commitUrl').rpartition('/')[2]
            if commit.get('checkSuites') is not None and isinstance(commit.get('checkSuites').get('nodes'), list):
                for node in commit.get('checkSuites').get('nodes'):
                    if node.get('conclusion') is not None and node.get('workflowRun') is not None:
                        last_workflow_status.append(node)

    return {
        'repo': nameWithOwner,
        'workflows': workflows_files,
        'pushedAt': repo.get('pushedAt', ''),
        'url': repo.get('url'),
        'forkCount': repo.get('forkCount', 0),
        'starCount': repo.get('stargazerCount', 0),
        'isTemplate': repo.get('isTemplate', False),
        'isFork': repo.get('isFork', False),
        'language': 'unknown' if not isinstance(repo.get('primaryLanguage'), dict) else repo.get('primaryLanguage', {}).get('name', 'unknown'),
        'lastCommitDate': last_commit_date,
        'lastCommitSHA': last_commit_sha,
        'lastWorkflowStatus': last_workflow_status,
        'maven': pom_text != '',
        'testFramework': test_framework,
        'multiModule': multi_module
    }

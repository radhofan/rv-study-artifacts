#!/bin/bash
#
# Select projects for evaluation
# Usage: get_project_revisions.sh <revisions> <repo> <sha> <output-dir> <log-dir>
#
REVISIONS=$1
REPO=$2
SHA=$3
OUTPUT_DIR=$4
LOG_DIR=$5
SCRIPT_DIR=$(cd $(dirname $0) && pwd)
PROJECT_NAME=$(echo ${REPO} | tr / -)

EXTENSIONS_DIR=${SCRIPT_DIR}/../../extensions
MOP_DIR=${SCRIPT_DIR}/../../mop

source ${SCRIPT_DIR}/../constants.sh

function check_input() {
  if [[ -z ${REVISIONS} || -z ${REPO} || -z ${SHA} || -z ${OUTPUT_DIR} || -z ${LOG_DIR} ]]; then
    echo "Usage bash get_project_revisions.sh <revisions> <repo> <sha> <output-dir> <log-dir>"
    exit 1
  fi
  
  if [[ ! ${OUTPUT_DIR} =~ ^/.* ]]; then
    OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
  fi
  
  if [[ ! ${LOG_DIR} =~ ^/.* ]]; then
    LOG_DIR=${SCRIPT_DIR}/${LOG_DIR}
  fi
  
  mkdir -p ${OUTPUT_DIR}/${PROJECT_NAME}
  mkdir -p ${OUTPUT_DIR}/${PROJECT_NAME}/repo
  mkdir -p ${LOG_DIR}/${PROJECT_NAME}
}

function setup() {
  log "Setting up environment..."
  pushd ${SCRIPT_DIR}/../junit-measure-time &> /dev/null
  mvn -Dmaven.repo.local=${OUTPUT_DIR}/${PROJECT_NAME}/repo install &> /dev/null
  popd &> /dev/null
  
  mvn -Dmaven.repo.local=${OUTPUT_DIR}/${PROJECT_NAME}/repo install:install-file -Dfile=${MOP_DIR}/agents/stats-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" &> /dev/null
}

function log() {
  local message=$1
  echo "${message}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/output.log
}

function test_commit() {
  local sha=$1
  mkdir -p ${LOG_DIR}/${PROJECT_NAME}/${sha}
  git checkout ${sha} &> /dev/null
  
  run_compile ${sha}
  if [[ $? -ne 0 ]]; then
    echo "${sha},0,0,0" >> ${LOG_DIR}/${PROJECT_NAME}/commits-check.txt
    
    log "Cannot use commit ${sha} due to compile error"
    return 1
  fi
  
  run_test ${sha}
  if [[ $? -ne 0 ]]; then
    echo "${sha},1,0,0" >> ${LOG_DIR}/${PROJECT_NAME}/commits-check.txt
    
    log "Cannot use commit ${sha} due to test error"
    return 1
  fi
  
  run_test_with_rv ${sha}
  if [[ $? -ne 0 ]]; then
    echo "${sha},1,1,0" >> ${LOG_DIR}/${PROJECT_NAME}/commits-check.txt
    
    log "Cannot use commit ${sha} due to test-rv error"
    return 1
  fi
  
  echo "${sha},1,1,1" >> ${LOG_DIR}/${PROJECT_NAME}/commits-check.txt
  log "Finished testing commit ${sha}"
  return 0
}

function run_compile() {
  local sha=$1
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  log "Running test-compile"
  local start=$(date +%s%3N)
  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${OUTPUT_DIR}/${PROJECT_NAME}/repo ${SKIP} test-compile) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/compile.log
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  echo "[TSM-CTW] Duration: ${duration} ms, status: ${status}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/${sha}/compile.log
  
  return ${status}
}

function run_test() {
  local sha=$1
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  log "Running test without MOP"
  local start=$(date +%s%3N)
  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${OUTPUT_DIR}/${PROJECT_NAME}/repo ${SKIP} surefire:test) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/test.log
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  echo "[TSM-CTW] Duration: ${duration} ms, status: ${status}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/${sha}/test.log
  
  return ${status}
}

function run_test_with_rv() {
  local sha=$1
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  export COLLECT_TRACES=1
  export JUNIT_MEASURE_TIME_LISTENER=1
  
  log "Running test with MOP"
  local start=$(date +%s%3N)
  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${OUTPUT_DIR}/${PROJECT_NAME}/repo ${SKIP} -Dmaven.ext.class.path="${EXTENSIONS_DIR}/javamop-extension-1.0.jar" surefire:test) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv.log
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  echo "[TSM-CTW] Duration: ${duration} ms, status: ${status}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv.log
  
  export COLLECT_TRACES=0
  export JUNIT_MEASURE_TIME_LISTENER=0
  return ${status}
}

function get_project() {
  pushd ${OUTPUT_DIR}/${PROJECT_NAME} &> /dev/null
  
  export GIT_TERMINAL_PROMPT=0
  git clone https://github.com/${REPO} project |& tee -a ${LOG_DIR}/${PROJECT_NAME}/output.log
  pushd ${OUTPUT_DIR}/${PROJECT_NAME}/project &> /dev/null
  git checkout ${SHA} |& tee -a ${LOG_DIR}/${PROJECT_NAME}/output.log
  if [[ $? -ne 0 ]]; then
    log "Skip project: cannot clone repository"
    exit 1
  fi
  
  if [[ -f ${OUTPUT_DIR}/${PROJECT_NAME}/.gitmodules ]]; then
    log "Skip project: project contains submodule"
    exit 1
  fi

  # We will use tail -n +2 to skip the first commit
  # We will test the first commit separately
  echo ${SHA} > ${LOG_DIR}/${PROJECT_NAME}/commits.txt
  git log --name-status | grep 'java\|^commit' | grep -B1 'java$' | grep ^commit | cut -d ' ' -f 2 | tail -n +2 | head -n 500 >> ${LOG_DIR}/${PROJECT_NAME}/commits.txt
  local failure=0
  
  while read -r commit; do
    log "Testing commit ${commit}"
    test_commit ${commit}
    if [[ $? -ne 0 ]]; then
      failure=$((failure + 1))
      if [[ ${failure} -ge 10 ]]; then
        log "Skip project: 10 failures in a row"
        exit 1
      fi
    else
      failure=0
    fi

    local success=$(grep ,1,1,1 ${LOG_DIR}/${PROJECT_NAME}/commits-check.txt | wc -l)
    if [[ ${success} -ge ${REVISIONS} ]]; then
      break
    fi
    log "Found ${success} projects"
  done < ${LOG_DIR}/${PROJECT_NAME}/commits.txt
  
  popd &> /dev/null
  popd &> /dev/null
  
  log "Done, found $(grep ,1,1,1 ${LOG_DIR}/${PROJECT_NAME}/commits-check.txt | wc -l)/$(cat ${LOG_DIR}/${PROJECT_NAME}/commits-check.txt | wc -l) valid commits"
}

export RVMLOGGINGLEVEL=UNIQUE
check_input
setup
get_project

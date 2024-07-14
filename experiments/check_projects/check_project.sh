#!/bin/bash
#
# Clone project, run tests, measure time, run tests with RV, and measure time again
# Usage: ./check_project.sh <repo> <sha> <log-dir> [steps]
# Output report.csv: <project-name>,<clone-status>,<test-status>,<rv-test-status>,<test-time>,<rv-test-time>
#
REPO=$1
SHA=$2
LOG_DIR=$3
STEPS=$4
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
PROJECT_NAME=$(echo ${REPO} | tr / -)

source ${SCRIPT_DIR}/../constants.sh
source ${SCRIPT_DIR}/../utils.sh

if [[ -z ${REPO} || -z ${SHA} ]]; then
  echo "Usage: bash check_project.sh <repo> <sha> <log-dir>  [steps]"
  echo "If prep"
  exit 1
fi

PROJECT_DIR=${SCRIPT_DIR}/../../projects
REPO_DIR=${SCRIPT_DIR}/../../repos
MOP_DIR=${SCRIPT_DIR}/../../mop
LOG_PATH=${LOG_DIR}/check_project/${PROJECT_NAME}
EXTENSIONS_DIR=${SCRIPT_DIR}/../../extensions

mkdir -p ${PROJECT_DIR}
mkdir -p ${REPO_DIR}
mkdir -p ${LOG_DIR}/check_project/${PROJECT_NAME}

if [[ -n ${STEPS} ]]; then
  START=$(echo ${STEPS} | cut -d '-' -f 1)
  END=$(echo ${STEPS} | cut -d '-' -f 2)
else
  START=0
  END=100
fi

# Start functions

function clone() {
  export GIT_TERMINAL_PROMPT=0
  echo "${PROJECT_NAME},0,0,0,-1,-1" > ${LOG_PATH}/result.csv
  
  timeout 180s git clone "https://github.com/${REPO}" ${PROJECT_DIR}/${PROJECT_NAME} &>> ${LOG_PATH}/clone.log
  local status=$?
  if [[ ${status} -ne 0 ]]; then
    exit 1
  fi
  
  pushd ${PROJECT_DIR}/${PROJECT_NAME}
  git checkout ${SHA} &>> ${LOG_PATH}/clone.log
  local status=$?
  if [[ ${status} -ne 0 ]]; then
    exit 1
  fi
  
  if [[ -f .gitmodules ]]; then
    timeout 180s git submodule update --init --recursive
    local status=$?
    if [[ ${status} -ne 0 ]]; then
      exit 1
    fi
  fi
  popd
  
  echo "${PROJECT_NAME},1,0,0,-1,-1" > ${LOG_PATH}/result.csv
}

function install_measure_time() {
  pushd ${SCRIPT_DIR}/../junit-measure-time
  mvn -Dmaven.repo.local=${REPO_DIR}/${PROJECT_NAME} install
  popd
}

function test_without_rv() {
  pushd ${PROJECT_DIR}/${PROJECT_NAME}
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR}/${PROJECT_NAME} "${SKIP}" test-compile) &>> ${LOG_PATH}/test.log
  
  export JUNIT_MEASURE_TIME_LISTENER=1
  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -DargLine="-verbose:class" -Dmaven.repo.local=${REPO_DIR}/${PROJECT_NAME} "${SKIP}" surefire:test) &>> ${LOG_PATH}/test.log
  local status=$?
  if [[ ${status} -ne 0 ]]; then
    exit 1
  fi
  export JUNIT_MEASURE_TIME_LISTENER=0
  
  get_loaded_classes
  popd
  
  echo "${PROJECT_NAME},1,1,0,-1,-1" > ${LOG_PATH}/result.csv
}

function get_loaded_classes() {
  # Generate loaded classes file
  if [[ -n $(grep --text "directly writing to native stream in forked" ${LOG_PATH}/test.log) ]]; then
    dumpstream=$(grep --text "directly writing to native stream in forked" ${LOG_PATH}/test.log | cut -d '/' -f 2-)
    while read -r file; do
      # Read all the dumpstream file
      local log_file="/${file}"
      if [[ -z $(grep --text "\[Loaded " ${log_file}) ]]; then
        # Skip the file if it doesn't contain [Load
        continue
      fi

      classes=$(grep --text "\[Loaded " ${log_file} | cut -d "[" -f 2- | cut -d ' ' -f 2)
      while read -r class; do
        echo ${class} >> ${LOG_PATH}/loaded-classes.txt
      done <<< "${classes}"
    done <<< "${dumpstream}"
  fi

  # Now, check test.log
  if [[ -n $(grep --text "\[Loaded " ${LOG_PATH}/test.log) ]]; then
    # Only check if it contains [Load
    classes=$(grep --text "\[Loaded " ${LOG_PATH}/test.log | cut -d "[" -f 2- | cut -d ' ' -f 2)
    while read -r class; do
      echo ${class} >> ${LOG_PATH}/loaded-classes.txt
    done <<< "${classes}"
  fi
}

function test_with_rv() {
  if [[ ${SINGLE_PASS} != true ]]; then
    # When single pass is true, it will not check RV is enabled or not
    mvn -Dmaven.repo.local=${REPO_DIR}/${PROJECT_NAME} install:install-file -Dfile=${MOP_DIR}/agents/stats-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar"
    local status=$?
    if [[ ${status} -ne 0 ]]; then
      exit 1
    fi
    
    pushd ${PROJECT_DIR}/${PROJECT_NAME}
    mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
    export COLLECT_TRACES=1
    export JUNIT_MEASURE_TIME_LISTENER=1
    (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR}/${PROJECT_NAME} "${SKIP}" -Dmaven.ext.class.path="${EXTENSIONS_DIR}/javamop-extension-1.0.jar" surefire:test) &>> ${LOG_PATH}/test-rv.log
    local status=$?
    export JUNIT_MEASURE_TIME_LISTENER=0

    move_violations ${LOG_PATH} violation-counts-ltw-stats

    if [[ ${status} -ne 0 ]]; then
      exit 1
    fi
    
    if [[ -z $(grep -m1 "URL_SetURLStreamHandlerFactory" ${LOG_PATH}/test-rv.log) ]]; then
      exit 1
    fi
    popd
    
    echo "${PROJECT_NAME},1,1,1,-1,-1" > ${LOG_PATH}/result.csv
  fi
}

function test_time() {
  pushd ${PROJECT_DIR}/${PROJECT_NAME}
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  delete_violations
  
  export JUNIT_MEASURE_TIME_LISTENER=1
  local start=$(date +%s%3N)
  (uptime && time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR}/${PROJECT_NAME} "${SKIP}" surefire:test) &>> ${LOG_PATH}/test-time.log
  local status=$?
  local end=$(date +%s%3N)
  local test_duration=$((end - start))
  export JUNIT_MEASURE_TIME_LISTENER=0
  if [[ ${status} -ne 0 ]]; then
    echo "${PROJECT_NAME},1,1,1,-1,-1" > ${LOG_PATH}/result.csv
    exit 1
  fi
  
  uptime >> ${LOG_PATH}/test-time.log
  
  
  mvn -Dmaven.repo.local=${REPO_DIR}/${PROJECT_NAME} install:install-file -Dfile=${MOP_DIR}/agents/no-track-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar"
  local status=$?
  if [[ ${status} -ne 0 ]]; then
    exit 1
  fi
  
  echo "${PROJECT_NAME},1,1,1,${test_duration},-1" > ${LOG_PATH}/result.csv

  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  delete_violations
  
  export JUNIT_MEASURE_TIME_LISTENER=1
  export COLLECT_TRACES=1
  local start=$(date +%s%3N)
  (uptime && time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR}/${PROJECT_NAME} "${SKIP}" -Dmaven.ext.class.path="${EXTENSIONS_DIR}/javamop-extension-1.0.jar" surefire:test) &>> ${LOG_PATH}/test-rv-time.log
  local status=$?
  local end=$(date +%s%3N)

  move_violations ${LOG_PATH} violation-counts-ltw-time
  
  local test_rv_duration=$((end - start))
  export JUNIT_MEASURE_TIME_LISTENER=0
  if [[ ${status} -ne 0 ]]; then
    exit 1
  fi
  popd
  
  echo "${PROJECT_NAME},1,1,1,${test_duration},${test_rv_duration}" > ${LOG_PATH}/result.csv
  uptime >> ${LOG_PATH}/test-rv-time.log
}

function run_steps() {
  if [[ ${START} -le 1 && ${END} -ge 1 ]]; then
    # Step 1
    clone
  fi
  
  if [[ ${START} -le 2 && ${END} -ge 2 ]]; then
    # Step 2
    install_measure_time
  fi
  
  if [[ ${START} -le 3 && ${END} -ge 3 ]]; then
    # Step 3
    test_without_rv
  fi
  
  if [[ ${START} -le 4 && ${END} -ge 4 ]]; then
    # Step 4
    test_with_rv
  fi
  
  if [[ ${START} -le 5 && ${END} -ge 5 ]]; then
    # Step 5
    test_time
  fi
}

run_steps

#!/bin/bash
#
# Measure test time and MOP time for each commit
# Usage: get_test_and_mop_time.sh <commits-check.txt> <project-name> <project-dir> <repo-dir> <log-dir>
#
COMMITS_CHECK_FILE=$1
PROJECT_NAME=$(echo $2 | tr / -)
PROJECT_DIR=$3
REPO_DIR=$4
LOG_DIR=$5
SCRIPT_DIR=$(cd $(dirname $0) && pwd)

EXTENSIONS_DIR=${SCRIPT_DIR}/../../extensions
MOP_DIR=${SCRIPT_DIR}/../../mop

source ${SCRIPT_DIR}/../constants.sh

function check_input() {
  if [[ ! -f ${COMMITS_CHECK_FILE} || -z ${PROJECT_NAME} || ! -d ${PROJECT_DIR} || ! -d ${REPO_DIR} || -z ${LOG_DIR} ]]; then
    echo "Usage bash get_test_and_mop_time.sh <commits-check.txt> <project-name> <project-dir> <repo-dir> <log-dir>"
    exit 1
  fi
  
  if [[ ! ${COMMITS_CHECK_FILE} =~ ^/.* ]]; then
    COMMITS_CHECK_FILE=${SCRIPT_DIR}/${COMMITS_CHECK_FILE}
  fi
  
  if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
    PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
  fi
  
  if [[ ! ${REPO_DIR} =~ ^/.* ]]; then
    REPO_DIR=${SCRIPT_DIR}/${REPO_DIR}
  fi
  
  if [[ ! ${LOG_DIR} =~ ^/.* ]]; then
    LOG_DIR=${SCRIPT_DIR}/${LOG_DIR}
  fi

  mkdir -p ${LOG_DIR}/${PROJECT_NAME}
}

function setup() {
  echo "Setting up environment..."
  mvn -Dmaven.repo.local=${REPO_DIR} install:install-file -Dfile=${MOP_DIR}/agents/no-track-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" &> /dev/null
}

function compile() {
  local sha=$1
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  echo "Running test-compile"
  git checkout ${sha} &> /dev/null

  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/compile-time.log
  
  local start=$(date +%s%3N)
  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR} ${SKIP} test-compile) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/compile-time.log
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/compile-time.log
  echo "[TSM-CTW] Duration: ${duration} ms, status: ${status}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/${sha}/compile-time.log
  
  echo -n "${sha},${duration},${status}," >> ${LOG_DIR}/${PROJECT_NAME}/report.csv
}

function measure_test_time() {
  local sha=$1
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  echo "Running test without MOP"
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-time.log
  
  local start=$(date +%s%3N)
  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR} ${SKIP} surefire:test) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-time.log
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-time.log
  echo "[TSM-CTW] Duration: ${duration} ms, status: ${status}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-time.log
  
  echo -n "${duration},${status}," >> ${LOG_DIR}/${PROJECT_NAME}/report.csv
}

function measure_mop_time() {
  local sha=$1
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  export COLLECT_TRACES=1

  for violation in $(find -name "violation-counts"); do
    rm ${violation}
  done

  echo "Running test with MOP"
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv-time.log
  
  local start=$(date +%s%3N)
  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR} ${SKIP} -Dmaven.ext.class.path="${EXTENSIONS_DIR}/javamop-extension-1.0.jar" surefire:test) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv-time.log
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv-time.log
  echo "[TSM-CTW] Duration: ${duration} ms, status: ${status}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv-time.log
  
  for violation in $(find -name "violation-counts"); do
    local name=$(echo "${violation}" | rev | cut -d '/' -f 2 | rev)
    if [[ ${name} != "." ]]; then
      # Is MMMP, add module name to file name
      mv ${violation} ${LOG_DIR}/${PROJECT_NAME}/${sha}/violation-counts_${name}
    else
      mv ${violation} ${LOG_DIR}/${PROJECT_NAME}/${sha}/violation-counts
    fi
  done

  echo "${duration},${status}" >> ${LOG_DIR}/${PROJECT_NAME}/report.csv
}

function measure_time() {
  pushd ${PROJECT_DIR} &> /dev/null
  for sha in $(grep ",1,1,1" ${COMMITS_CHECK_FILE} | cut -d ',' -f 1); do
    echo "Checking out to ${sha}"
    mkdir -p ${LOG_DIR}/${PROJECT_NAME}/${sha}
    
    compile ${sha}
    measure_test_time ${sha}
    measure_mop_time ${sha}
  done
  popd &> /dev/null
}

export RVMLOGGINGLEVEL=UNIQUE
export JUNIT_MEASURE_TIME_LISTENER=1
check_input
setup
measure_time

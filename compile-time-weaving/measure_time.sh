#!/bin/bash
#
# Measure test time and e2e with MOP (using CTW)
# Usage: measure_time.sh <projects-list> <log-dir> <aspectj-dir> [all/reduced/nomop]
#
PROJECTS_LIST=$1
LOG_DIR=$2
ASPECTJ_DIR=$3
MODE=$4
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

source ${SCRIPT_DIR}/../experiments/constants.sh

function check_inputs() {
  if [[ ! -f "${PROJECTS_LIST}" || -z "${LOG_DIR}" || -z ${ASPECTJ_DIR} ]]; then
    echo "Usage: ./measure_time.sh <projects-list> <log-dir> <aspectj-dir> [all/reduced/nomop]"
    exit 1
  fi
  
  if [[ ! -d "${SCRIPT_DIR}/../experiments/junit-measure-time" ]]; then
    echo "Missing dependency: ../experiments/junit-measure-time"
    exit 1
  fi
  
  if [[ ! -f "${ASPECTJ_DIR}/lib/aspectjrt.jar" ]]; then
    echo "Cannot find AspectJ"
    exit 2
  fi
  
  if [[ -z ${MODE} ]]; then
    MODE="all"
  elif [[ ${MODE} != "reduced" && ${MODE} != "nomop" ]]; then
    MODE="all"
  fi
  
  echo "Current Mode: ${MODE}"

  mkdir -p ${LOG_DIR}
}

function convert_to_absolute_paths() {
  if [[ ! ${PROJECTS_LIST} =~ ^/.* ]]; then
    PROJECTS_LIST=${SCRIPT_DIR}/${PROJECTS_LIST}
  fi
  
  if [[ ! ${LOG_DIR} =~ ^/.* ]]; then
    LOG_DIR=${SCRIPT_DIR}/${LOG_DIR}
  fi
  
  if [[ ! ${ASPECTJ_DIR} =~ ^/.* ]]; then
    ASPECTJ_DIR=${SCRIPT_DIR}/${ASPECTJ_DIR}
  fi
  
  ASPECTJRT_JAR="${ASPECTJ_DIR}/lib/aspectjrt.jar"
}

function measure_with_mop() {
  local project=$1
  local repo="${SCRIPT_DIR}/repos/${project}"
  local log_path="${LOG_DIR}/${project}.log"
  
  echo "Measuring ${project}..."
  
  pushd ${SCRIPT_DIR}/../experiments/junit-measure-time
  mvn -Dmaven.repo.local="${repo}" install
  popd

  export JUNIT_MEASURE_TIME_LISTENER=1
  export MY_ASPECTS_JAR="${SCRIPT_DIR}/myaspects.jar"
  export ASPECTJRT_JAR=${ASPECTJRT_JAR}
  export RV_MONITOR_RT_JAR="${SCRIPT_DIR}/../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar"
  
  pushd ${SCRIPT_DIR}/projects/${project}
  run_tests ${project}
  popd
  
  export JUNIT_MEASURE_TIME_LISTENER=0
  unset MY_ASPECTS_JAR
  unset ASPECTJRT_JAR
  unset RV_MONITOR_RT_JAR
}

function measure_without_mop() {
  local project=$1
  local repo="${SCRIPT_DIR}/nomop-repos"
  local log_path="${LOG_DIR}/${project}.log"
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  if [[ ! -d ${repo} ]]; then
    mkdir -p ${repo}
    
    # Install JUnit time listener
    pushd ${SCRIPT_DIR}/../experiments/junit-measure-time
    mvn -Dmaven.repo.local="${repo}" install
    popd
  fi
  
  if [[ ! -d "${SCRIPT_DIR}/nomop-projects/${project}" ]]; then
    cp -r ${SCRIPT_DIR}/projects/${project} ${SCRIPT_DIR}/nomop-projects/${project}
  fi

  pushd ${SCRIPT_DIR}/nomop-projects/${project}
  # First test will download jars, second surefire:test will measure test time
# mvn -Dmaven.repo.local="${repo}" clean test
  
  export JUNIT_MEASURE_TIME_LISTENER=1
  local start=$(date +%s%3N)
  (uptime && time timeout ${TIMEOUT} mvn -Dmaven.repo.local="${repo}" -Djava.io.tmpdir=/tmp/tsm-rv surefire:test) &>> ${log_path}
  echo "Status Code: $?" >> ${log_path}
  local end=$(date +%s%3N)
  export JUNIT_MEASURE_TIME_LISTENER=0

  collect_time ${start} ${end} ${log_path}
  uptime >> ${log_path}
  popd
}

function run_tests() {
  local project=$1
  local repo="${SCRIPT_DIR}/repos/${project}"
  local log_path="${LOG_DIR}/${project}.log"
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  if [[ ${MODE} = "all" ]]; then
    local start=$(date +%s%3N)
    (uptime && time timeout ${TIMEOUT} mvn -Dmaven.repo.local="${repo}" -Djava.io.tmpdir=/tmp/tsm-rv surefire:test) &>> ${log_path}
    echo "Status Code: $?" >> ${log_path}
    local end=$(date +%s%3N)
    
    collect_time ${start} ${end} ${log_path}
  elif [[ ${MODE} == "reduced" ]]; then
    local test_suite=$(cat reduced_tests.txt | sed -z '$ s/\n$//;s/\n/,/g') # Replace \n with ,
    
    local start=$(date +%s%3N)
    (uptime && time timeout ${TIMEOUT} mvn -Dmaven.repo.local="${repo}" -Djava.io.tmpdir=/tmp/tsm-rv surefire:test -Dtest="${test_suite}") &>> ${log_path}
    echo "Status Code: $?" >> ${log_path}
    local end=$(date +%s%3N)
    
    collect_time ${start} ${end} ${log_path}
  fi

  uptime >> ${log_path}
}

function collect_time() {
  local start_time=$1
  local end_time=$2
  local log=$3
  local output=$4
  
  local e2e_time=$((end_time - start_time))
  local test_time=$(grep --text "^\[TSM\] JUnit Total Time:" ${log})
  if [[ -n ${test_time} ]]; then
    test_time=$(grep --text "^\[TSM\] JUnit Total Time:" ${log} | cut -d' ' -f5 | paste -sd+ | bc -l)
  else
    test_time=-1
  fi
  
  echo "${project},${test_time},${e2e_time}" >> ${LOG_DIR}/times.csv
}


function run_all() {
  while read -r project; do
    if [[ ! -d "${SCRIPT_DIR}/projects/${project}" ]]; then
      echo "Cannot find project ${project}"
      echo "Please run ./run.sh first"
      continue
    fi
    
    if [[ ${MODE} == "nomop" ]]; then
      # Measure time without MOP
      mkdir -p "${SCRIPT_DIR}/nomop-projects"
      measure_without_mop ${project}
    else
      # Measure time with MOP
      if [[ ! -d "${SCRIPT_DIR}/repos/${project}" ]]; then
        echo "Cannot find repo for project ${project}"
        echo "Please run ./run.sh first"
        continue
      fi
      
      if [[ -f "${SCRIPT_DIR}/projects/${project}/violation-counts" ]]; then
        # Backup violation-counts
        mv "${SCRIPT_DIR}/projects/${project}/violation-counts" "${SCRIPT_DIR}/projects/${project}/.violation-counts"
      fi
      
      measure_with_mop ${project}
      
      if [[ -f "${SCRIPT_DIR}/projects/${project}/.violation-counts" ]]; then
        # Restore
        mv "${SCRIPT_DIR}/projects/${project}/.violation-counts" "${SCRIPT_DIR}/projects/${project}/violation-counts"
      fi
    fi
  done < ${PROJECTS_LIST}
}

export RVMLOGGINGLEVEL=UNIQUE
check_inputs
convert_to_absolute_paths
run_all

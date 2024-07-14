#!/bin/bash
#
# Profile project 3 times: without mop, with mop, without hot methods
# Usage: profile_projects.sh <project-dir> <output-dir> <projects-list> <extension-directory> <nohot-agents-dir> <agents-dir> <path-to-profiler>
#
PROJECT_DIR=$1
OUTPUT_DIR=$2
PROJECTS_LIST=$3
EXTENSION_DIR=$4
NOHOT_AGENTS_DIR=$5
ALL_AGENTS_DIR=$6
PROFILER_PATH=$7
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

source ${SCRIPT_DIR}/../experiments/constants.sh

check_inputs() {
  if [[ ! -d "${PROJECT_DIR}" || -z "${OUTPUT_DIR}" || ! -f "${PROJECTS_LIST}" || ! -d "${EXTENSION_DIR}" || ! -d "${ALL_AGENTS_DIR}" || ! -d "${NOHOT_AGENTS_DIR}" || ! -f "${PROFILER_PATH}" ]]; then
    echo "Usage: ./profile_projects.sh <project-dir> <output-dir> <projects-list> <extension-directory> <nohot-agents-dir> <agents-dir> <path-to-profiler>"
    exit 1
  fi
  
  mkdir -p ${OUTPUT_DIR}
}

function convert_to_absolute_paths() {
  if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
    PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
  fi
  
  if [[ ! ${OUTPUT_DIR} =~ ^/.* ]]; then
    OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
  fi
  
  if [[ ! ${EXTENSION_DIR} =~ ^/.* ]]; then
    EXTENSION_DIR=${SCRIPT_DIR}/${EXTENSION_DIR}
  fi
  
  if [[ ! ${ALL_AGENTS_DIR} =~ ^/.* ]]; then
    ALL_AGENTS_DIR=${SCRIPT_DIR}/${ALL_AGENTS_DIR}
  fi
  
  if [[ ! ${NOHOT_AGENTS_DIR} =~ ^/.* ]]; then
    NOHOT_AGENTS_DIR=${SCRIPT_DIR}/${NOHOT_AGENTS_DIR}
  fi
  
  if [[ ! ${PROFILER_PATH} =~ ^/.* ]]; then
    PROFILER_PATH=${SCRIPT_DIR}/${PROFILER_PATH}
  fi
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
  
  echo -n "${test_time},${e2e_time}," >> ${output}
}

function without_mop() {
  local project=$1
  
  rm -rf /tmp/tsm-rv profile.jfr && mkdir -p /tmp/tsm-rv
  
  local log_path=${OUTPUT_DIR}/${project}/time-without-mop.log
  local result_path=${OUTPUT_DIR}/${project}/result.csv

  local start=$(date +%s%3N)
  (uptime && time timeout ${TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv surefire:test) &> ${log_path}
  
  if [[ $? -ne 0 ]]; then
    # -2 = timeout
    echo -n "-2,-2" >> ${result_path}
    echo "Timeout..." >> ${OUTPUT_DIR}/out.log
  else
    local end=$(date +%s%3N)
    
    uptime >> ${log_path}
    collect_time ${start} ${end} ${log_path} ${result_path}
  fi
  
  if [[ -f profile.jfr ]]; then
    mv profile.jfr profile_nomop.jfr
  fi
}

function with_mop() {
  local project=$1
  mvn install:install-file -Dfile=${ALL_AGENTS_DIR}/no-track-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" &>/dev/null
  
  rm -rf /tmp/tsm-rv profile.jfr && mkdir -p /tmp/tsm-rv
  
  local log_path=${OUTPUT_DIR}/${project}/time-with-mop.log
  local result_path=${OUTPUT_DIR}/${project}/result.csv
  
  local start=$(date +%s%3N)
  (uptime && time timeout ${TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv surefire:test -Dmaven.ext.class.path="${EXTENSION_DIR}/javamop-extension-1.0.jar") &> ${log_path}
  
  if [[ $? -ne 0 ]]; then
    # -2 = timeout
    echo -n "-2,-2" >> ${result_path}
    echo "Timeout..." >> ${OUTPUT_DIR}/out.log
  else
    local end=$(date +%s%3N)
    
    uptime >> ${log_path}
    collect_time ${start} ${end} ${log_path} ${result_path}
  fi
  
  if [[ -f profile.jfr ]]; then
    mv profile.jfr profile_mop.jfr
  fi
}

function without_hot_methods() {
  local project=$1
  mvn install:install-file -Dfile=${NOHOT_AGENTS_DIR}/${project}-notrack-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" &>/dev/null
  
  rm -rf /tmp/tsm-rv profile.jfr && mkdir -p /tmp/tsm-rv
  
  local log_path=${OUTPUT_DIR}/${project}/time-without-hot.log
  local result_path=${OUTPUT_DIR}/${project}/result.csv
  
  local start=$(date +%s%3N)
  (uptime && time timeout ${TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv surefire:test -Dmaven.ext.class.path="${EXTENSION_DIR}/javamop-extension-1.0.jar") &> ${log_path}
  
  if [[ $? -ne 0 ]]; then
    # -2 = timeout
    echo -n "-2,-2" >> ${result_path}
    echo "Timeout..." >> ${OUTPUT_DIR}/out.log
  else
    local end=$(date +%s%3N)
    
    uptime >> ${log_path}
    collect_time ${start} ${end} ${log_path} ${result_path}
  fi
  
  if [[ -f profile.jfr ]]; then
    mv profile.jfr profile_nohot.jfr
  fi
}


function profile_project() {
  local project=$1

  cp -r ${PROJECT_DIR}/${project} ${OUTPUT_DIR}/${project}
  pushd ${OUTPUT_DIR}/${project} &>/dev/null

  echo "Without mop..." >> ${OUTPUT_DIR}/out.log
  without_mop ${project}
  
  echo "With mop..." >> ${OUTPUT_DIR}/out.log
  with_mop ${project}
  
  echo "Without hot methods..." >> ${OUTPUT_DIR}/out.log
  without_hot_methods ${project}

  popd &>/dev/null
}

function profile_all() {
  export PROFILER_PATH=${PROFILER_PATH}

  while read -r project; do
    echo "Profiling ${project}" >> ${OUTPUT_DIR}/out.log
    
    profile_project ${project}
  done < ${PROJECTS_LIST}
}


export JUNIT_MEASURE_TIME_LISTENER=1
export RVMLOGGINGLEVEL=UNIQUE
check_inputs
convert_to_absolute_paths
profile_all
export JUNIT_MEASURE_TIME_LISTENER=0

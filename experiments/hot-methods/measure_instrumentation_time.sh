#!/bin/bash
#
# Measure instrumentation only time
# Usage: measure_instrumentation_time.sh <project-dir> <output-dir> <projects-list> <extension-directory> <no-monitoring-agent-path>
#
PROJECT_DIR=$1
OUTPUT_DIR=$2
PROJECTS_LIST=$3
EXTENSION_DIR=$4
AGENT_PATH=$5
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

check_inputs() {
  if [[ ! -d "${PROJECT_DIR}" || -z "${OUTPUT_DIR}" || ! -f "${PROJECTS_LIST}" || ! -d "${EXTENSION_DIR}" || ! -f "${AGENT_PATH}" ]]; then
    echo "Usage: ./measure_instrumentation_time.sh <project-dir> <output-dir> <projects-list> <extension-directory> <no-monitoring-agent-path>"
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
}

function measure_project() {
  local project=$1

  cp -r ${PROJECT_DIR}/${project} ${OUTPUT_DIR}/${project}
  pushd ${OUTPUT_DIR}/${project}
  
  export JUNIT_MEASURE_TIME_LISTENER=1
  rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  local log_path=${OUTPUT_DIR}/${project}/time.log
  local start=$(date +%s%3N)
  (uptime && time mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.ext.class.path=${EXTENSION_DIR}/javamop-extension-1.0.jar surefire:test) &> ${log_path}
  local end=$(date +%s%3N)
  
  uptime >> ${log_path}
  export JUNIT_MEASURE_TIME_LISTENER=0
  popd
  
  local e2e_time=$((end - start))
  local test_time=$(grep --text "^\[TSM\] JUnit Total Time:" ${log_path})
  if [[ -n ${test_time} ]]; then
    test_time=$(grep --text "^\[TSM\] JUnit Total Time:" ${log_path} | cut -d' ' -f5 | paste -sd+ | bc -l)
  else
    test_time=-1
  fi

  echo "${project},${test_time},${e2e_time}" >> ${OUTPUT_DIR}/results.csv
}

function measure_all() {
  mvn install:install-file -Dfile=${AGENT_PATH} -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" &>/dev/null

  while read -r project; do
    echo "Checking ${project}"
    measure_project ${project}
  done < ${PROJECTS_LIST}
}

check_inputs
measure_all

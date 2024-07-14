#!/bin/bash
#
# Measure test time
# Usage: measure_test_time.sh <project-dir> <output-dir> <projects-list>
#
PROJECT_DIR=$1
OUTPUT_DIR=$2
PROJECTS_LIST=$3
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

check_inputs() {
  if [[ ! -d "${PROJECT_DIR}" || -z "${OUTPUT_DIR}" || ! -f "${PROJECTS_LIST}" ]]; then
    echo "Usage: ./measure_test_time.sh <project-dir> <output-dir> <projects-list>"
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
}

function measure_project() {
  local project=$1

  cp -r ${PROJECT_DIR}/${project} ${OUTPUT_DIR}/${project}
  pushd ${OUTPUT_DIR}/${project}
  
  export JUNIT_MEASURE_TIME_LISTENER=1
  rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  local log_path=${OUTPUT_DIR}/${project}/time.log
  local start=$(date +%s%3N)
  (uptime && time mvn -Djava.io.tmpdir=/tmp/tsm-rv surefire:test) &> ${log_path}
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
  while read -r project; do
    echo "Checking ${project}"
    measure_project ${project}
  done < ${PROJECTS_LIST}
}

check_inputs
measure_all

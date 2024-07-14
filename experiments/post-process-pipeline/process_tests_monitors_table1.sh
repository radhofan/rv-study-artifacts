#!/bin/bash
#
# Check run_all_experiments.sh's output
# Usage: ./process_tests_monitors_table1.sh <output-dir> [projects-list]
#
OUTPUT_DIR=$1
PROJECTS_LIST=$2
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ ! -d "${OUTPUT_DIR}" ]]; then
  echo "Cannot find output directory"
  exit 1
fi

if [[ ! -f ${PROJECTS_LIST} ]]; then
  ls ${OUTPUT_DIR} > .repo.txt
  PROJECTS_LIST=".repo.txt"
fi

function check_files() {
  project=$1
  
  if [[ ! -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/result.csv ]]; then
    return 1
  fi
  
  if [[ ! -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/test-rv.log ]]; then
#   echo "${project},no test rv"
    return 1
  fi
  
  if [[ ! -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/test.log ]]; then
#   echo "${project},no test"
    return 1
  fi
  
  if [[ ! -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/test-rv-time.log ]]; then
#   echo "${project},no test rv time"
    return 1
  fi
  
  if [[ ! -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/test-time.log ]]; then
#   echo "${project},no test time"
    return 1
  fi
}

function check_result() {
  echo "project,tests count,rv tests count,timed tests count,timed rv tests count,monitors,events"

  for project in $(cat ${PROJECTS_LIST}); do
    check_files ${project}
    if [[ $? -ne 0 ]]; then
      continue
    fi
    
    local tests_count=-1
    local rv_tests_count=-1
    local timed_tests_count=-1
    local timed_rv_tests_count=-1
    local monitors=-1
    local events=-1
    
    local test_log=${OUTPUT_DIR}/${project}/logs/check_project/${project}/test.log
    local test_rv_log=${OUTPUT_DIR}/${project}/logs/check_project/${project}/test-rv.log
    local test_time_log=${OUTPUT_DIR}/${project}/logs/check_project/${project}/test-time.log
    local test_rv_time_log=${OUTPUT_DIR}/${project}/logs/check_project/${project}/test-rv-time.log
    
    tests_count=$(python3 ${SCRIPT_DIR}/check_time_and_test.py ${test_log} | cut -d ',' -f 4)
    rv_tests_count=$(python3 ${SCRIPT_DIR}/check_time_and_test.py ${test_rv_log} | cut -d ',' -f 4)
    timed_tests_count=$(python3 ${SCRIPT_DIR}/check_time_and_test.py ${test_time_log} | cut -d ',' -f 4)
    timed_rv_tests_count=$(python3 ${SCRIPT_DIR}/check_time_and_test.py ${test_rv_time_log} | cut -d ',' -f 4)
    
    monitors=$(grep -a "#monitors: " ${test_rv_log} | cut -d '#' -f 2 | cut -d ' ' -f 2 | paste -sd+ | bc -l)
    events=$(grep -a "#event -" ${test_rv_log} | cut -d '#' -f 2 | cut -d ':' -f 2 | paste -sd+ | bc -l)
    
    echo "${project},${tests_count},${rv_tests_count},${timed_tests_count},${timed_rv_tests_count},${monitors},${events}"
  done
}

pushd ${OUTPUT_DIR} &> /dev/null
check_result
popd &> /dev/null

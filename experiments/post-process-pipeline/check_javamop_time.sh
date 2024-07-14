#!/bin/bash
#
# Check test time and JavaMOP time, check number of tests and failed tests
# Usage: ./check_javamop_time.sh <output-dir> <projects-list>
#
OUTPUT_DIR=$1
PROJECTS_LIST=$2
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ ! -d "${OUTPUT_DIR}" ]]; then
  echo "Cannot find output directory"
  exit 1
fi

if [[ ! -f "${PROJECTS_LIST}" ]]; then
  echo "Cannot find projects list"
fi

function check_result() {
  echo "project,test e2e time,test time,build status,tests,failed tests,javamop e2e time,javamop test time,javamop build status,javamop tests,javamop failed tests"
  
  while read -r project; do
    if [[ ! -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/test.log ]]; then
      # Cannot find project
      continue
    fi

    local test_e2e=-1
    local test_time=-1
    local build_status="unknown"
    local tests=-1
    local failed_tests=-1

    local mop_test_e2e=-1
    local mop_test_time=-1
    local mop_build_status="unknown"
    local mop_tests=-1
    local mop_failed_tests=-1
    
    local monitors=$(grep "#monitors: " test-rv.log  | cut -d ' ' -f 2 | paste -sd+ | bc -l)
    local events=$(grep "#event -" test-rv.log | cut -d ':' -f 2 | paste -sd+ | bc -l)

    local logname="test.log"
    if [[ -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/test-time.log ]]; then
      logname="test-time.log"
    fi
    local check_result=$(python3 ${SCRIPT_DIR}/check_time_and_test.py ${OUTPUT_DIR}/${project}/logs/check_project/${project}/${logname})
    if [[ $? -ne 0 ]]; then
      build_status="script error"
    else
      build_status=$(echo ${check_result} | cut -d ',' -f 1)
      test_e2e=$(echo ${check_result} | cut -d ',' -f 2)
      test_time=$(echo ${check_result} | cut -d ',' -f 3)
      tests=$(echo ${check_result} | cut -d ',' -f 4)
      failed_tests=$(echo ${check_result} | cut -d ',' -f 5)
    fi
    
    if [[ -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/test-rv.log ]]; then
      logname="test-rv.log"
      if [[ -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/test-rv-time.log ]]; then
        logname="test-rv-ime.log"
      fi
      
      check_result=$(python3 ${SCRIPT_DIR}/check_time_and_test.py ${OUTPUT_DIR}/${project}/logs/check_project/${project}/${logname})
      if [[ $? -ne 0 ]]; then
        mop_build_status="script error"
      else
        mop_build_status=$(echo ${check_result} | cut -d ',' -f 1)
        mop_test_e2e=$(echo ${check_result} | cut -d ',' -f 2)
        mop_test_time=$(echo ${check_result} | cut -d ',' -f 3)
        mop_tests=$(echo ${check_result} | cut -d ',' -f 4)
        mop_failed_tests=$(echo ${check_result} | cut -d ',' -f 5)
      fi
    fi
  
    echo "${project},${test_e2e},${test_time},${build_status},${tests},${failed_tests},${mop_test_e2e},${mop_test_time},${mop_build_status},${mop_tests},${mop_failed_tests}"
  done < ${PROJECTS_LIST}
}

check_result

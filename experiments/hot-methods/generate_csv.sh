#!/bin/bash
#
# Generate a csv for each project
# Usage: generate_csv.sh <project-dir> <projects-list> <run-all-log-dir> <output-dir> [is-test-by-test: true]
#
PROJECT_DIR=$1
PROJECTS_LIST=$2
LOG_DIR=$3
OUT_DIR=$4
TEST_BY_TEST=$5
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

function check_inputs() {
  if [[ -z "${PROJECT_DIR}" || -z "${PROJECTS_LIST}"  || -z "${LOG_DIR}" || -z "${OUT_DIR}" ]]; then
    echo "Usage: ./generate_csv.sh <project-dir> <projects-list>  <run-all-log-dir> <out-dir> [is-test-by-test: true]"
    exit 1
  fi
  
  if [[ ! -d "${LOG_DIR}" ]]; then
    echo "run-all-log-dir: not found"
    exit 1
  fi
  
  if [[ -z "${TEST_BY_TEST}" ]]; then
    TEST_BY_TEST=true
  fi
}

# Convert relative path to absolute path
function convert_to_absolute_paths() {
  if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
    PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
  fi
  
  if [[ ! ${LOG_DIR} =~ ^/.* ]]; then
    LOG_DIR=${SCRIPT_DIR}/${LOG_DIR}
  fi
  
  if [[ ! ${OUT_DIR} =~ ^/.* ]]; then
    OUT_DIR=${SCRIPT_DIR}/${OUT_DIR}
  fi
}

function generate_csv_for_project() {
  local project=$1
  echo "Running ${project}"
  mkdir -p ${OUT_DIR}/${project}
  mkdir -p ${OUT_DIR}/${project}/hot-methods
  
  local log_file="${LOG_DIR}/${project}.log"
  local header=$(head -n 1 ${log_file})
  local regex="Total (.+) events and (.+) traces"
  
  if [[ ${header} =~ ${regex} ]]; then
    local events=${BASH_REMATCH[1]}
    local traces=${BASH_REMATCH[2]}
    
    local i=0
    while read -r top_method_line; do
      local method_line=$(echo ${top_method_line} | sed 's/ //g')
      ((i++))
      local method_events=$(echo ${method_line} | cut -d ',' -f 1)
      local method_name=$(echo ${method_line} | cut -d ',' -f 2)
      local method_test=$(echo ${method_line} | cut -d ',' -f 3)
      
      if [[ ${TEST_BY_TEST} == true ]]; then
        python3 ${SCRIPT_DIR}/hot_methods_locator.py ${PROJECT_DIR}/${project} ${method_name} &> ${OUT_DIR}/${project}/hot-methods/${i}.log
      else
        python3 ${SCRIPT_DIR}/hot_methods_locator.py ${PROJECT_DIR}/${project}/.all-traces ${method_name} &> ${OUT_DIR}/${project}/hot-methods/${i}.log
      fi

      local trace_result_line=$(sed -n '2p' ${OUT_DIR}/${project}/hot-methods/${i}.log)
      local method_traces=$(echo ${trace_result_line} | cut -d ',' -f 2)
      local method_isolated_traces=$(echo ${trace_result_line} | cut -d ',' -f 3)
      
      local traces_ratio=0
      if [[ ${traces} -gt 0 ]]; then
        traces_ratio=$(echo "(${method_traces}/${traces})*100" | bc -l)
      fi
      
      echo "${method_name},${traces},${events},${method_events},${method_test},${method_traces},${method_isolated_traces},${traces_ratio}" >> ${OUT_DIR}/${project}/top5.csv
      
    done <<< $(tail -n +2 ${log_file} | head -n 5)
  fi
}

function run_all() {
  while read -r project; do
    if [[ -d "${PROJECT_DIR}/${project}" ]]; then
      generate_csv_for_project ${project}
    fi
  done < ${PROJECTS_LIST}
}

check_inputs
convert_to_absolute_paths
run_all

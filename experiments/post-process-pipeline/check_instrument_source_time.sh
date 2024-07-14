#!/bin/bash
#
# Usage: ./check_instrument_source_time.sh <output-dir> <projects-list>
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


function check_files() {
  project=$1
  
  if [[ ! -f ${OUTPUT_DIR}/${project}/logs/ctw/source/attempt-1.log ]]; then
    echo "Missing attempt log"
    return 1
  fi
  
  if [[ ! -f ${OUTPUT_DIR}/${project}/logs/ctw/${project}.log ]]; then
    echo "Missing ctw log"
    return 1
  fi
}

function check_result() {
  echo "project,instrument all,instrument source"
  # tail -n 4 | grep "real" | cut -d $'\t' -f 2
  # Finished instrument_all in 246524 ms
  while read -r project; do
    check_files ${project}
    if [[ $? -ne 0 ]]; then
      continue
    fi
    
    local attempt_1="${OUTPUT_DIR}/${project}/logs/ctw/source/attempt-1.log"
    local attempt_2="${OUTPUT_DIR}/${project}/logs/ctw/source/attempt-2.log"
    local ctw_log="${OUTPUT_DIR}/${project}/logs/ctw/${project}.log"
    
    local attempt_1_time=$(tail -n 4 ${attempt_1} | grep "real" | cut -d $'\t' -f 2)
    local attempt_1min=0
    local attempt_1sec=0
    
    local attempt_2min=0
    local attempt_2sec=0
  
    regex="(.*)m(.*)s"
    if [[ ${attempt_1_time} =~ $regex ]]; then
      attempt_1min="${BASH_REMATCH[1]}"
      attempt_1sec="${BASH_REMATCH[2]}"
    fi
    
    if [[ -f ${attempt_2} ]]; then
      local attempt_2_time=$(tail -n 4 ${attempt_2} | grep "real" | cut -d $'\t' -f 2)
      if [[ ${attempt_2_time} =~ $regex ]]; then
        attempt_2min="${BASH_REMATCH[1]}"
        attempt_2sec="${BASH_REMATCH[2]}"
      fi
    fi
    
    local instrument_source_time=$(echo "scale=3; ${attempt_1min} * 60 + ${attempt_2min} * 60 + ${attempt_1sec} + ${attempt_2sec}" | bc -l)
    
    local total_ms=$(grep --text "Finished instrument_all in" ${ctw_log} | cut -d ' ' -f 5)
    local total_sec=$(echo "scale=3; ${total_ms}/1000" | bc -l)
    
    echo "${project},${total_sec},${instrument_source_time}"
  done < ${PROJECTS_LIST}
}

check_result

#!/bin/bash
#
# Check run_all_experiments.sh's output
# Usage: ./process_time_table1.sh <output-dir> <projects-list>
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
  
  if [[ ! -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/result.csv ]]; then
    return 1
  fi
  
  if [[ ! -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/test-rv-time.log ]]; then
    echo "${project},no test rv time"
    return 1
  fi
  
  if [[ ! -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/test-time.log ]]; then
    echo "${project},no test time"
    return 1
  fi
}

function check_result() {
  echo "project,without mop e2e,ltw mop e2e,abs overhead,rel overhead"

  while read -r project; do
    check_files ${project}
    if [[ $? -ne 0 ]]; then
      continue
    fi
    
    local f1=${OUTPUT_DIR}/${project}/logs/check_project/${project}/result.csv
    local without_mop_e2e=$(echo "scale=3; $(cat ${f1} | cut -d ',' -f 5)/1000" | bc -l)
    local ltw_mop_e2e=$(echo "scale=3; $(cat ${f1} | cut -d ',' -f 6)/1000" | bc -l)
    
    if [[ ${without_mop_e2e} == "-.001" ]]; then
      echo "${project},-1,-1,-1,-1"
      continue
    fi
    
    if [[ ${ltw_mop_e2e} == "-.001" ]]; then
      echo "${project},-1,-1,-1,-1"
      continue
    fi
    
    local abs_overhead=$(echo "(${ltw_mop_e2e}) - (${without_mop_e2e})" | bc -l)
    local rel_overhead=$(echo "scale=3; ${ltw_mop_e2e}/${without_mop_e2e}" | bc -l) 
    
    echo "${project},${without_mop_e2e},${ltw_mop_e2e},${abs_overhead},${rel_overhead}"
  done < ${PROJECTS_LIST}
}

check_result

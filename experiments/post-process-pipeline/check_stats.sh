#!/bin/bash
#
# Check run_all_experiments.sh's output
# Usage: ./check_stats <output-dir> <projects-list>
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
    echo "Missing result.csv"
    return 1
  fi
  
  if [[ ! -f ${OUTPUT_DIR}/${project}/logs/ctw-time/times.csv ]]; then
    echo "Missing times.csv"
    return 2
  fi
  
  if [[ ! -f ${OUTPUT_DIR}/${project}/logs/removed-hot-methods-time/${project}.log ]]; then
    echo "Missing ${project}.log"
    return 3
  fi
}

function check_result() {
  echo "project,without mop e2e,ltw mop e2e,ctw mop e2e,without hot e2e,abs overhead,rel overhead,without hot over with hot"

  while read -r project; do
    check_files ${project}
    if [[ $? -ne 0 ]]; then
      continue
    fi
    
    local f1=${OUTPUT_DIR}/${project}/logs/check_project/${project}/result.csv
    local without_mop_e2e=$(echo "scale=3; $(cat ${f1} | cut -d ',' -f 5)/1000" | bc -l)
    local ltw_mop_e2e=$(echo "scale=3; $(cat ${f1} | cut -d ',' -f 6)/1000" | bc -l)
    
    local f2=${OUTPUT_DIR}/${project}/logs/ctw-time/times.csv
    local ctw_mop_e2e=$(echo "scale=3; $(cat ${f2} | cut -d ',' -f 3)/1000" | bc -l)
    
    local f3=${OUTPUT_DIR}/${project}/logs/removed-hot-methods-time/${project}.log
    local without_hot_e2e=$(echo "scale=3; $(tail -n 1 ${f3}  | cut -d ' ' -f 3 | cut -d ',' -f 1)/1000" | bc -l)
  
    local abs_overhead=$(echo "${ctw_mop_e2e}-${without_mop_e2e}" | bc -l)
    local rel_overhead=$(echo "scale=3; ${ctw_mop_e2e}/${without_mop_e2e}" | bc -l) 
    local without_hot_reduced=$(echo "scale=3; ${without_hot_e2e}/${ctw_mop_e2e}" | bc -l)
    
    echo "${project},${without_mop_e2e},${ltw_mop_e2e},${ctw_mop_e2e},${without_hot_e2e},${abs_overhead},${rel_overhead},${without_hot_reduced}"
  done < ${PROJECTS_LIST}
}

check_result

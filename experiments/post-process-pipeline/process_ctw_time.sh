#!/bin/bash
#
# Check run_all_experiments.sh's output
# Usage: ./process_ctw_time.sh <output-dir> <projects-list>
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
    echo "${project},no result"
    return 1
  fi
  
  if [[ ! -f ${OUTPUT_DIR}/${project}/logs/ctw/${project}.log ]]; then
    echo "${project},no ctw rv time"
    return 1
  fi
}

function check_result() {
  echo "project,without mop e2e,ltw mop e2e,ctw mop e2e"

  while read -r project; do
    check_files ${project}
    if [[ $? -ne 0 ]]; then
      continue
    fi
    
    local f1=${OUTPUT_DIR}/${project}/logs/check_project/${project}/result.csv
    local ctw_log=${OUTPUT_DIR}/${project}/logs/ctw/${project}.log
    local without_mop_e2e=$(echo "scale=3; $(cat ${f1} | cut -d ',' -f 5)/1000" | bc -l)
    local ltw_mop_e2e=$(echo "scale=3; $(cat ${f1} | cut -d ',' -f 6)/1000" | bc -l)
    local ctw_mop_e2e=$(echo "scale=3; $(tail ${ctw_log} -n 1 | cut -d ' ' -f 5)/1000" | bc -l)
    
    echo "${project},${without_mop_e2e},${ltw_mop_e2e},${ctw_mop_e2e}"
  done < ${PROJECTS_LIST}
}

check_result

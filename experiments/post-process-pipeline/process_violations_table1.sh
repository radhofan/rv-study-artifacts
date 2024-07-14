#!/bin/bash
#
# Use profiler's output to find violations
# Usage: ./process_violations_table1 <output-dir> <projects-list>
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
  echo "project,dynamic,static"
  
  while read -r project; do
    local total_static=0
    local total_dynamic=0
    
    for violations in $(find ${OUTPUT_DIR}/${project}/logs/check_project/${project} -name "violation-counts-ltw-stats*" 2>/dev/null); do
      local static=$(wc -l < ${violations})
      local dynamic=$(cut -d ' ' -f 1 ${violations} | paste -sd+ | bc -l)
      
      total_static=$((total_static + static))
      total_dynamic=$((total_dynamic + dynamic))
    done
    
    echo "${project},${total_dynamic},${total_static}"
  done < ${PROJECTS_LIST}
}

check_result

#!/bin/bash
#
# Check profile_with_mop.sh's output for ALL projects in output-dir
# Usage: ./check_profiler.sh <output-dir>
#
OUTPUT_DIR=$1
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ ! -d "${OUTPUT_DIR}" ]]; then
  echo "Cannot find output directory"
  exit 1
fi

function check_result() {
  echo "project,clone,status,has jfr"

  for project in $(ls ${OUTPUT_DIR}); do
    local status_file="${OUTPUT_DIR}/${project}/logs/mop-profiling/${project}/status.csv"
    if [[ ! -f ${status_file} ]]; then
      echo "${project},-1,-1,-1"
    else
      if [[ $(cut -d ',' -f 3-4 ${status_file}) == "1,0" ]]; then
        if [[ -n $(find ${OUTPUT_DIR}/${project}/projects/${project} -name "profile.jfr") ]]; then
          # MMMP, profile.jfr is in module dirs
          echo "${project},1,1,1"
          continue
        fi
      fi
      
      cat ${status_file}
    fi
  done
}

check_result

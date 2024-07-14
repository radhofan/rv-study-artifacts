#!/bin/bash
#
# Check run_all_experiments.sh's output for ALL projects in output-dir
# Usage: ./check_stats_all.sh <output-dir>
#
OUTPUT_DIR=$1
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ ! -d "${OUTPUT_DIR}" ]]; then
  echo "Cannot find output directory"
  exit 1
fi


function check_result() {
  echo "project,without mop e2e,ltw mop e2e,ctw mop e2e,compile time instrumentation time,load time instrumentation time"

  for project in $(ls ${OUTPUT_DIR}); do
    local without_mop_e2e=-1
    local ltw_mop_e2e=-1
    local ctw_mop_e2e=-1
    local compile_ajc_time=-1
    local load_ajc_time=-1

    if [[ -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/result.csv && -f ${OUTPUT_DIR}/${project}/logs/check_project/${project}/test-rv-time.log ]]; then
      # Only check this if javamop (ltw) works
      local f1=${OUTPUT_DIR}/${project}/logs/check_project/${project}/result.csv
      without_mop_e2e=$(echo "scale=3; $(cat ${f1} | cut -d ',' -f 5)/1000" | bc -l)
      ltw_mop_e2e=$(echo "scale=3; $(cat ${f1} | cut -d ',' -f 6)/1000" | bc -l)
    fi
    
    if [[ -f ${OUTPUT_DIR}/${project}/logs/ctw-time/times.csv ]]; then
      # Only check this if ctw works
      local f2=${OUTPUT_DIR}/${project}/logs/ctw-time/times.csv
      ctw_mop_e2e=$(echo "scale=3; $(cat ${f2} | cut -d ',' -f 3)/1000" | bc -l)
      load_ajc_time=$(echo "${ltw_mop_e2e}-${ctw_mop_e2e}" | bc -l)
      
      if [[ -f ${OUTPUT_DIR}/${project}/logs/ctw/${project}.log ]]; then
        compile_ajc_time=$(python3 ${SCRIPT_DIR}/check_instrumentation_time.py "${OUTPUT_DIR}/${project}/logs/ctw/${project}.log")
      fi
    fi

    echo "${project},${without_mop_e2e},${ltw_mop_e2e},${ctw_mop_e2e},${compile_ajc_time},${load_ajc_time}"
  done
}

check_result

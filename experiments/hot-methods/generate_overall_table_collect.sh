#!/bin/bash
#
# Collect overall table csv
# ** Need to run generate_csv.sh and generate_overall_table.sh  first **
# Usage: generate_overall_table_collect.sh <overall-table-output-dir> <generate-csv-output-dir> <projects-list>
# Output: One single csv for all projects
#
OVERALL_TABLE_OUTPUT_DIR=$1
GENERATE_CSV_OUTPUT_DIR=$2
PROJECTS_LIST=$3
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

check_inputs() {
  if [[ ! -d "${OVERALL_TABLE_OUTPUT_DIR}" || ! -d "${GENERATE_CSV_OUTPUT_DIR}" || ! -f "${PROJECTS_LIST}" ]]; then
    echo "Usage: ./generate_overall_table_collect.sh <overall-table-output-dir> <generate-csv-output-dir> <projects-list>"
    exit 1
  fi
}

function collect_project() {
  local project=$1

  local csv_path=${GENERATE_CSV_OUTPUT_DIR}/${project}/top5.csv
  local result_path=${OVERALL_TABLE_OUTPUT_DIR}/${project}/result.csv
  
  local ratioO=$(awk -F ',' '{printf "%.4f\n", 100*$7/$2}' ${csv_path} | paste -sd+ | bc -l)
  local result=$(cat ${result_path})
  
  echo "${project},${result}${ratioO}"
}

function collect() {
  while read -r project; do
    collect_project ${project}
  done < ${PROJECTS_LIST}
}

check_inputs
collect

#!/bin/bash
#
# Generate `unique-traces-noraw.txt` for each project
# Usage: ./rq2_remove_raw_specs.sh <output-dir> <projects-list> <path-to-converter>
#
OUTPUT_DIR=$1
PROJECTS_LIST=$2
CONVERTER=$3
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ ! -d "${OUTPUT_DIR}" || ! -f "${PROJECTS_LIST}" || ! -f "${CONVERTER}" ]]; then
  echo "Cannot find output directory, projects list, or converter"
  exit 1
fi

function remove_all() {
  while read -r project; do
    local traces_dir="${OUTPUT_DIR}/${project}/projects/${project}/.all-traces"
    if [[ ! -d ${traces_dir} ]]; then
      echo "ERROR: cannot find ${project}"
    else
      echo "Converting ${project}..."
      python3 ${CONVERTER} ${traces_dir}
      if [[ $? -ne 0 ]]; then
        echo "ERROR: cannot convert ${project}"
      fi
    fi
  done < ${PROJECTS_LIST}
}

remove_all

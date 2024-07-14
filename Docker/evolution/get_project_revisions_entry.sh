#!/bin/bash
#
# Run get_project_revisions.sh in Docker
# Before running this script, run `docker login` first.
# Usage: get_project_revisions_entry.sh <projects-list> <revisions> <output-dir> [threads=10] [timeout=86400s]
#
PROJECTS_LIST=$1
REVISIONS=$2
OUTPUT_DIR=$3
THREADS=$4
TIMEOUT=$5

SCRIPT_DIR=$(cd $(dirname $0) && pwd)

function check_input() {
  if [[ ! -f ${PROJECTS_LIST} || -z ${OUTPUT_DIR} ]]; then
    echo "Usage: get_project_revisions_entry.sh <projects-list> <revisions> <output-dir>"
    exit 1
  fi
  
  mkdir -p ${OUTPUT_DIR}
  
  if [[ ! -s ${PROJECTS_LIST} ]]; then
    echo "${PROJECTS_LIST} is empty..."
    exit 0
  fi
  
  if [[ -z ${THREADS} ]]; then
    THREADS=10
  fi
  
  if [[ -z ${TIMEOUT} ]]; then
    TIMEOUT=86400s
  fi
}

function setup_commands() {
  rm -f ${OUTPUT_DIR}/get_project_revisions_cmd.txt

  while read -r project_sha; do
    if [[ -z ${project_sha} ]]; then
      continue
    fi
    
    echo "bash ${SCRIPT_DIR}/get_project_revisions_in_docker.sh ${project_sha} ${REVISIONS} "${OUTPUT_DIR}/get_project_revisions" ${TIMEOUT}" >> ${OUTPUT_DIR}/get_project_revisions_cmd.txt
  done < ${PROJECTS_LIST}
}

check_input
setup_commands
cat ${OUTPUT_DIR}/get_project_revisions_cmd.txt | parallel --jobs ${THREADS} --bar

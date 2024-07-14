#!/bin/bash
#
# Instrument changed jars only
# Usage: instrument_changed_jars.sh <project-dir> <old-classpath-file> <new-classpath-file> <repo-dir> <log-dir> <myaspects.jar>
#
PROJECT_DIR=$1
OLD_CP_FILE=$2
NEW_CP_FILE=$3
REPO_DIR=$4
LOG_DIR=$5
ASPECT_PATH=$6
SCRIPT_DIR=$(cd $(dirname $0) && pwd)

source ${SCRIPT_DIR}/../constants.sh

function check_input() {
  if [[ ! -d ${PROJECT_DIR} || ! -f ${OLD_CP_FILE} || ! -f ${NEW_CP_FILE} || ! -d ${REPO_DIR} || ! -d ${LOG_DIR} || ! -f ${ASPECT_PATH} ]]; then
    echo "Usage bash instrument_changed_jars.sh <project-dir> <old-classpath-file> <new-classpath-file> <repo-dir> <log-dir> <myaspects.jar>"
    exit 1
  fi
  
  if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
    PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
  fi
  
  if [[ ! ${OLD_CP_FILE} =~ ^/.* ]]; then
    OLD_CP_FILE=${SCRIPT_DIR}/${OLD_CP_FILE}
  fi
  
  if [[ ! ${NEW_CP_FILE} =~ ^/.* ]]; then
    NEW_CP_FILE=${SCRIPT_DIR}/${NEW_CP_FILE}
  fi
  
  if [[ ! ${REPO_DIR} =~ ^/.* ]]; then
    REPO_DIR=${SCRIPT_DIR}/${REPO_DIR}
  fi
  
  if [[ ! ${LOG_DIR} =~ ^/.* ]]; then
    LOG_DIR=${SCRIPT_DIR}/${LOG_DIR}
  fi
  
  if [[ ! ${ASPECT_PATH} =~ ^/.* ]]; then
    ASPECT_PATH=${SCRIPT_DIR}/${ASPECT_PATH}
  fi
}

function reinstrument() {
  local reinstrument_start=$(date +%s%3N)  
  local project_name=$(basename ${REPO_DIR})  # The reason we need project name is find_changed_jars.py will check if a jar is in 'project name' or not. So we will not instrument jar outside REPO_DIR

  echo "bash ${SCRIPT_DIR}/instrument_changed_classes.sh ${PROJECT_DIR} ${NEW_CP_FILE} &> ${LOG_DIR}/source.log" > ${SCRIPT_DIR}/.cmd.txt

  local num_of_jar=0
  for jar in $(python3 ${SCRIPT_DIR}/find_changed_jars.py ${OLD_CP_FILE} ${NEW_CP_FILE} ${project_name}); do
    num_of_jar=$((num_of_jar + 1))

    local jar_name=$(echo "${jar}" | rev | cut -d '/' -f 1 | cut -d '.' -f 2- | rev)
    mkdir -p ${LOG_DIR}/${jar_name}
    echo "bash ${SCRIPT_DIR}/../../compile-time-weaving/instrumentation/instrument_jar.sh ${project_name} ${LOG_DIR}/${jar_name} ${jar} ${NEW_CP_FILE} ${ASPECT_PATH}" >> ${SCRIPT_DIR}/.cmd.txt
  done
  
  echo "Instrumenting source and ${num_of_jar} jars"
  cat ${SCRIPT_DIR}/.cmd.txt | parallel --jobs ${INSTRUMENTATION_THREADS} --halt now,fail=1
  local status=$?
  rm -f ${SCRIPT_DIR}/.cmd.txt
  local reinstrument_end=$(date +%s%3N)
  echo "Re-instrumented source and lib! ($((reinstrument_end - reinstrument_start)) ms)"
  
  exit ${status}
}

check_input
reinstrument

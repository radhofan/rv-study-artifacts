#!/bin/bash
#
# Usage: run_tsm.sh <project-name> <main-log-dir> <aspectj-dir>
# Run TSM on CTW projects
# Preconditions:
#   - Already ran run_projects.sh
#   - Already collected tests with scripts/collect_tests.sh
#   - Already collected traces with scripts/collect_traces.py
#   - tracemop is in scripts/projects
#   - Project is in scripts/projects directory (should contain .all-traces and tests.txt)
#   - Project is in ../projects directory and ../projects-withhot directory
#   - Non CTW project is in ../nomop-projects directory
#
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
PROJECT=$1
LOG_DIR=$2
ASPECTJ_DIR=$3

function verify_preconditons() {
  if [[ -z "${PROJECT}" || ! -d "${SCRIPT_DIR}/../../scripts/projects/${PROJECT}" || ! -d "${SCRIPT_DIR}/../../scripts/projects/${PROJECT}/.all-traces" || ! -f "${SCRIPT_DIR}/../../scripts/projects/${PROJECT}/tests.txt" ]]; then
    echo "Project preconditions not satisfied"
    exit 1
  fi
  
  if [[ -z "${LOG_DIR}" ]]; then
    echo "Missing argument: main-log-dir"
    exit 1
  fi
  
  if [[ -z "${ASPECTJ_DIR}" ]]; then
    echo "Missing argument: aspectj-dir"
    exit 1
  fi
  
  mkdir -p ${LOG_DIR}/tsm
}

function run() {
  pushd ${SCRIPT_DIR}/../../scripts
  bash run.sh -r ${PROJECT} -x 2 -o false ${SCRIPT_DIR}/../../extensions ${SCRIPT_DIR}/../../mop ${LOG_DIR}/tsm
  popd
}

function measure() {
  if [[ ! -d "${SCRIPT_DIR}/../projects/${PROJECT}" ]]; then
    cp -r "${SCRIPT_DIR}/../../scripts/projects/${PROJECT}" "${SCRIPT_DIR}/../projects/${PROJECT}"
  fi
  
  if [[ ! -f "${SCRIPT_DIR}/../projects/${PROJECT}/reduced_tests.txt" ]]; then
    cp "${SCRIPT_DIR}/../../scripts/projects/${PROJECT}/reduced_tests.txt" "${SCRIPT_DIR}/../projects/${PROJECT}"
  fi
  
  echo ${PROJECT} > ${SCRIPT_DIR}/.tsm-projects.txt
  pushd ${SCRIPT_DIR}/..
  bash measure_time.sh ${SCRIPT_DIR}/.tsm-projects.txt ${LOG_DIR}/tsm/${PROJECT} ${ASPECTJ_DIR}
  mv ${LOG_DIR}/tsm/${PROJECT}/${PROJECT}.log ${LOG_DIR}/tsm/${PROJECT}/${PROJECT}.all.log
  mv ${LOG_DIR}/tsm/${PROJECT}/times.csv ${LOG_DIR}/tsm/${PROJECT}/time.all.csv
  
  bash measure_time.sh ${SCRIPT_DIR}/.tsm-projects.txt ${LOG_DIR}/tsm/${PROJECT} ${ASPECTJ_DIR} reduced
  mv ${LOG_DIR}/tsm/${PROJECT}/${PROJECT}.log ${LOG_DIR}/tsm/${PROJECT}/${PROJECT}.reduced.log
  mv ${LOG_DIR}/tsm/${PROJECT}/times.csv ${LOG_DIR}/tsm/${PROJECT}/time.reduced.csv
  popd
}

verify_preconditons
run
measure

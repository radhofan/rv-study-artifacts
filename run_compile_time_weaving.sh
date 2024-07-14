#!/bin/bash
#
# Download project then instrument it
# Usage: ./run_compile_time_weaving.sh <repo> <sha> <output-dir> <aspectj-dir>
#
REPO=$1
SHA=$2
OUTPUT_DIR=$3
ASPECTJ_DIR=$4
PROFILER_DIR=$5
STEPS=$6
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
PROJECT_NAME=$(echo ${REPO} | tr / -)
LOG_PREFIX="[TSM-CTW]"

source ${SCRIPT_DIR}/experiments/constants.sh

if [[ -z ${REPO} || -z ${SHA} || -z ${OUTPUT_DIR} || ! -d ${ASPECTJ_DIR} ]]; then
  echo "Usage bash run_compile_time_weaving.sh <repo> <sha> <output-dir> <aspectj-dir>"
  exit 1
fi

function setup() {
  echo "${LOG_PREFIX} start setup"
  if [[ ! -f "${MAVEN_HOME}/lib/ext/measure-extension-1.0.jar" ]]; then
    cp ${SCRIPT_DIR}/extensions/measure-extension-1.0.jar ${MAVEN_HOME}/lib/ext/measure-extension-1.0.jar
  fi
  
  if [[ ! -f "${MAVEN_HOME}/lib/ext/ctw-extension-1.0.jar" ]]; then
    cp ${SCRIPT_DIR}/extensions/ctw-extension-1.0.jar ${MAVEN_HOME}/lib/ext/ctw-extension-1.0.jar
  fi
  
  if [[ ! -f "${MAVEN_HOME}/lib/ext/profiler-extension-1.0.jar" ]]; then
    cp ${SCRIPT_DIR}/extensions/profiler-extension-1.0.jar ${MAVEN_HOME}/lib/ext/profiler-extension-1.0.jar
  fi
  echo "${LOG_PREFIX} end setup"
}

function setup_project() {
  echo "${LOG_PREFIX} start setup_project"
  mkdir -p ${OUTPUT_DIR}
  bash ${SCRIPT_DIR}/experiments/check_projects/check_project.sh ${REPO} ${SHA} ${OUTPUT_DIR} 0-3  # clone, install_measure_time, test_without_rv

  local result=${OUTPUT_DIR}/check_project/${PROJECT_NAME}/result.csv

  if [[ ! -f ${result} ]]; then
    echo "${LOG_PREFIX} missing check_project.sh's result.csv"
    exit 1
  fi
  
  if [[ $(cat ${result} | cut -d ',' -f 2) -ne 1 ]]; then
    echo "${LOG_PREFIX} cannot clone project ${REPO}"
    exit 2
  fi
  
  if [[ $(cat ${result} | cut -d ',' -f 3) -ne 1 ]]; then
    echo "${LOG_PREFIX} cannot test project ${REPO}"
    exit 3
  fi
  echo "${LOG_PREFIX} end setup_project"
}

function ctw_project() {
  echo "${LOG_PREFIX} start ctw_project"
  mkdir -p ${OUTPUT_DIR}/ctw
  mkdir ${SCRIPT_DIR}/compile-time-weaving/projects
  mkdir ${SCRIPT_DIR}/compile-time-weaving/repos
  
  # Setup CTW project and repos
  cp -r ${SCRIPT_DIR}/projects/${PROJECT_NAME} ${SCRIPT_DIR}/compile-time-weaving/projects/${PROJECT_NAME}
  cp -r ${SCRIPT_DIR}/repos/${PROJECT_NAME} ${SCRIPT_DIR}/compile-time-weaving/repos/${PROJECT_NAME}

  # Run CTW
  echo "${REPO},${SHA}" > ${SCRIPT_DIR}/compile-time-weaving/projects.csv
  bash ${SCRIPT_DIR}/compile-time-weaving/run.sh ${SCRIPT_DIR}/compile-time-weaving/projects.csv ${OUTPUT_DIR}/ctw ${SCRIPT_DIR}/mop/props ${ASPECTJ_DIR} instrument # instrument-only
  
  local result=${OUTPUT_DIR}/ctw/${PROJECT_NAME}.log
  if [[ ! -f ${result} || -z $(tail ${result} -n 1 | grep "Finished instrument_all") ]]; then
    echo "${LOG_PREFIX} cannot test project ${REPO} with CTW RV"
    exit 6
  fi
  echo "${LOG_PREFIX} end ctw_project"
}

function run_pipeline() {
  setup
  setup_project
  ctw_project
}

export RVMLOGGINGLEVEL=UNIQUE

uptime
time run_pipeline
uptime

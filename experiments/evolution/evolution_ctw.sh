#!/bin/bash
#
# Usage: evolution_ctw.sh <project-dir> <repo-dir> <myaspects.jar> <aspectj-dir> <rv-monitor-rt.jar>
#
PROJECT_DIR=$1
REPO_DIR=$2
MY_ASPECTS_JAR=$3
ASPECTJ_DIR=$4
RV_MONITOR_RT_JAR=$5
SCRIPT_DIR=$(cd $(dirname $0) && pwd)
LOG_PREFIX="[EVOLUTION-CTW]"

source ${SCRIPT_DIR}/../constants.sh

function check_input() {
  if [[ ! -d ${PROJECT_DIR} || ! -d ${REPO_DIR} || ! -f ${MY_ASPECTS_JAR} || ! -d ${ASPECTJ_DIR} || ! -f ${RV_MONITOR_RT_JAR} ]]; then
    echo "Usage bash evolution_ctw.sh <project-dir> <repo-dir> <myaspects.jar> <aspectj-dir> <rv-monitor-rt.jar>"
    exit 1
  fi
  
  if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
    PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
  fi
  
  if [[ ! ${REPO_DIR} =~ ^/.* ]]; then
    REPO_DIR=${SCRIPT_DIR}/${REPO_DIR}
  fi
}

function install_dependencies() {
  local log_path=${PROJECT_DIR}/.evolution_ctw/logs/install_dependencies.log

  bash ${SCRIPT_DIR}/../../compile-time-weaving/instrumentation/setup_source_for_instrumentation.sh ${REPO_DIR} ${MY_ASPECTS_JAR} ${ASPECTJ_DIR}/lib/aspectjrt.jar ${RV_MONITOR_RT_JAR} ${log_path}
  if [[ $? -ne 0 ]]; then
    echo "${LOG_PREFIX} Unable to perform CTW due to an error in setup_source_for_instrumentation.sh"
    exit 1
  fi
}

function copy_resources() {
  if [[ -f ${PROJECT_DIR}/.evolution_ctw/logs/instrumentation/source/attempt-2.log ]]; then
    # Only need to manually copy resources if we used post compile instrumentation
    while read -r resource_file; do
      if [[ -n ${resource_file} ]]; then
        local resource_dest=$(dirname "$(echo ${resource_file} | cut -d '/' -f 3-)")
        mkdir -p ${PROJECT_DIR}/target/classes/${resource_dest}
        cp ${resource_file} ${PROJECT_DIR}/target/classes/${resource_dest}
      fi
    done <<< $(find .evolution_ctw/uninstrumented-classes -type f ! -name "*.class")  # Search all non *.class file in ${file} directory
    while read -r resource_file; do
      if [[ -n ${resource_file} ]]; then
        local resource_dest=$(dirname "$(echo ${resource_file} | cut -d '/' -f 3-)")
        mkdir -p ${PROJECT_DIR}/target/test-classes/${resource_dest}
        cp ${resource_file} ${PROJECT_DIR}/target/test-classes/${resource_dest}
      fi
    done <<< $(find .evolution_ctw/uninstrumented-test-classes -type f ! -name "*.class")  # Search all non *.class file in ${file} directory
  fi
}

function instrument_all() {
  local project_name=$(basename ${REPO_DIR})  # The reason we need project name is instrument_project.py will check if a jar is in 'project name' or not. So we will not instrument jar outside REPO_DIR
  mkdir -p ${PROJECT_DIR}/.evolution_ctw/logs/instrumentation
  cp -r ${REPO_DIR} "${REPO_DIR}.tmp"

  python3 ${SCRIPT_DIR}/../../compile-time-weaving/instrumentation/instrument_project.py ${project_name} "${REPO_DIR}.tmp" ${PROJECT_DIR}/.evolution_ctw/logs/instrumentation ${PROJECT_DIR}/.evolution_ctw/classpath.txt ${ASPECTJ_DIR}/lib/aspectjrt.jar ${INSTRUMENTATION_THREADS} ${PROJECT_DIR}
  local status=$?
  
  rm -rf "${REPO_DIR}.tmp"
  
  if [[ ${status} -ne 0 ]]; then
    echo "${LOG_PREFIX} Unable to perform CTW due to an error in instrument_project.py"
    exit 1
  fi
  
  copy_resources
}

function instrument_first_time() {
  local instrument_first_time_start=$(date +%s%3N)
  
  # First time using `evolution_ctw.sh`
  mkdir -p ${PROJECT_DIR}/.evolution_ctw
  mkdir -p ${PROJECT_DIR}/.evolution_ctw/logs

  # Save current version of **uninstrumented** code
  cp -r ${PROJECT_DIR}/target/classes ${PROJECT_DIR}/.evolution_ctw/uninstrumented-classes
  cp -r ${PROJECT_DIR}/target/test-classes ${PROJECT_DIR}/.evolution_ctw/uninstrumented-test-classes

  # Get classpath
  echo "${LOG_PREFIX} Getting classpath..."
  local get_classpath_start=$(date +%s%3N)
  
  local build_classpath_start=$(date +%s%3N)
  mvn -Dmaven.repo.local=${REPO_DIR} dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q 2>&1 | cat > ${PROJECT_DIR}/.evolution_ctw/classpath.txt
  local build_classpath_end=$(date +%s%3N)
  echo "${LOG_PREFIX} Built classpath! ($((build_classpath_end - build_classpath_start)) ms)"
  
  local parse_classpath_start=$(date +%s%3N)
  python3 ~/tsm-rv/compile-time-weaving/parse_classpath.py ${PROJECT_DIR}/.evolution_ctw/classpath.txt
  local parse_classpath_end=$(date +%s%3N)
  echo "${LOG_PREFIX} Parsed classpath! ($((parse_classpath_end - parse_classpath_start)) ms)"
  
  local get_classpath_end=$(date +%s%3N)
  echo "${LOG_PREFIX} Got classpath! ($((get_classpath_end - get_classpath_start)) ms)"
  
  
  # Install required jar
  echo "${LOG_PREFIX} Installing dependencies..."
  local install_dependencies_start=$(date +%s%3N)
  install_dependencies
  local install_dependencies_end=$(date +%s%3N)
  echo "${LOG_PREFIX} Installed dependencies! ($((install_dependencies_end - install_dependencies_start)) ms)"
  
  
  # Instrument
  echo "${LOG_PREFIX} Instrumenting project..."
  local instrument_all_start=$(date +%s%3N)
  instrument_all
  local instrument_all_end=$(date +%s%3N)
  echo "${LOG_PREFIX} Instrumented all! ($((instrument_all_end - instrument_all_start)) ms)"
  
  
  # Copy pom.xml for future reference
  cp ${PROJECT_DIR}/pom.xml ${PROJECT_DIR}/.evolution_ctw/previous_pom.xml


  # Mark current time
  touch ${PROJECT_DIR}/.evolution_ctw/timestamp.txt

  
  # Save current version of **instrumented** code
  cp -r ${PROJECT_DIR}/target/classes ${PROJECT_DIR}/.evolution_ctw/instrumented-classes
  cp -r ${PROJECT_DIR}/target/test-classes ${PROJECT_DIR}/.evolution_ctw/instrumented-test-classes
  
  local instrument_first_time_end=$(date +%s%3N)
  echo "${LOG_PREFIX} Instrumented project - initial! ($((instrument_first_time_end - instrument_first_time_start)) ms)"
}

function instrument_again_with_lib() {
  mkdir -p ${PROJECT_DIR}/.evolution_ctw/logs/instrumentation

  # Get classpath
  echo "${LOG_PREFIX} Getting classpath..."
  local get_classpath_start=$(date +%s%3N)
  
  local build_classpath_start=$(date +%s%3N)
  mvn -Dmaven.repo.local=${REPO_DIR} dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q 2>&1 | cat > ${PROJECT_DIR}/.evolution_ctw/current_classpath.txt
  local build_classpath_end=$(date +%s%3N)
  echo "${LOG_PREFIX} Built classpath! ($((build_classpath_end - build_classpath_start)) ms)"
  
  local parse_classpath_start=$(date +%s%3N)
  python3 ~/tsm-rv/compile-time-weaving/parse_classpath.py ${PROJECT_DIR}/.evolution_ctw/current_classpath.txt
  local parse_classpath_end=$(date +%s%3N)
  echo "${LOG_PREFIX} Parsed classpath! ($((parse_classpath_end - parse_classpath_start)) ms)"
  
  local get_classpath_end=$(date +%s%3N)
  echo "${LOG_PREFIX} Got classpath! ($((get_classpath_end - get_classpath_start)) ms)"


  # Reinstrument jar and lib
  cp -r ${REPO_DIR} "${REPO_DIR}.tmp"
  bash ${SCRIPT_DIR}/instrument_changed_jars.sh ${PROJECT_DIR} ${PROJECT_DIR}/.evolution_ctw/classpath.txt ${PROJECT_DIR}/.evolution_ctw/current_classpath.txt ${REPO_DIR} ${PROJECT_DIR}/.evolution_ctw/logs/instrumentation ${MY_ASPECTS_JAR}
  local status=$?
  
  rm -rf "${REPO_DIR}.tmp"
  
  if [[ ${status} -ne 0 ]]; then
    rm ${PROJECT_DIR}/.evolution_ctw/current_classpath.txt
    echo "${LOG_PREFIX} Unable to perform CTW due to an error in instrument_changed_jars.sh"
    exit 1
  fi
  
  mv ${PROJECT_DIR}/.evolution_ctw/current_classpath.txt ${PROJECT_DIR}/.evolution_ctw/classpath.txt
}

function instrument_again() {
  local instrument_again_start=$(date +%s%3N)
  
  rm -rf ${PROJECT_DIR}/.evolution_ctw/logs && mkdir -p ${PROJECT_DIR}/.evolution_ctw/logs
  mkdir -p ${PROJECT_DIR}/.evolution_ctw/logs/instrumentation

  if [[ -z $(diff ${PROJECT_DIR}/pom.xml  ${PROJECT_DIR}/.evolution_ctw/previous_pom.xml) ]]; then
    # pom file not modified, can assume no new dependencies
    echo "${LOG_PREFIX} Instrument only changed classes..."
    bash ${SCRIPT_DIR}/instrument_changed_classes.sh ${PROJECT_DIR} ${PROJECT_DIR}/.evolution_ctw/classpath.txt &> ${PROJECT_DIR}/.evolution_ctw/logs/instrumentation/source.log
    if [[ $? -ne 0 ]]; then
      echo "${LOG_PREFIX} Unable to perform CTW due to an error in instrument_changed_classes.sh"
      exit 1
    fi
  else
    echo "${LOG_PREFIX} Dependencies changed! Instrument both changed classes and changed jars..."
    instrument_again_with_lib
  fi
  
  # Copy pom.xml for future reference
  cp ${PROJECT_DIR}/pom.xml ${PROJECT_DIR}/.evolution_ctw/previous_pom.xml
  
  # Mark current time
  touch ${PROJECT_DIR}/.evolution_ctw/timestamp.txt
  
  local instrument_again_end=$(date +%s%3N)
  echo "${LOG_PREFIX} Instrumented project - again! ($((instrument_again_end - instrument_again_start)) ms)"
}

function instrument() {
  pushd ${PROJECT_DIR} &> /dev/null
  if [[ ! -d ${PROJECT_DIR}/.evolution_ctw || ! -f ${PROJECT_DIR}/.evolution_ctw/classpath.txt || ! -f ${PROJECT_DIR}/.evolution_ctw/previous_pom.xml || ! -f ${PROJECT_DIR}/.evolution_ctw/timestamp.txt ]]; then
    instrument_first_time
  else
    instrument_again
  fi
  popd &> /dev/null
}

export CTW_DISABLE_CHECKING=true
check_input
instrument

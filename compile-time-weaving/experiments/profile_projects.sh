#!/bin/bash
#
# Profile project 3 times: without mop, with mop, without hot methods
# Usage: profile_projects.sh <output-dir> <projects-list> <path-to-profiler> <aspectj-dir> [mode]
#
OUTPUT_DIR=$1
PROJECTS_LIST=$2
PROFILER_PATH=$3
ASPECTJ_DIR=$4
MODE=$5
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

source ${SCRIPT_DIR}/../../experiments/constants.sh
source ${SCRIPT_DIR}/../../experiments/utils.sh

check_inputs() {
  if [[ -z "${OUTPUT_DIR}" || ! -f "${PROJECTS_LIST}" || ! -f "${PROFILER_PATH}" || ! -d "${ASPECTJ_DIR}" ]]; then
    echo "Usage: ./profile_projects.sh <output-dir> <projects-list> <path-to-profiler> <aspectj-dir> [mode]"
    echo "mode: 0 (all), 1 (without-mop), 2 (with-mop), 3 (without-hot-time), 4 (without-mop & with-mop)"
    exit 1
  fi
  
  if [[ -z "${MODE}" ]]; then
    MODE=0
  fi
  
  if [[ "${MODE}" != 0 && "${MODE}" != 1 && "${MODE}" != 2 && "${MODE}" != 3 && "${MODE}" != 4 ]]; then
    echo "mode: 0 (all), 1 (without-mop), 2 (with-mop), 3 (without-hot-time), 4 (without-mop & with-mop)"
    exit 1
  fi
  
  mkdir -p ${OUTPUT_DIR}
}

function convert_to_absolute_paths() {
  if [[ ! ${OUTPUT_DIR} =~ ^/.* ]]; then
    OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
  fi

  if [[ ! ${PROFILER_PATH} =~ ^/.* ]]; then
    PROFILER_PATH=${SCRIPT_DIR}/${PROFILER_PATH}
  fi
  
  if [[ ! ${ASPECTJ_DIR} =~ ^/.* ]]; then
    ASPECTJ_DIR=${SCRIPT_DIR}/${ASPECTJ_DIR}
  fi
}

function collect_time() {
  local start_time=$1
  local end_time=$2
  local log=$3
  local output=$4
  
  local e2e_time=$((end_time - start_time))
  local test_time=$(grep --text "^\[TSM\] JUnit Total Time:" ${log})
  if [[ -n ${test_time} ]]; then
    test_time=$(grep --text "^\[TSM\] JUnit Total Time:" ${log} | cut -d' ' -f5 | paste -sd+ | bc -l)
  else
    test_time=-1
  fi
  
  echo -n "${test_time},${e2e_time}," >> ${output}
}

function without_mop() {
  local project=$1
  pushd ${SCRIPT_DIR}/../projects-without-mop/${project}
  
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  rm -rf profile.jfr
  delete_violations
  
  local log_path=${OUTPUT_DIR}/${project}/time-without-mop.log
  local result_path=${OUTPUT_DIR}/${project}/result.csv

  local start=$(date +%s%3N)
  (uptime && time timeout ${TIMEOUT} mvn -Dmaven.repo.local="${SCRIPT_DIR}/../repos-without-mop/${project}" -Djava.io.tmpdir=/tmp/tsm-rv surefire:test) &> ${log_path}
  
  if [[ $? -ne 0 ]]; then
    # -2 = timeout
    echo -n "-2,-2" >> ${result_path}
    echo "Timeout..." >> ${OUTPUT_DIR}/${project}/out.log
  else
    local end=$(date +%s%3N)
    
    uptime >> ${log_path}
    collect_time ${start} ${end} ${log_path} ${result_path}
  fi
  
  if [[ -f profile.jfr ]]; then
    mv profile.jfr ${OUTPUT_DIR}/${project}/profile_nomop.jfr
  fi
  
  move_violations ${OUTPUT_DIR}/${project} violation-counts-profile-nomop
  
  popd
}

function with_mop() {
  local project=$1
  pushd ${SCRIPT_DIR}/../projects-with-mop/${project}
  
  export MY_ASPECTS_JAR="${SCRIPT_DIR}/aspects/myaspects-${project}.jar"
  export ASPECTJRT_JAR="${ASPECTJ_DIR}/lib/aspectjrt.jar"
  export RV_MONITOR_RT_JAR="${SCRIPT_DIR}/../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar"
  
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  rm -rf profile.jfr
  delete_violations
  
  local log_path=${OUTPUT_DIR}/${project}/time-with-mop.log
  local result_path=${OUTPUT_DIR}/${project}/result.csv
  
  local start=$(date +%s%3N)
  (uptime && time timeout ${TIMEOUT} mvn -Dmaven.repo.local="${SCRIPT_DIR}/../repos-with-mop/${project}" -Djava.io.tmpdir=/tmp/tsm-rv surefire:test) &> ${log_path}
  
  if [[ $? -ne 0 ]]; then
    # -2 = timeout
    echo -n "-2,-2" >> ${result_path}
    echo "Timeout..." >> ${OUTPUT_DIR}/${project}/out.log
  else
    local end=$(date +%s%3N)
    
    uptime >> ${log_path}
    collect_time ${start} ${end} ${log_path} ${result_path}
  fi
  
  if [[ -f profile.jfr ]]; then
    mv profile.jfr ${OUTPUT_DIR}/${project}/profile_mop.jfr
  fi
  
  move_violations ${OUTPUT_DIR}/${project} violation-counts-profile-mop
  
  unset MY_ASPECTS_JAR
  unset ASPECTJRT_JAR
  unset RV_MONITOR_RT_JAR
  popd
  
}

function without_hot_methods() {
  local project=$1
  pushd ${SCRIPT_DIR}/../projects-without-hot-time/${project}
  
  export MY_ASPECTS_JAR="${SCRIPT_DIR}/aspects/myaspects-${project}.jar"
  export ASPECTJRT_JAR="${ASPECTJ_DIR}/lib/aspectjrt.jar"
  export RV_MONITOR_RT_JAR="${SCRIPT_DIR}/../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar"
  
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  rm -rf profile.jfr
  delete_violations
  
  local log_path=${OUTPUT_DIR}/${project}/time-without-hot.log
  local result_path=${OUTPUT_DIR}/${project}/result.csv
  
  local start=$(date +%s%3N)
  (uptime && time timeout ${TIMEOUT} mvn -Dmaven.repo.local="${SCRIPT_DIR}/../repos-without-hot-time/${project}" -Djava.io.tmpdir=/tmp/tsm-rv surefire:test) &> ${log_path}
  
  if [[ $? -ne 0 ]]; then
    # -2 = timeout
    echo -n "-2,-2" >> ${result_path}
    echo "Timeout..." >> ${OUTPUT_DIR}/${project}/out.log
  else
    local end=$(date +%s%3N)
    
    uptime >> ${log_path}
    collect_time ${start} ${end} ${log_path} ${result_path}
  fi
  
  if [[ -f profile.jfr ]]; then
    mv profile.jfr ${OUTPUT_DIR}/${project}/profile_nohot_time.jfr
  fi

  move_violations ${OUTPUT_DIR}/${project} violation-counts-profile-nohot
  
  unset MY_ASPECTS_JAR
  unset ASPECTJRT_JAR
  unset RV_MONITOR_RT_JAR
  
  popd
}


function profile_project() {
  local project=$1

  if [[ "${MODE}" == 0 || "${MODE}" == 1 || "${MODE}" == 4 ]]; then
    if [[ ! -d "${SCRIPT_DIR}/../projects-without-mop/${project}" || ! -d "${SCRIPT_DIR}/../repos-without-mop/${project}" ]]; then
      echo "Missing project or repo (without-mop)"
      return 1
    fi
  
    echo "Without mop..." >> ${OUTPUT_DIR}/${project}/out.log
    without_mop ${project}
  fi
  
  if [[ "${MODE}" == 0 || "${MODE}" == 2 || "${MODE}" == 4 ]]; then
    if [[ ! -d "${SCRIPT_DIR}/../projects-with-mop/${project}" || ! -d "${SCRIPT_DIR}/../repos-with-mop/${project}" ]]; then
      echo "Missing project or repo (with-mop)"
      return 1
    fi
    
    echo "With mop..." >> ${OUTPUT_DIR}/${project}/out.log
    with_mop ${project}
  fi
  
  if [[ "${MODE}" == 0 || "${MODE}" == 3 ]]; then
    if [[ ! -d "${SCRIPT_DIR}/../projects-without-hot-time/${project}" || ! -d "${SCRIPT_DIR}/../repos-without-hot-time/${project}" ]]; then
      echo "Missing project or repo (without-hot)"
      return 1
    fi
    
    echo "Without hot methods..." >> ${OUTPUT_DIR}/${project}/out.log
    without_hot_methods ${project}
  fi
}

function profile_all() {
  export PROFILER_PATH=${PROFILER_PATH}

  while read -r project; do
    mkdir -p ${OUTPUT_DIR}/${project}
    
    if [[ "${MODE}" == 0 || "${MODE}" == 3 ]]; then
      pushd ${SCRIPT_DIR}/../../experiments/junit-measure-time
      mvn -Dmaven.repo.local="${SCRIPT_DIR}/../repos-without-hot-time/${project}" install
      popd
    fi

    echo "Profiling ${project}" >> ${OUTPUT_DIR}/${project}/out.log
    
    export JUNIT_MEASURE_TIME_LISTENER=1
    profile_project ${project}
    export JUNIT_MEASURE_TIME_LISTENER=0
  done < ${PROJECTS_LIST}
}


export RVMLOGGINGLEVEL=UNIQUE
check_inputs
convert_to_absolute_paths
profile_all

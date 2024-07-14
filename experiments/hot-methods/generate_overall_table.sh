#!/bin/bash
#
# Generate overall table csv
# ** Need to run run_without_hot_methods.sh to generate agents first **
# Usage: generate_overall_table.sh <project-dir> <projects-list> <nohot-agents-dir> <agents-dir> <tmp-directory> <extension-directory> <output-dir>
# Output: A csv file: project, with hot methods time, events, monitor, hot ratio, without hot methods time, events, monitor
# This script will run 4 times, with hot methods time, with hot methods traces, without hot methods time, without hot methods traces
#
PROJECT_DIR=$1
PROJECTS_LIST=$2
NOHOT_AGENTS_DIR=$3
ALL_AGENTS_DIR=$4
TMP_DIR=$5
EXTENSION_DIR=$6
OUTPUT_DIR=$7
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

check_inputs() {
  if [[ ! -d "${PROJECT_DIR}" || ! -f "${PROJECTS_LIST}" || ! -d "${NOHOT_AGENTS_DIR}" || ! -d "${ALL_AGENTS_DIR}" || -z "${TMP_DIR}" || ! -d "${EXTENSION_DIR}" || -z "${OUTPUT_DIR}" ]]; then
    echo "Usage: ./generate_overall_table.sh <project-dir> <projects-list> <nohot-agents-dir> <agents-dir> <tmp-directory> <extension-directory> <output-dir>"
    exit 1
  fi
  
  if [[ -d "${TMP_DIR}" ]]; then
    echo "tmp-directory already exists"
    exit 2
  fi
  
  mkdir -p ${OUTPUT_DIR}
}

# Convert relative path to absolute path
function convert_to_absolute_paths() {
  if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
    PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
  fi
  
  if [[ ! ${NOHOT_AGENTS_DIR} =~ ^/.* ]]; then
    NOHOT_AGENTS_DIR=${SCRIPT_DIR}/${NOHOT_AGENTS_DIR}
  fi
  
  if [[ ! ${ALL_AGENTS_DIR} =~ ^/.* ]]; then
    ALL_AGENTS_DIR=${SCRIPT_DIR}/${ALL_AGENTS_DIR}
  fi
  
  if [[ ! ${TMP_DIR} =~ ^/.* ]]; then
    TMP_DIR=${SCRIPT_DIR}/${TMP_DIR}
  fi
  
  if [[ ! ${EXTENSION_DIR} =~ ^/.* ]]; then
    EXTENSION_DIR=${SCRIPT_DIR}/${EXTENSION_DIR}
  fi
  
  if [[ ! ${OUTPUT_DIR} =~ ^/.* ]]; then
    OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
  fi
}

function collect_events_and_monitors() {
  local log=$1
  local traces_file=$2
  local output=$3

  local events=$(grep --text "#event -" ${log})
  if [[ -n ${events} ]]; then
    events=$(grep --text "#event -" ${log} | cut -d: -f2 | paste -sd+ | bc -l)
  else
    events=-1
  fi
  
  local traces=$(grep --text "#monitors:" ${log})
  if [[ -n ${traces} ]]; then
    traces=$(grep --text "#monitors:" ${log} | cut -d: -f2 | paste -sd+ | bc -l)
  else
    traces=-1
  fi
  
  local traces_unique_traces_and_events=$(python3 ${SCRIPT_DIR}/traces_stats.py ${traces_file} | cut -d ',' -f -3)

  echo -n "${events},${traces},${traces_unique_traces_and_events}," >> ${output}
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

# 1. Install no-track-agent.jar
# 2. Enable JUnit time measure plugin
# 3. Run mvn surefire:test and uptime
# 4. Collect e2e and test time
function time_with_hot_methods() {
  local project=$1

  mvn install:install-file -Dfile=${ALL_AGENTS_DIR}/no-track-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" &>/dev/null
  export JUNIT_MEASURE_TIME_LISTENER=1
  rm -rf ${TMP_DIR} && mkdir -p ${TMP_DIR}
  
  local start=$(date +%s%3N)
  (uptime && time mvn -Djava.io.tmpdir=${TMP_DIR} -Dmaven.ext.class.path=${EXTENSION_DIR}/javamop-extension-1.0.jar surefire:test) &> ${OUTPUT_DIR}/${project}/with-hot-time.log
  local end=$(date +%s%3N)
  
  uptime >> ${OUTPUT_DIR}/${project}/with-hot-time.log
  export JUNIT_MEASURE_TIME_LISTENER=0

  collect_time ${start} ${end} ${OUTPUT_DIR}/${project}/with-hot-time.log ${OUTPUT_DIR}/${project}/result.csv
}

# 1. Install track-stats-agent.jar
# 2. Run mvn surefire:test
# 3. Collect events and monitors
function traces_with_hot_methods() {
  local project=$1

  mvn install:install-file -Dfile=${ALL_AGENTS_DIR}/track-stats-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" &>/dev/null
  rm -rf ${TMP_DIR} && mkdir -p ${TMP_DIR}
  
  export TRACEDB_PATH=${OUTPUT_DIR}/${project}/with-hot/.traces
  rm -rf ${TRACEDB_PATH} && mkdir ${TRACEDB_PATH}
  
  mvn -Djava.io.tmpdir=${TMP_DIR} -Dmaven.ext.class.path=${EXTENSION_DIR}/javamop-extension-1.0.jar surefire:test &> ${OUTPUT_DIR}/${project}/with-hot-traces.log
  
  collect_events_and_monitors ${OUTPUT_DIR}/${project}/with-hot-traces.log ${OUTPUT_DIR}/${project}/with-hot/.traces/unique-traces.txt ${OUTPUT_DIR}/${project}/result.csv
}

# 1. Install project's notrack-agent.jar
# 2. Enable JUnit time measure plugin
# 3. Run mvn surefire:test and uptime
# 4. Collect e2e and test time
function time_without_hot_methods() {
  local project=$1

  mvn install:install-file -Dfile=${NOHOT_AGENTS_DIR}/${project}-notrack-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" &>/dev/null
  export JUNIT_MEASURE_TIME_LISTENER=1
  rm -rf ${TMP_DIR} && mkdir -p ${TMP_DIR}
  
  local start=$(date +%s%3N)
  (uptime && time mvn -Djava.io.tmpdir=${TMP_DIR} -Dmaven.ext.class.path=${EXTENSION_DIR}/javamop-extension-1.0.jar surefire:test) &> ${OUTPUT_DIR}/${project}/without-hot-time.log
  local end=$(date +%s%3N)

  uptime >> ${OUTPUT_DIR}/${project}/without-hot-time.log
  export JUNIT_MEASURE_TIME_LISTENER=0
  
  collect_time ${start} ${end} ${OUTPUT_DIR}/${project}/without-hot-time.log ${OUTPUT_DIR}/${project}/result.csv
}

# 1. Install project's track-agent.jar
# 2. Run mvn surefire:test
# 3. Collect events and monitors
function traces_without_hot_methods() {
  local project=$1

  mvn install:install-file -Dfile=${NOHOT_AGENTS_DIR}/${project}-track-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" &>/dev/null
  rm -rf ${TMP_DIR} && mkdir -p ${TMP_DIR}

  export TRACEDB_PATH=${OUTPUT_DIR}/${project}/without-hot/.traces
  rm -rf ${TRACEDB_PATH} && mkdir ${TRACEDB_PATH}
  
  mvn -Djava.io.tmpdir=${TMP_DIR} -Dmaven.ext.class.path=${EXTENSION_DIR}/javamop-extension-1.0.jar surefire:test &> ${OUTPUT_DIR}/${project}/without-hot-traces.log
  
  collect_events_and_monitors ${OUTPUT_DIR}/${project}/without-hot-traces.log ${OUTPUT_DIR}/${project}/without-hot/.traces/unique-traces.txt ${OUTPUT_DIR}/${project}/result.csv
}

function run_project() {
  local project=$1
  
  echo "Running project ${project}"
  
  # Setup directory
  mkdir -p ${OUTPUT_DIR}/${project}
  cp -r ${PROJECT_DIR}/${project} ${OUTPUT_DIR}/${project}/with-hot
  cp -r ${PROJECT_DIR}/${project} ${OUTPUT_DIR}/${project}/without-hot
  
  # Generate result.csv in ${OUTPUT_DIR}/${project}
  # with hot methods test time, e2e time, events from stats, monitors from stats, all traces, unique traces, all events,
  # without hot methods test time, e2e time, events from stats, monitors from stats, all traces, unique traces, all events

  pushd ${OUTPUT_DIR}/${project}/with-hot &>/dev/null
  echo "Measuring time with hot methods"
  time_with_hot_methods ${project}
  echo "Collecting traces with hot methods"
  traces_with_hot_methods ${project}
  popd &>/dev/null
  
  pushd ${OUTPUT_DIR}/${project}/without-hot &>/dev/null
  echo "Measuring time without hot methods"
  time_without_hot_methods ${project}
  echo "Collecting traces without hot methods"
  traces_without_hot_methods ${project}
  popd &>/dev/null
}

function run_all() {
  while read -r project; do
    if [[ -d "${PROJECT_DIR}/${project}" ]]; then
      run_project ${project}
    fi
  done < ${PROJECTS_LIST}
}

check_inputs
convert_to_absolute_paths
run_all

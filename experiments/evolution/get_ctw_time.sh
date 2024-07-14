#!/bin/bash
#
# Measure evolution CTW e2e time
# Usage: get_ctw_time.sh <SHAS-FILE> <repo> <output-dir> <log-dir> <aspectj-dir>
#
SHAS_FILE=$1
REPO=$2
PROJECT_NAME=$(echo ${REPO} | tr / -)
OUTPUT_DIR=$3
LOG_DIR=$4
ASPECTJ_DIR=$5
SCRIPT_DIR=$(cd $(dirname $0) && pwd)

EXTENSIONS_DIR=${SCRIPT_DIR}/../../extensions
MOP_DIR=${SCRIPT_DIR}/../../mop
REPO_DIR=${OUTPUT_DIR}/repo

source ${SCRIPT_DIR}/../constants.sh

function check_input() {
  if [[ ! -f ${SHAS_FILE} || -z ${REPO} || -z ${OUTPUT_DIR} || -z ${LOG_DIR} || ! -d ${ASPECTJ_DIR} ]]; then
    echo "Usage bash get_ctw_time.sh <SHAS-FILE> <repo> <output-dir> <log-dir> <aspectj-dir>"
    exit 1
  fi
  
  if [[ ! ${SHAS_FILE} =~ ^/.* ]]; then
    SHAS_FILE=${SCRIPT_DIR}/${SHAS_FILE}
  fi
  
  if [[ ! ${OUTPUT_DIR} =~ ^/.* ]]; then
    OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
  fi
  
  if [[ ! ${LOG_DIR} =~ ^/.* ]]; then
    LOG_DIR=${SCRIPT_DIR}/${LOG_DIR}
  fi

  mkdir -p ${OUTPUT_DIR}
  mkdir -p ${LOG_DIR}/${PROJECT_NAME}
}

function setup() {
  # Show current script version
  git rev-parse HEAD > ${LOG_DIR}/${PROJECT_NAME}/version.txt

  echo "Setting up environment..."
  # Clone project
  pushd ${OUTPUT_DIR}
  git clone https://github.com/${REPO} project
  if [[ $? -ne 0 ]]; then
    echo "Cannot clone project"
    exit 1
  fi
  popd

  if [[ ! -f "${MAVEN_HOME}/lib/ext/ctw-extension-1.0.jar" ]]; then
    cp ${EXTENSIONS_DIR}/ctw-extension-1.0.jar ${MAVEN_HOME}/lib/ext/ctw-extension-1.0.jar
  fi
}

function download_jar() {
  local sha=$1
  local first_time=$2

  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  mkdir -p /tmp/tsm-rv-target
  
  echo "Downloading jar by running test"
  
  # Downlaod jars
  if [[ ${first_time} == "true" ]]; then
    # Initially, we don't have to worry about adding dependency
    (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR} ${SKIP} test) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/download_jar.log
    local status=$?

    local monitor_rt_jar="${SCRIPT_DIR}/../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar"
    local my_aspects="${SCRIPT_DIR}/../../compile-time-weaving/myaspects.jar"
    bash ${SCRIPT_DIR}/../../compile-time-weaving/instrumentation/setup_source_for_instrumentation.sh ${REPO_DIR} ${my_aspects} ${ASPECTJ_DIR}/lib/aspectjrt.jar ${monitor_rt_jar} ${LOG_DIR}/${PROJECT_NAME}/${sha}/compile.log
  else
    export ADD_DEPENDENCY_ONLY=1  # Use CTW-extension to add dependency (because some jars are instrumented, we need to tell plugin where to find ajc code)
    export MY_ASPECTS_JAR=${SCRIPT_DIR}/../../compile-time-weaving/myaspects.jar
    export ASPECTJRT_JAR=${ASPECTJ_DIR}/lib/aspectjrt.jar
    export RV_MONITOR_RT_JAR=${SCRIPT_DIR}/../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar

    (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR}_uninstrumented ${SKIP} test) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/download_jar.log
    local status=$?
  fi

  echo -n "${sha},${status}," >> ${LOG_DIR}/${PROJECT_NAME}/report.csv
}

function compile() {
  local sha=$1
  local first_time=$2
  echo "Compiling"
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/compile.log

  local start=$(date +%s%3N)

  rm -rf target/classes target/test-classes

  if [[ ${first_time} == "true" ]]; then
    # Initially, we don't have to worry about adding dependency
    (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Dmaven.repo.local=${REPO_DIR} ${SKIP} test-compile) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/compile.log
    local status=$?
  
    cp -r ${REPO_DIR} ${REPO_DIR}_uninstrumented
  else
    export ADD_DEPENDENCY_ONLY=1  # Use CTW-extension to add dependency (because some jars are instrumented, we need to tell plugin where to find ajc code)
    export MY_ASPECTS_JAR=${SCRIPT_DIR}/../../compile-time-weaving/myaspects.jar
    export ASPECTJRT_JAR=${ASPECTJ_DIR}/lib/aspectjrt.jar
    export RV_MONITOR_RT_JAR=${SCRIPT_DIR}/../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar

    (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Dmaven.repo.local=${REPO_DIR}_uninstrumented ${SKIP} test-compile) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/compile.log
    local status=$?

    # copy new jar
    cp -rnv ${REPO_DIR}_uninstrumented/* ${REPO_DIR}/ &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/cp_jar.log
  fi

  local end=$(date +%s%3N)
  local duration=$((end - start))

  unset MY_ASPECTS_JAR
  unset ASPECTJRT_JAR
  unset RV_MONITOR_RT_JAR
  unset ADD_DEPENDENCY_ONLY

  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/compile.log

  echo "[TSM-CTW] Duration: ${duration} ms, status: ${status}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/${sha}/compile.log
  echo -n "${duration},${status}," >> ${LOG_DIR}/${PROJECT_NAME}/report.csv
}

function instrument() {
  local sha=$1

  echo "Instrumenting"
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/instrument.log

  local start=$(date +%s%3N)
  local monitor_rt_jar="${SCRIPT_DIR}/../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar"
  local my_aspects="${SCRIPT_DIR}/../../compile-time-weaving/myaspects.jar"

  (time timeout ${CHECK_PROJECT_TIMEOUT} bash ${SCRIPT_DIR}/evolution_ctw.sh ${OUTPUT_DIR}/project ${REPO_DIR} ${my_aspects} ${ASPECTJ_DIR} ${monitor_rt_jar}) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/instrument.log
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))

  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/instrument.log

  echo "[TSM-CTW] Duration: ${duration} ms, status: ${status}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/${sha}/instrument.log
  echo -n "${duration},${status}," >> ${LOG_DIR}/${PROJECT_NAME}/report.csv
}

function test_with_ctw() {
  local sha=$1
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  echo "Running test with CTW MOP"
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/ctw.log
  
  local start=$(date +%s%3N)
  export MY_ASPECTS_JAR=${SCRIPT_DIR}/../../compile-time-weaving/myaspects.jar
  export ASPECTJRT_JAR=${ASPECTJ_DIR}/lib/aspectjrt.jar
  export RV_MONITOR_RT_JAR=${SCRIPT_DIR}/../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar

  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR} ${SKIP} surefire:test) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/ctw.log
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))

  unset MY_ASPECTS_JAR
  unset ASPECTJRT_JAR
  unset RV_MONITOR_RT_JAR
  
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/ctw.log
  
  mkdir ${LOG_DIR}/${PROJECT_NAME}/${sha}/violations
  for violation in $(find -name "violation-counts"); do
    local name=$(echo "${violation}" | rev | cut -d '/' -f 2 | rev)
    if [[ ${name} != "." ]]; then
      # Is MMMP, add module name to file name
      mv ${violation} ${LOG_DIR}/${PROJECT_NAME}/${sha}/violations/violation-counts_${name}
    else
      mv ${violation} ${LOG_DIR}/${PROJECT_NAME}/${sha}/violations/violation-counts
    fi
  done
  
  echo "[TSM-CTW] Duration: ${duration} ms, status: ${status}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/${sha}/ctw.log
  echo -n "${duration},${status}," >> ${LOG_DIR}/${PROJECT_NAME}/report.csv
}

function check_time() {
  git clone ${OUTPUT_DIR}/project ${OUTPUT_DIR}/project_download_jar &> /dev/null

  local first_time=true
  pushd ${OUTPUT_DIR}/project &> /dev/null
  for sha in $(tac ${SHAS_FILE}); do
    # Start from back
    echo "Checking out to ${sha}"
    mkdir -p ${LOG_DIR}/${PROJECT_NAME}/${sha}
    
    pushd ${OUTPUT_DIR}/project_download_jar &> /dev/null
    git checkout ${sha} &> /dev/null
    download_jar ${sha} ${first_time}
    popd &> /dev/null
    
    local start=$(date +%s%3N)
    git checkout ${sha} &> /dev/null
    compile ${sha} ${first_time}
    instrument ${sha}
    test_with_ctw ${sha}
    local end=$(date +%s%3N)
    local duration=$((end - start))
    
    if [[ -d .evolution_ctw ]]; then
      cp -r .evolution_ctw ${LOG_DIR}/${PROJECT_NAME}/${sha}/.evolution_ctw
    fi

    echo "[TSM-CTW] commit ${sha} end-to-end time ${duration} ms"
    echo "${duration}" >> ${LOG_DIR}/${PROJECT_NAME}/report.csv
    first_time=false
  done
  popd &> /dev/null
}

export RVMLOGGINGLEVEL=UNIQUE
export JUNIT_MEASURE_TIME_LISTENER=1
check_input
setup
check_time

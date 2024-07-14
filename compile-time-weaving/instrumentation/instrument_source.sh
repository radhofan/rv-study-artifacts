#!/bin/bash
#
PROJECT_NAME=$1
REPO_PATH=$2
ASPECTJRT_JAR_PATH=$3
LOG_DIR=$4
CP_FILE=$5
ASPECT_PATH=$6
PROJECT_DIR=$7
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

source ${SCRIPT_DIR}/../../experiments/constants.sh

function check_inputs() {
  if [[ -n ${PROJECT_DIR} ]]; then
    # If PROJECT_DIR is defined, then convert it to absolute path
    if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
      PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
    fi
  else
    # If PROJECT_DIR is not defined, then set it to default path
    PROJECT_DIR="${SCRIPT_DIR}/../projects/${PROJECT_NAME}"
  fi


  if [[ ! -d ${PROJECT_DIR} || ! -d "${REPO_PATH}" ]]; then
    echo "Cannot find project or repos directory"
    exit 1
  fi

  if [[ ! -f "${CP_FILE}" ]]; then
    echo "Cannot find classpath file"
    exit 1
  fi

  if [[ ! -f "${ASPECTJRT_JAR_PATH}" ]]; then
    echo "Cannot find AspectJ"
    exit 1
  fi


  if [[ -z "${LOG_DIR}" ]]; then
    echo "Cannot find log_dir"
    exit 1
  fi

  if [[ -z "${ASPECT_PATH}" ]]; then
    ASPECT_PATH="${SCRIPT_DIR}/../myaspects.jar"
  fi


  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  mkdir -p ${LOG_DIR}
}

function patch_known_issues() {
  # Fix memory issue
  for pom in $(find -name "pom.xml"); do
    echo "Found ${pom}: replace -Xmx with a larger value" &>> ${LOG_DIR}/source.log
    sed -E -i "s/-Xmx[0-9]+[M|m]/-Xmx100G/g" ${pom}
  done
}

function instrument_source_directly() {
  # Simply instrument source code using AspectJ maven plugin
  local attempt=$1
  local log=$2

  echo "[TSM-RV] Instrumenting source code (attempt ${attempt}) using direct instrumentation" &>> ${log}
  start=$(date +%s%3N)

  export MY_ASPECTS_JAR=${ASPECT_PATH}
  export ASPECTJRT_JAR=${ASPECTJRT_JAR_PATH}
  export RV_MONITOR_RT_JAR="${SCRIPT_DIR}/../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar"

  (time timeout ${TIMEOUT} mvn -Dmaven.repo.local=${REPO_PATH} ${SKIP} -Djava.io.tmpdir=/tmp/tsm-rv clean test-compile) &>> ${log}
  local status=$?

  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv

  unset MY_ASPECTS_JAR
  unset ASPECTJRT_JAR
  unset RV_MONITOR_RT_JAR
  return ${status}
}

function instrument_source_with_repair() {
  local attempt=$1
  local log=$2
  local strategy=$3
  
  echo "[TSM-RV] Instrumenting source code (attempt ${attempt}) using ${strategy}" &>> ${log}
  (time bash ${SCRIPT_DIR}/${strategy}/patch.sh ${PROJECT_NAME} ${REPO_PATH} ${ASPECTJRT_JAR_PATH} ${LOG_DIR} ${CP_FILE} ${attempt} ${ASPECT_PATH} ${PROJECT_DIR}) &>> ${log}
  return $?
}

function instrument_source() {
  local attempt=$1
  local log="${LOG_DIR}/attempt-${attempt}.log"
  echo "[TSM-RV] Instrumenting source code (attempt ${attempt})" &>> ${LOG_DIR}/source.log

  if [[ ${attempt} -eq 1 ]]; then
    # First attempt, simply instrument the jar
    instrument_source_directly ${attempt} ${log}
    status=$?
  else
    # Parse previous log then apply a strategy
    local previous_attempt=$((attempt-1))
    local strategy=""
    if [[ ! -f "${LOG_DIR}/attempt-${previous_attempt}.log" ]]; then
      echo "[TSM-RV] Cannot find log for the previous attempt ${JAR} (current ${attempt}, previous ${previous_attempt}" &>>  ${LOG_DIR}/source.log
      exit 1
    fi
    
    if [[ -n $(grep "AJC compiler error" "${LOG_DIR}/attempt-${previous_attempt}.log") ]]; then
      strategy="post-compile-instrumentation"
    elif [[ -n $(grep "Code size too big:" "${LOG_DIR}/attempt-${previous_attempt}.log") ]]; then
      strategy="code-size-too-big-source"
    elif [[ -n $(grep "when weaving type " "${LOG_DIR}/attempt-${previous_attempt}.log") ]]; then
      # This strategy can fix this error as well
      strategy="code-size-too-big-source"
    elif [[ -n $(grep "Unexpected problem whilst preparing bytecode for " "${LOG_DIR}/attempt-${previous_attempt}.log") ]]; then
      # This strategy can fix this error as well
      strategy="code-size-too-big-source"
    elif [[ -n $(grep "^Killed$" "${LOG_DIR}/attempt-${previous_attempt}.log") ]]; then
      strategy="retry"
    fi
    
    if [[ -n $(tail -n 2 "${LOG_DIR}/source.log" | grep ${strategy}) ]]; then
      echo "[TSM-RV] Cannot repair source code (strategy for attempt ${attempt} is ${strategy}, which is the same as the previous attempt)" &>>  ${LOG_DIR}/source.log
      exit 1
    elif [[ ${strategy} == "" ]]; then
      echo "[TSM-RV] No strategy to repair source code (current ${attempt})" &>> ${LOG_DIR}/source.log
      exit 1
    else
      echo "[TSM-RV] Repair source code using ${strategy} (current ${attempt})" &>> ${LOG_DIR}/source.log

      if [[ ${strategy} == "retry" ]]; then
        instrument_source_directly ${attempt} ${log}
        status=$?
      else
        instrument_source_with_repair ${attempt} ${log} ${strategy}
        status=$?
      fi
    fi
  fi

  if [[ ${status} -ne 0 ]]; then
    echo "[TSM-RV] Failed to instrument source code" &>> ${log}
    return 1
  else
    echo "[TSM-RV] Instrumented source code" &>> ${log}
    return 0
  fi
}


function instrument() {
  pushd ${PROJECT_DIR}
  echo "[TSM-RV] Instrumenting source code" &>> ${LOG_DIR}/source.log

  local attempt=0
  
  if [[ -z ${MAX_RETRY} ]]; then
    MAX_RETRY=10
  fi
  
  while [[ ${attempt} -le ${MAX_RETRY} ]]; do
    attempt=$((attempt+1))
    instrument_source ${attempt}
    if [[ $? -eq 0 ]]; then
      echo "[TSM-RV] Instrumented source code" &>> ${LOG_DIR}/source.log
      exit 0
    fi
  done
  
  echo "[TSM-RV] Failed to instrument source code after ${MAX_RETRY} attempts" &>> ${LOG_DIR}/source.log
  exit 1
}

start=$(date +%s%3N)
check_inputs
patch_known_issues
instrument
end=$(date +%s%3N)
duration=$((end - start))
echo "[TSM-RV] Time: ${duration}" &>> ${LOG_DIR}/source.log

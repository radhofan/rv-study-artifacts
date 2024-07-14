#!/bin/bash
#
PROJECT_NAME=$1
LOG_DIR=$2
JAR=$3
CP_FILE=$4
ASPECT_PATH=$5
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
source ${SCRIPT_DIR}/../../experiments/constants.sh

function check_inputs() {
  if [[ -z "${LOG_DIR}" ]]; then
    echo "Cannot find log_dir"
    exit 1
  fi
  
  mkdir -p ${LOG_DIR}
  
  if [[ ! -f "${JAR}" || ! -f "${CP_FILE}" ]]; then
    echo "${JAR}"
    echo "${CP_FILE}"
    echo "Cannot find jar file or classpath file"
    exit 1
  fi
  
  if [[ ! ${JAR} =~ "${PROJECT_NAME}" ]]; then
    echo "[TSM-RV] Will not instrument ${JAR} because the jar is outside maven repository" &>> ${LOG_DIR}/jar.log
    exit 0
  fi
  
  if [[ -f "${JAR}.ctw.lock" && -z "${ASPECT_PATH}" ]]; then
    echo "[TSM-RV] Will not instrument ${JAR}. Instrumented @ $(echo ${JAR}.ctw.lock)" &>> ${LOG_DIR}/jar.log
    exit 0
  fi
  
  if [[ -z "${ASPECT_PATH}" ]]; then
    ASPECT_PATH="${SCRIPT_DIR}/../myaspects.jar"
  fi
  
  JAR_CP=$(cat ${CP_FILE})
}

function patch_known_issues() {
  # Fix multi-release jar
  if [[ -n $(unzip -l "${JAR}" | grep "META-INF/versions/") ]]; then
    echo "Found multi-release jar ${JAR}, removing it" &>> ${LOG_DIR}/jar.log
    zip -d "${JAR}" "META-INF/versions/*"
  fi
  
  # Unsign a jar
  if [[ -n $(unzip -l "${JAR}" | grep "META-INF/.*.SF") ]]; then
    echo "Found signed jar ${JAR}, removing it" &>> ${LOG_DIR}/jar.log
    zip -d ${JAR} "META-INF/*.SF" "META-INF/*.DSA" "META-INF/*.RSA" "META-INF/*.EC"
  fi
}

function instrument_jar_directly() {
  # Simply instrument the jar
  local attempt=$1
  local log=$2
  
  echo "[TSM-RV] Instrumenting ${JAR} (attempt ${attempt}) using direct instrumentation" &>> ${log}
  (time timeout ${TIMEOUT} ajc -Xlint:ignore -1.8 -encoding UTF-8 -showWeaveInfo -classpath ${CLASSPATH}:${JAR_CP} -aspectpath "${ASPECT_PATH}" -inpath "${JAR}" -outjar "${JAR}.tmp") &>> ${log}
  
  return $?
}

function instrument_jar_with_repair() {
  local attempt=$1
  local log=$2
  local strategy=$3
  
  echo "[TSM-RV] Instrumenting ${JAR} (attempt ${attempt}) using ${strategy}" &>> ${log}
  
  (time bash ${SCRIPT_DIR}/${strategy}/patch.sh ${PROJECT_NAME} ${LOG_DIR} ${JAR} ${CP_FILE} ${attempt} ${ASPECT_PATH}) &>> ${log}
  return $?
}

function instrument_jar() {
  local attempt=$1
  local log="${LOG_DIR}/attempt-${attempt}.log"
  echo "[TSM-RV] Instrumenting ${JAR} (attempt ${attempt})" &>> ${LOG_DIR}/jar.log
  local status=0
  
  if [[ ${attempt} -eq 1 ]]; then
    # First attempt, simply instrument the jar
    instrument_jar_directly ${attempt} ${log}
    status=$?
  else
    # Parse previous log then apply a strategy
    local previous_attempt=$((attempt-1))
    local strategy=""
    if [[ ! -f "${LOG_DIR}/attempt-${previous_attempt}.log" ]]; then
      echo "[TSM-RV] Cannot find log for the previous attempt ${JAR} (current ${attempt}, previous ${previous_attempt}" &>>  ${LOG_DIR}/jar.log
      exit 1
    fi
    
    if [[ -n $(grep "Code size too big:" "${LOG_DIR}/attempt-${previous_attempt}.log") ]]; then
      strategy="code-size-too-big"
    elif [[ -n $(grep "when weaving type " "${LOG_DIR}/attempt-${previous_attempt}.log") ]]; then
      # This strategy can fix this error as well
      strategy="code-size-too-big"
    elif [[ -n $(grep "Unexpected problem whilst preparing bytecode for " "${LOG_DIR}/attempt-${previous_attempt}.log") ]]; then
      # This strategy can fix this error as well
      strategy="code-size-too-big"
    elif [[ -n $(grep "^Killed$" "${LOG_DIR}/attempt-${previous_attempt}.log") ]]; then
      strategy="retry"
    fi
    
    if [[ -n $(tail -n 2 "${LOG_DIR}/jar.log" | grep ${strategy}) ]]; then
      echo "[TSM-RV] Cannot repair ${JAR} (strategy for attempt ${attempt} is ${strategy}, which is the same as the previous attempt)" &>>  ${LOG_DIR}/jar.log
      exit 1
    elif [[ ${strategy} == "" ]]; then
      echo "[TSM-RV] No strategy to repair ${JAR} (current ${attempt})" &>> ${LOG_DIR}/jar.log
      exit 1
    else
      echo "[TSM-RV] Repair ${JAR} using ${strategy} (current ${attempt})" &>> ${LOG_DIR}/jar.log

      if [[ ${strategy} == "retry" ]]; then
        instrument_jar_directly ${attempt} ${log}
        status=$?
      else
        instrument_jar_with_repair ${attempt} ${log} ${strategy}
        status=$?
      fi
    fi
  fi
  
  if [[ ${status} -ne 0 ]]; then
    echo "[TSM-RV] Failed to instrument ${JAR}" &>> ${log}
    return 1
  else
    if [[ ! -f "${JAR}.tmp" ]]; then
      echo "[TSM-RV] Failed to instrument ${JAR}" &>> ${log}
      return 1
    fi

    echo "[TSM-RV] Instrumented ${JAR}" &>> ${log}
    mv "${JAR}.tmp" "${JAR}"
    echo $(date +%s%3N) >> ${JAR}.ctw.lock
    return 0
  fi
}

function instrument() {
  echo "[TSM-RV] Instrumenting ${JAR}" &>> ${LOG_DIR}/jar.log

  local attempt=0
  
  if [[ -z ${MAX_RETRY} ]]; then
    MAX_RETRY=10
  fi
  
  while [[ ${attempt} -le ${MAX_RETRY} ]]; do
    attempt=$((attempt+1))
    instrument_jar ${attempt}
    if [[ $? -eq 0 ]]; then
      echo "[TSM-RV] Instrumented ${JAR}" &>> ${LOG_DIR}/jar.log
      exit 0
    fi
  done
  
  echo "[TSM-RV] Failed to instrument ${JAR} after 10 attempts" &>> ${LOG_DIR}/jar.log
  exit 1
}

start=$(date +%s%3N)
check_inputs
patch_known_issues
instrument
end=$(date +%s%3N)
duration=$((end - start))
echo "[TSM-RV] Time: ${duration}" &>> ${LOG_DIR}/jar.log
      
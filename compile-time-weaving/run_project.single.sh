#!/bin/bash
#
# Run project with JavaMOP using compile time weaving
# Usage: run_project.single.sh <path-to-project> <project-name> <maven-repo> <log-dir> <myaspects.jar> <aspectjrt.jar> <rv-monitor-rt.jar>
# This script will instrument both the jar files (using ajc) and the source code (using aspectj-maven-plugin)
#
PROJECT_DIR=$1
PROJECT_NAME=$2
REPO_DIR=$3
LOG_DIR=$4
MY_ASPECTS_JAR=$5
ASPECTJRT_JAR=$6
RV_MONITOR_RT_JAR=$7
LOG_PATH="${LOG_DIR}/${PROJECT_NAME}.log"
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
LOG_PREFIX="[TSM-CTW]"

source ${SCRIPT_DIR}/../experiments/constants.sh


function show_arguments() {
  echo "PROJECT_DIR: ${PROJECT_DIR}"
  echo "PROJECT_NAME: ${PROJECT_NAME}"
  echo "REPO_DIR: ${REPO_DIR}"
  echo "LOG_DIR: ${LOG_DIR}"
  echo "MY_ASPECTS_JAR: ${MY_ASPECTS_JAR}"
  echo "ASPECTJRT_JAR: ${ASPECTJRT_JAR}"
  echo "RV_MONITOR_RT_JAR: ${RV_MONITOR_RT_JAR}"
  echo "LOG_PATH: ${LOG_PATH}"
  echo "SCRIPT_DIR: ${SCRIPT_DIR}"
}

function check_inputs() {
  # show_arguments
  if [[ ! -d "${PROJECT_DIR}" || -z "${PROJECT_NAME}" || ! -f "${MY_ASPECTS_JAR}" || ! -f "${ASPECTJRT_JAR}" || ! -f ${RV_MONITOR_RT_JAR} ]]; then
    echo "Usage: ./run_project.single.sh <path-to-project> <project-name> <maven-repo> <log-dir> <myaspects.jar> <aspectjrt.jar> <rv-monitor-rt.jar>"
    echo "myaspects.jar: path to myaspects.jar file"
    # To generate myaspects.jar, run the following commands
    # export CLASSPATH=${RV_MONITOR_RT_JAR}:${CLASSPATH}
    # ajc -Xlint:ignore -1.8 -encoding UTF-8 -showWeaveInfo -verbose -outjar myaspects.jar props/* 

    echo "aspectjrt.jar: path to aspectjrt.jar file"
    echo "rv-monitor-rt.jar: path to rv-monitor-rt.jar file"
    exit 1
  fi
  
  if [[ ! -f "${MAVEN_HOME}/lib/ext/ctw-extension-1.0.jar" ]]; then
    echo "ctw-extension-1.0.jar not in maven extension directory"
    echo "To build ctw-extension-1.0.jar, cd into javamop-maven-extension, then run mvn package, then find ctw-extension/target/ctw-extension-1.0.jar"
    exit 1
  fi

  mkdir -p ${LOG_DIR}
  mkdir -p ${REPO_DIR}
}

function convert_to_absolute_paths() {
  if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
    PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
  fi
  
  if [[ ! ${REPO_DIR} =~ ^/.* ]]; then
    REPO_DIR=${SCRIPT_DIR}/${REPO_DIR}
  fi
  
  if [[ ! ${LOG_DIR} =~ ^/.* ]]; then
    LOG_DIR=${SCRIPT_DIR}/${LOG_DIR}
  fi
  
  if [[ ! ${MY_ASPECTS_JAR} =~ ^/.* ]]; then
    MY_ASPECTS_JAR=${SCRIPT_DIR}/${MY_ASPECTS_JAR}
  fi
  
  if [[ ! ${ASPECTJRT_JAR} =~ ^/.* ]]; then
    ASPECTJRT_JAR=${SCRIPT_DIR}/${ASPECTJRT_JAR}
  fi
  
  if [[ ! ${RV_MONITOR_RT_JAR} =~ ^/.* ]]; then
    RV_MONITOR_RT_JAR=${SCRIPT_DIR}/${RV_MONITOR_RT_JAR}
  fi
}

function run() {
  pushd ${PROJECT_DIR}
  
  if [[ -f ${PROJECT_DIR}/.ctw.lock ]]; then
    echo "${LOG_PREFIX} Will not instrument project ${PROJECT_NAME}. Instrumented @ $(cat ${PROJECT_DIR}/.ctw.lock)" &>> ${LOG_PATH}
    exit 1
  fi
  
  echo "${LOG_PREFIX} Downloading jar files" &>> ${LOG_PATH}
  download_jars
  if [[ $? -ne 0 ]]; then
    echo "${LOG_PREFIX} Failed to download jar files" &>> ${LOG_PATH}
    exit 1
  else
    echo "${LOG_PREFIX} Downloaded jar files" &>> ${LOG_PATH}
  fi
  
  echo "${LOG_PREFIX} Instrumenting jar files" &>> ${LOG_PATH}
  instrument_jars
  local failed_jars=$?
  if [[ ${failed_jars} -ne 0 ]]; then
    echo "${LOG_PREFIX} Failed to instrument ${failed_jars} jar files" &>> ${LOG_PATH}
    exit 2
  else
    echo "${LOG_PREFIX} Instrumented all jar files" &>> ${LOG_PATH}
  fi
  
  echo "${LOG_PREFIX} Installing aspect jar" &>> ${LOG_PATH}
  mvn -Dmaven.repo.local="${REPO_DIR}/${PROJECT_NAME}" install:install-file -Dfile=${MY_ASPECTS_JAR} -DgroupId="javamop-aspect" -DartifactId="javamop-aspect" -Dversion="1.0" -Dpackaging="jar" &>> ${LOG_PATH}
  mvn -Dmaven.repo.local="${REPO_DIR}/${PROJECT_NAME}" install:install-file -Dfile=${ASPECTJRT_JAR} -DgroupId="aspectjrt" -DartifactId="aspectjrt" -Dversion="1.0" -Dpackaging="jar" &>> ${LOG_PATH}
  mvn -Dmaven.repo.local="${REPO_DIR}/${PROJECT_NAME}" install:install-file -Dfile=${RV_MONITOR_RT_JAR} -DgroupId="rv-monitor-rt" -DartifactId="rv-monitor-rt" -Dversion="1.0" -Dpackaging="jar" &>> ${LOG_PATH}
  if [[ $? -ne 0 ]]; then
    echo "${LOG_PREFIX} Failed to install aspect jar" &>> ${LOG_PATH}
    exit 3
  fi
  
  echo "${LOG_PREFIX} Instrumenting source code" &>> ${LOG_PATH}
  instrument_source
  if [[ $? -ne 0 ]]; then
    echo "${LOG_PREFIX} Failed to instrument source code" &>> ${LOG_PATH}
    exit 4
  fi
  
  echo "${LOG_PREFIX} Monitoring project" &>> ${LOG_PATH}
  monitor_project
  if [[ $? -ne 0 ]]; then
    echo "${LOG_PREFIX} Failed to monitor project" &>> ${LOG_PATH}
    exit 5
  fi
  
  echo $(date +%s%3N) >> ${PROJECT_DIR}/.ctw.lock
}

function download_jars() {
  if [[ -d "${REPO_DIR}/${PROJECT_NAME}" ]]; then
    # Already downloaded
    echo "${LOG_PREFIX} Will not download jars" &>> ${LOG_PATH}
    return 0
  fi

  local start=$(date +%s%3N)
  
  timeout ${TIMEOUT} mvn -Dmaven.repo.local="${REPO_DIR}/${PROJECT_NAME}" ${SKIP} clean test &>> ${LOG_PATH}
  local status=$?
  
  local end=$(date +%s%3N)
  local duration=$((end - start))
  echo "${LOG_PREFIX} Finished download_jars in ${duration} ms" &>> ${LOG_PATH}

  return ${status}
}

function instrument_jars() {
  local start=$(date +%s%3N)
  
  local cp_file=".classpath.txt"
  rm -rf ${cp_file}
  
  # Need to use 2>&1 | cat > because projects like OpenNMS/newts (b31501e) doesn't work if we simply use >
  timeout ${TIMEOUT} mvn -Dmaven.repo.local="${REPO_DIR}/${PROJECT_NAME}" dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q 2>&1 | cat > ${cp_file}
  if [[ $? -ne 0 ]]; then
    echo "${LOG_PREFIX} Cannot get classpath" &>> ${LOG_PATH}
    # Cannot get all the jars
    return 999
  fi

  # Remove duplicate jars
  python3 ${SCRIPT_DIR}/parse_classpath.py ${cp_file}
  local jar_cp=$(cat ${cp_file})
  rm -rf ${cp_file}

  echo "${LOG_PREFIX} Classpath: ${jar_cp}" &>> ${LOG_PATH}
  
  local error_list=()
  IFS=':' read -ra CP <<< $jar_cp

  for jar in "${CP[@]}";  do
    echo "${LOG_PREFIX} Instrumenting ${jar}" &>> ${LOG_PATH}
    
    if [[ ! ${jar} =~ "${PROJECT_NAME}" ]]; then
      echo "${LOG_PREFIX} Will not instrument ${jar} because the jar is outside maven repository" &>> ${LOG_PATH}
      continue
    fi
    
    if [[ -f "${jar}.ctw.lock" ]]; then
      echo "${LOG_PREFIX} Will not instrument ${jar}. Instrumented @ $(echo ${jar}.ctw.lock)" &>> ${LOG_PATH}
      continue
    fi

    if [[ -n $(unzip -l "${jar}" | grep "META-INF/versions/") ]]; then
      # Is multi-release jar
      zip -d "${jar}" "META-INF/versions/*"
    fi

    timeout ${TIMEOUT} ajc -Xlint:ignore -1.8 -encoding UTF-8 -classpath ${CLASSPATH}:${jar_cp} -aspectpath ${MY_ASPECTS_JAR} -inpath "${jar}" -outjar "${jar}.tmp" &>> ${LOG_PATH}

    if [[ $? -ne 0 ]]; then
      echo "${LOG_PREFIX} Failed to instrument ${jar}" &>> ${LOG_PATH}
      error_list+=(${jar})
    else
      echo "${LOG_PREFIX} Instrumented ${jar}" &>> ${LOG_PATH}
      mv "${jar}.tmp" "${jar}"

      echo $(date +%s%3N) >> ${jar}.ctw.lock
    fi
  done
  
  local end=$(date +%s%3N)
  local duration=$((end - start))
  echo "${LOG_PREFIX} Finished instrument_jars in ${duration} ms" &>> ${LOG_PATH}
  
  return ${#error_list[@]}
}
  
function instrument_source() {
  mkdir -p /tmp/tsm-rv
  local start=$(date +%s%3N)
  
  export MY_ASPECTS_JAR=${MY_ASPECTS_JAR}
  export ASPECTJRT_JAR=${ASPECTJRT_JAR}
  export RV_MONITOR_RT_JAR=${RV_MONITOR_RT_JAR}

  timeout ${TIMEOUT} mvn -Dmaven.repo.local="${REPO_DIR}/${PROJECT_NAME}" ${SKIP} -Djava.io.tmpdir=/tmp/tsm-rv clean test-compile &>> ${LOG_PATH}
  local status=$?
  
  local end=$(date +%s%3N)
  local duration=$((end - start))
  echo "${LOG_PREFIX} Finished instrument_source in ${duration} ms" &>> ${LOG_PATH}
  
  chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv
  return ${status}
}

function monitor_project() {
  mkdir -p /tmp/tsm-rv
  local start=$(date +%s%3N)
  
  timeout ${TIMEOUT} mvn -Dmaven.repo.local="${REPO_DIR}/${PROJECT_NAME}" ${SKIP} -Djava.io.tmpdir=/tmp/tsm-rv surefire:test &>> ${LOG_PATH}
  local status=$?
  
  local end=$(date +%s%3N)
  local duration=$((end - start))
  echo "${LOG_PREFIX} Finished monitor_project in ${duration} ms" &>> ${LOG_PATH}
  
  chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv
  return ${status}
}

export RVMLOGGINGLEVEL=UNIQUE
check_inputs
convert_to_absolute_paths
run

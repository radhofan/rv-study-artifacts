#!/bin/bash
#
# Measure emop e2e time
# Usage: get_emop_time.sh <SHAS-FILE> <repo> <output-dir> <log-dir> [async-profiler-dir]
#
SHAS_FILE=$1
REPO=$2
PROJECT_NAME=$(echo ${REPO} | tr / -)
OUTPUT_DIR=$3
LOG_DIR=$4
PROFILER=$5
SCRIPT_DIR=$(cd $(dirname $0) && pwd)

EXTENSIONS_DIR=${SCRIPT_DIR}/../../extensions
MOP_DIR=${SCRIPT_DIR}/../../mop
REPO_DIR=${OUTPUT_DIR}/repo

source ${SCRIPT_DIR}/../constants.sh
source ${SCRIPT_DIR}/../utils.sh

function check_input() {
  if [[ ! -f ${SHAS_FILE} || -z ${REPO} || -z ${OUTPUT_DIR} || -z ${LOG_DIR} ]]; then
    echo "Usage bash get_emop_time.sh <SHAS-FILE> <repo> <output-dir> <log-dir>"
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
  
  if [[ -n ${PROFILER} && -f ${PROFILER} ]]; then
    if [[ ! ${PROFILER} =~ ^/.* ]]; then
      PROFILER=${SCRIPT_DIR}/${PROFILER}
    fi
  else
    PROFILER=""
  fi

  mkdir -p ${OUTPUT_DIR}
  mkdir -p ${LOG_DIR}/${PROJECT_NAME}
}

function setup() {
  echo "Setting up environment..."
  
  # Install JavaMOP agent
  mvn -Dmaven.repo.local=${REPO_DIR} install:install-file -Dfile=${MOP_DIR}/agents/no-track-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" &> /dev/null
  
  # Install STARTS
  git clone https://github.com/TestingResearchIllinois/starts
  if [[ $? -ne 0 ]]; then
    echo "Cannot clone STARTS"
    exit 1
  fi

  pushd starts
  git checkout impacted-both-ways
  mvn -Dmaven.repo.local=${REPO_DIR} -DskipTests -Dinvoker.skip install
  if [[ $? -ne 0 ]]; then
    echo "Cannot install STARTS"
    exit 1
  fi
  popd
  
  rm -rf starts
  
  # Install eMOP
  git clone https://github.com/SoftEngResearch/emop
  if [[ $? -ne 0 ]]; then
    echo "Cannot clone eMOP"
    exit 1
  fi
  
  pushd emop

  # Delete Object_NoCloneMonitor
  rm emop-maven-plugin/src/main/resources/weaved-specs/Object_NoCloneMonitorAspect.aj
  mvn -Dmaven.repo.local=${REPO_DIR} install
  if [[ $? -ne 0 ]]; then
    echo "Cannot install eMOP"
    exit 1
  fi
  popd
  rm -rf emop
  
  if [[ ! -f "${MAVEN_HOME}/lib/ext/emop-extension.jar" ]]; then
    if [[ ! -f "${SCRIPT_DIR}/emop-extension/emop-extension.jar" ]]; then
      pushd ${SCRIPT_DIR}/emop-extension/
        mvn -Dmaven.repo.local=${REPO_DIR} package
        cp target/emop-extension-1.0-SNAPSHOT.jar ${MAVEN_HOME}/lib/ext/emop-extension.jar
      popd
    else
      cp "${SCRIPT_DIR}/emop-extension/emop-extension.jar" ${MAVEN_HOME}/lib/ext/emop-extension.jar
    fi
  fi
  
  if [[ ! -f "${MAVEN_HOME}/lib/ext/profiler-extension-1.0.jar" ]]; then
    cp ${EXTENSIONS_DIR}/profiler-extension-1.0.jar ${MAVEN_HOME}/lib/ext/profiler-extension-1.0.jar
  fi
  
  # Clone project
  pushd ${OUTPUT_DIR}
  git clone https://github.com/${REPO} project
  if [[ $? -ne 0 ]]; then
    echo "Cannot clone project"
    exit 1
  fi
  popd
}

function download_jar() {
  local sha=$1
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  mkdir -p /tmp/tsm-rv-target
  
  echo "Downloading jar by running test"
  
  # Downlaod jars
  export ADD_AGENT=0  # Use extension to update surefire version but don't add agent
  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR} ${SKIP} -Dmaven.ext.class.path="${EXTENSIONS_DIR}/javamop-extension-1.0.jar" test) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/download_jar.log
  unset ADD_AGENT
}

function test() {
  local sha=$1
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  echo "Running test without MOP"

  export ADD_AGENT=0  # Use extension to update surefire version but don't add agent
  local start=$(date +%s%3N)
  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR} ${SKIP} -Dmaven.ext.class.path="${EXTENSIONS_DIR}/javamop-extension-1.0.jar" test) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/test.log
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  unset ADD_AGENT
  
  echo "[TSM-CTW] Duration: ${duration} ms, status: ${status}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/${sha}/test.log
  echo -n "${sha},${duration},${status}," >> ${LOG_DIR}/${PROJECT_NAME}/report.csv
}

function test_with_mop() {
  local sha=$1
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  if [[ -n ${PROFILER} ]]; then
    export PROFILER_PATH=${PROFILER}
    export COLLECT_TRACES=1
  fi
  
  echo "Running test test MOP"
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv.log
  
  local start=$(date +%s%3N)
  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR} ${SKIP} -Dmaven.ext.class.path="${EXTENSIONS_DIR}/javamop-extension-1.0.jar" test) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv.log
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv.log
  
  mkdir ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv-violations
  for violation in $(find -name "violation-counts"); do
    local name=$(echo "${violation}" | rev | cut -d '/' -f 2 | rev)
    if [[ ${name} != "." ]]; then
      # Is MMMP, add module name to file name
      mv ${violation} ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv-violations/violation-counts_${name}
    else
      mv ${violation} ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv-violations/violation-counts
    fi
  done
  
  if [[ -n ${PROFILER} ]]; then
    unset PROFILER_PATH
    unset COLLECT_TRACES
    
    if [[ -n $(find -name "profile.jfr") ]]; then
      mkdir ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv-profiler
      move_jfr ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv-profiler profile.jfr
    fi
  fi
  
  echo "[TSM-CTW] Duration: ${duration} ms, status: ${status}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/${sha}/test-rv.log
  echo -n "${duration},${status}," >> ${LOG_DIR}/${PROJECT_NAME}/report.csv
}

function emop_ps1c() {
  local sha=$1
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  if [[ -n ${PROFILER} ]]; then
    export PROFILER_PATH=${PROFILER}
    export COLLECT_TRACES=1
  fi
  
  echo "Running test with eMOP (PS1c)"
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps1c.log
  
  local start=$(date +%s%3N)
  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR} ${SKIP} -Dmaven.ext.class.path="${EXTENSIONS_DIR}/javamop-extension-1.0.jar" -DincludeNonAffected=false -DclosureOption=PS1 -DjavamopAgent="${REPO_DIR}/javamop-agent-ps1c/javamop-agent-ps1c/1.0/javamop-agent-ps1c-1.0.jar" emop:rps) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps1c.log
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps1c.log
  
  mkdir ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps1c-violations
  for violation in $(find -name "violation-counts"); do
    local name=$(echo "${violation}" | rev | cut -d '/' -f 2 | rev)
    if [[ ${name} != "." ]]; then
      # Is MMMP, add module name to file name
      mv ${violation} ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps1c-violations/violation-counts_${name}
    else
      mv ${violation} ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps1c-violations/violation-counts
    fi
  done
  
  if [[ -d .starts ]]; then
    cp -r .starts ${LOG_DIR}/${PROJECT_NAME}/${sha}/.ps1c_starts
  fi

  if [[ -n ${PROFILER} ]]; then
    unset PROFILER_PATH
    unset COLLECT_TRACES
    
    if [[ -n $(find -name "profile.jfr") ]]; then
      mkdir ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps1c-profiler
      move_jfr ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps1c-profiler profile.jfr
    fi
  fi
  
  echo "[TSM-CTW] Duration: ${duration} ms, status: ${status}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps1c.log
  echo -n "${duration},${status}," >> ${LOG_DIR}/${PROJECT_NAME}/report.csv
}

function emop_ps3cl() {
  local sha=$1
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  if [[ -n ${PROFILER} ]]; then
    export PROFILER_PATH=${PROFILER}
    export COLLECT_TRACES=1
  fi
  
  echo "Running test with eMOP (PS3cl)"
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps3cl.log
  
  local start=$(date +%s%3N)
  (time timeout ${CHECK_PROJECT_TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local=${REPO_DIR} ${SKIP} -Dmaven.ext.class.path="${EXTENSIONS_DIR}/javamop-extension-1.0.jar" -DincludeNonAffected=false -DincludeLibraries=false -DclosureOption=PS3 -DjavamopAgent="${REPO_DIR}/javamop-agent-ps3cl/javamop-agent-ps3cl/1.0/javamop-agent-ps3cl-1.0.jar" emop:rps) &>> ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps3cl.log
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  
  uptime >> ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps3cl.log
  
  mkdir ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps3cl-violations
  for violation in $(find -name "violation-counts"); do
    local name=$(echo "${violation}" | rev | cut -d '/' -f 2 | rev)
    if [[ ${name} != "." ]]; then
      # Is MMMP, add module name to file name
      mv ${violation} ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps3cl-violations/violation-counts_${name}
    else
      mv ${violation} ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps3cl-violations/violation-counts
    fi
  done
  
  if [[ -d .starts ]]; then
    cp -r .starts ${LOG_DIR}/${PROJECT_NAME}/${sha}/.ps3cl_starts
  fi
  
  if [[ -n ${PROFILER} ]]; then
    unset PROFILER_PATH
    unset COLLECT_TRACES
    
    if [[ -n $(find -name "profile.jfr") ]]; then
      mkdir ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps3cl-profiler
      move_jfr ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps3cl-profiler profile.jfr
    fi
  fi
  
  echo "[TSM-CTW] Duration: ${duration} ms, status: ${status}" |& tee -a ${LOG_DIR}/${PROJECT_NAME}/${sha}/emop_ps3cl.log
  echo "${duration},${status}" >> ${LOG_DIR}/${PROJECT_NAME}/report.csv
}

function check_time() {
  git clone ${OUTPUT_DIR}/project ${OUTPUT_DIR}/project_download_jar &> /dev/null
  git clone ${OUTPUT_DIR}/project ${OUTPUT_DIR}/project_test &> /dev/null
  git clone ${OUTPUT_DIR}/project ${OUTPUT_DIR}/project_test_with_mop &> /dev/null
  git clone ${OUTPUT_DIR}/project ${OUTPUT_DIR}/project_ps1c &> /dev/null
  git clone ${OUTPUT_DIR}/project ${OUTPUT_DIR}/project_ps3cl &> /dev/null

  # Agent for test with mop
  mvn -Dmaven.repo.local=${REPO_DIR} install:install-file -Dfile=${MOP_DIR}/agents/no-track-agent.jar -DgroupId="javamop-agent-mop" -DartifactId="javamop-agent-mop" -Dversion="1.0" -Dpackaging="jar" &> /dev/null
  mvn -Dmaven.repo.local=${REPO_DIR} install:install-file -Dfile=${MOP_DIR}/agents/no-track-agent.jar -DgroupId="javamop-agent-ps1c" -DartifactId="javamop-agent-ps1c" -Dversion="1.0" -Dpackaging="jar" &> /dev/null
  mvn -Dmaven.repo.local=${REPO_DIR} install:install-file -Dfile=${MOP_DIR}/agents/no-track-agent.jar -DgroupId="javamop-agent-ps3cl" -DartifactId="javamop-agent-ps3cl" -Dversion="1.0" -Dpackaging="jar" &> /dev/null

  pushd ${OUTPUT_DIR}/project &> /dev/null
  for sha in $(tac ${SHAS_FILE}); do
    # Start from back
    echo "Checking out to ${sha}"
    mkdir -p ${LOG_DIR}/${PROJECT_NAME}/${sha}
    
    pushd ${OUTPUT_DIR}/project_download_jar
    git checkout ${sha} &> /dev/null
    download_jar ${sha}
    popd
    
    pushd ${OUTPUT_DIR}/project_test
    git checkout ${sha} &> /dev/null
    test ${sha}
    popd
    
    pushd ${OUTPUT_DIR}/project_test_with_mop
    export MOP_AGENT_PATH="-javaagent:\${settings.localRepository}/javamop-agent-mop/javamop-agent-mop/1.0/javamop-agent-mop-1.0.jar"
    git checkout ${sha} &> /dev/null
    test_with_mop ${sha}
    unset MOP_AGENT_PATH
    popd
    
    pushd ${OUTPUT_DIR}/project_ps1c
    export MOP_AGENT_PATH="-javaagent:\${settings.localRepository}/javamop-agent-ps1c/javamop-agent-ps1c/1.0/javamop-agent-ps1c-1.0.jar"
    git checkout ${sha} &> /dev/null
    emop_ps1c ${sha}
    unset MOP_AGENT_PATH
    popd
    
    pushd ${OUTPUT_DIR}/project_ps3cl
    export MOP_AGENT_PATH="-javaagent:\${settings.localRepository}/javamop-agent-ps3cl/javamop-agent-ps3cl/1.0/javamop-agent-ps3cl-1.0.jar"
    git checkout ${sha} &> /dev/null
    emop_ps3cl ${sha}
    unset MOP_AGENT_PATH
    popd
  done
  popd &> /dev/null
}

export RVMLOGGINGLEVEL=UNIQUE
export JUNIT_MEASURE_TIME_LISTENER=1
check_input
setup
check_time

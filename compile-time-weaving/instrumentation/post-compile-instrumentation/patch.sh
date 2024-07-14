#!/bin/bash
#
PROJECT_NAME=$1
REPO_PATH=$2
ASPECTJRT_JAR=$3
LOG_DIR=$4
CP_FILE=$5
ATTEMPT=$6
ASPECT_PATH=$7
PROJECT_DIR=$8
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
JAR_CP=$(cat ${CP_FILE})

source ${SCRIPT_DIR}/../../../experiments/constants.sh

if [[ -z ${PROJECT_DIR} ]]; then
  PROJECT_DIR="${SCRIPT_DIR}/../../projects/${PROJECT_NAME}"
fi

function instrument_source() {
  pushd ${PROJECT_DIR}
  
  # Clean and re-compile
  echo "Compiling"
  time timeout 3600s mvn -Dmaven.repo.local=${REPO_PATH} ${SKIP} -Djava.io.tmpdir=/tmp/tsm-rv clean test-compile
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  # Post-compile instrumentation
  echo "Instrumenting source"
  ajc -Xlint:ignore -1.8 -encoding UTF-8 -showWeaveInfo -inpath target/classes -d target/instrumented-classes -aspectpath ${ASPECT_PATH} -classpath ${JAR_CP}:${SCRIPT_DIR}/../../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${CLASSPATH}
  if [[ $? -ne 0 || ! -d "target/instrumented-classes" ]]; then
    echo "Cannot instrument code"
    exit 1
  fi
  
  echo "Instrumenting test"
  ajc -Xlint:ignore -1.8 -encoding UTF-8 -showWeaveInfo -inpath target/test-classes -d target/instrumented-test-classes -aspectpath ${ASPECT_PATH} -classpath ${JAR_CP}:${SCRIPT_DIR}/../../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:target/classes:${CLASSPATH}
  if [[ $? -ne 0 || ! -d "target/instrumented-test-classes" ]]; then
    echo "Cannot instrument test"
    exit 1
  fi
  
  rm -rf target/classes target/test-classes
  mv target/instrumented-classes target/classes
  mv target/instrumented-test-classes target/test-classes
  
  popd
}

instrument_source

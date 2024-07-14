#!/bin/bash
#
# If environment variable CTW_DISABLE_CHECKING is set to true, then script will not check loaded classes
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

function generate_base_aspect() {
  local previous_attempt=$((ATTEMPT-1))
  
  mkdir -p ${LOG_DIR}/aspects
  
  local loaded_classes="${LOG_DIR}/../../check_project/${PROJECT_NAME}/loaded-classes.txt"
  if [[ ! -f "${loaded_classes}" ]]; then
    if [[ ${CTW_DISABLE_CHECKING} != "true" ]]; then
      # Environment variable CTW_DISABLE_CHECKING is not set
      echo "Cannot apply this patch: missing loaded-classes.txt file"
      exit 1
    fi
    
    loaded_classes=${SCRIPT_DIR}/loaded-classes-tmp.txt
    touch ${loaded_classes}
  fi
  
  python3 ${SCRIPT_DIR}/../code-size-too-big/generate_base_aspect_from_log.py "${LOG_DIR}/attempt-${previous_attempt}.log" ${loaded_classes} "${LOG_DIR}/aspects/BaseAspect.aj"
  if [[ $? -ne 0 ]]; then
    exit 1
  fi
}

function build_aspects() {
  local orig_classpath=${CLASSPATH}
  local orig_path=${PATH}
  local script_project_dir="${SCRIPT_DIR}/../../../scripts/projects"
  
  export PATH=${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/bin:${script_project_dir}/tracemop/javamop/target/release/javamop/javamop/bin:${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${PATH}
  export CLASSPATH=${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${CLASSPATH}
  
  local tmp_props=${LOG_DIR}/tsm-rv-props
  rm -rf ${tmp_props}
  cp -r ${SCRIPT_DIR}/../../../mop/props ${tmp_props}
  
  # Generate .aj files and MultiSpec_1RuntimeMonitor.java
  cp ${LOG_DIR}/aspects/BaseAspect.aj ${tmp_props}/BaseAspect.aj
  
  for spec in ${tmp_props}/*.mop; do
    javamop -baseaspect ${tmp_props}/BaseAspect.aj -emop ${spec} -internalBehaviorObserving # Generate .aj
  done
  
  rm -rf ${tmp_props}/classes/mop; mkdir -p ${tmp_props}/classes/mop
  
  rv-monitor -merge -d ${tmp_props}/classes/mop/ ${tmp_props}/*.rvm -locationFromAjc # Generate MultiSpec_1RuntimeMonitor.java
  
  cp ${tmp_props}/classes/mop/MultiSpec_1RuntimeMonitor.java ${tmp_props}/MultiSpec_1RuntimeMonitor.java
  rm -rf ${tmp_props}/classes/ ${tmp_props}/*.mop ${tmp_props}/*.rvm  # Only keep .aj and MultiSpec_1RuntimeMonitor.java
  
  pushd ${LOG_DIR}/aspects
  ajc -Xlint:ignore -1.8 -encoding UTF-8 -showWeaveInfo -verbose -outjar myaspects.jar ${tmp_props}/*
  popd
  
  rm -rf ${tmp_props}
  
  export CLASSPATH=${orig_classpath}
  export PATH=${orig_path}
}

function instrument_source() {
  pushd ${PROJECT_DIR}
  
  # Clean and re-compile
  echo "Compiling"
  time timeout 3600s mvn -Dmaven.repo.local=${REPO_PATH} ${SKIP} -Djava.io.tmpdir=/tmp/tsm-rv clean test-compile
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  
  # Post-compile instrumentation
  echo "Instrumenting source"
  ajc -Xlint:ignore -1.8 -encoding UTF-8 -showWeaveInfo -inpath target/classes -d target/instrumented-classes -aspectpath "${LOG_DIR}/aspects/myaspects.jar" -classpath ${JAR_CP}:${SCRIPT_DIR}/../../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${CLASSPATH}
  if [[ $? -ne 0 || ! -d "target/instrumented-classes" ]]; then
    echo "Cannot instrument code"
    exit 1
  fi
  
  echo "Instrumenting test"
  ajc -Xlint:ignore -1.8 -encoding UTF-8 -showWeaveInfo -inpath target/test-classes -d target/instrumented-test-classes -aspectpath "${LOG_DIR}/aspects/myaspects.jar" -classpath ${JAR_CP}:${SCRIPT_DIR}/../../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:target/classes:${CLASSPATH}
  if [[ $? -ne 0 || ! -d "target/instrumented-test-classes" ]]; then
    echo "Cannot instrument test"
    exit 1
  fi
  
  rm -rf target/classes target/test-classes
  mv target/instrumented-classes target/classes
  mv target/instrumented-test-classes target/test-classes
  
  popd
}

generate_base_aspect
build_aspects
instrument_source


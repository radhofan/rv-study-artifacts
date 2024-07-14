#!/bin/bash
#
# Usage: run_hot.sh <project-name> <log-dir> <aspectj-dir> <path-to-top5.csv> [jar-files]
# Run HOT METHODS on CTW projects
# Preconditions:
#   - Already ran run_projects.sh
#   - Already collected tests with scripts/collect_tests.sh
#   - Already collected traces with scripts/collect_traces.py
#   - tracemop is in scripts/projects
#   - Project is in scripts/projects directory (should contain .all-traces and tests.txt)
#   - Project is in ../projects directory and ../projects-withhot directory
#   - Non CTW project is in ../nomop-projects directory
#
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
PROJECT=$1
LOG_DIR=$2
ASPECTJ_DIR=$3
TOP5_CSV=$4
JAR_FILE=$5

source ${SCRIPT_DIR}/../../experiments/constants.sh
source ${SCRIPT_DIR}/../../experiments/utils.sh

function verify_preconditons() {
  if [[ -z ${OVERRIDE_PRECONDITION} ]]; then
    if [[ -z "${PROJECT}" || ! -d "${SCRIPT_DIR}/../../scripts/projects/${PROJECT}" || ! -d "${SCRIPT_DIR}/../../scripts/projects/${PROJECT}/.all-traces" || ! -f "${SCRIPT_DIR}/../../scripts/projects/${PROJECT}/tests.txt" ]]; then
      echo "Project preconditions not satisfied"
      exit 1
    fi
  fi

  if [[ -z "${LOG_DIR}" ]]; then
    echo "Missing argument: log-dir"
    exit 1
  fi
  
  if [[ -z "${ASPECTJ_DIR}" ]]; then
    echo "Missing argument: aspectj-dir"
    exit 1
  fi
  
  if [[ ! -f "${TOP5_CSV}" ]]; then
    echo "Missing argument: path-to-top5.csv"
    exit 1
  fi
  
  mkdir -p ${LOG_DIR}
}

function build_aspects_jar() {
  local orig_classpath=${CLASSPATH}
  local orig_path=${PATH}
  local script_project_dir="${SCRIPT_DIR}/../../scripts/projects"
  
  export PATH=${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/bin:${script_project_dir}/tracemop/javamop/target/release/javamop/javamop/bin:${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${PATH}
  export CLASSPATH=${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${CLASSPATH}
  
  local tmp_props=/tmp/tsm-rv-props
  rm -rf /tmp/tsm-rv-props
  cp -r ${SCRIPT_DIR}/../../mop/props ${tmp_props}
  
  # Generate .aj files and MultiSpec_1RuntimeMonitor.java
  cp ${SCRIPT_DIR}/../../mop/BaseAspect_new.aj ${tmp_props}/BaseAspect.aj
  
  for spec in ${tmp_props}/*.mop; do
    javamop -baseaspect ${tmp_props}/BaseAspect.aj -emop ${spec} -internalBehaviorObserving # Generate .aj
  done
  
  rm -rf ${tmp_props}/classes/mop; mkdir -p ${tmp_props}/classes/mop
  rv-monitor -merge -d ${tmp_props}/classes/mop/ ${tmp_props}/*.rvm -locationFromAjc # Generate MultiSpec_1RuntimeMonitor.java
  
  cp ${tmp_props}/classes/mop/MultiSpec_1RuntimeMonitor.java ${tmp_props}/MultiSpec_1RuntimeMonitor.java
  rm -rf ${tmp_props}/classes/ ${tmp_props}/*.mop ${tmp_props}/*.rvm  # Only keep .aj and MultiSpec_1RuntimeMonitor.java
  
  pushd ${SCRIPT_DIR}/aspects
  ajc -Xlint:ignore -1.8 -encoding UTF-8 -showWeaveInfo -verbose -outjar myaspects-${PROJECT}.jar ${tmp_props}/*
  popd
  
  rm -rf ${tmp_props}
  
  export CLASSPATH=${orig_classpath}
  export PATH=${orig_path}
}

function run_test() {
  pushd ${SCRIPT_DIR}/../projects/${PROJECT}
  
  # Instrument source code
  local MY_ASPECTS_JAR="${SCRIPT_DIR}/aspects/myaspects-${PROJECT}.jar"
  local ASPECTJRT_JAR="${ASPECTJ_DIR}/lib/aspectjrt.jar"
  local RV_MONITOR_RT_JAR="${SCRIPT_DIR}/../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar"

  bash ${SCRIPT_DIR}/../instrumentation/setup_source_for_instrumentation.sh "${SCRIPT_DIR}/../repos/${PROJECT}" ${MY_ASPECTS_JAR} ${ASPECTJRT_JAR} ${RV_MONITOR_RT_JAR} "${LOG_DIR}/${PROJECT}.log" true
  if [[ $? -ne 0 ]]; then
    echo "Failed to setup repo" &>> ${LOG_DIR}/${PROJECT}.log
    exit 1
  fi
  
  cp -r "${SCRIPT_DIR}/../repos/${PROJECT}" "${SCRIPT_DIR}/../repos.tmp"
  local start=$(date +%s%3N)
  bash ${SCRIPT_DIR}/../instrumentation/instrument_source.sh ${PROJECT} "${SCRIPT_DIR}/../repos.tmp" ${ASPECTJRT_JAR} "${LOG_DIR}/source" "${SCRIPT_DIR}/.classpath.txt" ${MY_ASPECTS_JAR}
  local status=$?
  
  local end=$(date +%s%3N)
  local duration=$((end - start))
  echo "Instrument: ${duration}, Status: ${status}" &>> ${LOG_DIR}/${PROJECT}.log
  if [[ ${status} -ne 0 ]]; then
    exit 1
  fi

  rm -rf "${SCRIPT_DIR}/../repos.tmp"
  delete_violations
  
  # Run JavaMOP
  export MY_ASPECTS_JAR=${MY_ASPECTS_JAR}
  export ASPECTJRT_JAR=${ASPECTJRT_JAR}
  export RV_MONITOR_RT_JAR=${RV_MONITOR_RT_JAR}
  export JUNIT_MEASURE_TIME_LISTENER=1

  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv

  local start=$(date +%s%3N)
  (uptime && time mvn -Dmaven.repo.local="${SCRIPT_DIR}/../repos/${PROJECT}" ${SKIP} -Djava.io.tmpdir=/tmp/tsm-rv surefire:test) &>> ${LOG_DIR}/${PROJECT}.log
  local status=$?
  local end=$(date +%s%3N)
  local duration=$((end - start))
  
  uptime >> ${LOG_DIR}/${PROJECT}.log
  echo "Test Again: ${duration}, Status: ${status}" &>> ${LOG_DIR}/${PROJECT}.log
  if [[ ${status} -ne 0 ]]; then
    exit 1
  fi
  
  move_violations ${LOG_DIR} violation-counts-nohot
  
  chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv
  popd
  
  export JUNIT_MEASURE_TIME_LISTENER=0
}

function instrument_jar() {
  local cp_file="${SCRIPT_DIR}/.classpath.txt"
  rm -rf ${cp_file}
  
  pushd ${SCRIPT_DIR}/../projects/${PROJECT}
  timeout 3600s mvn -Dmaven.repo.local="${SCRIPT_DIR}/../repos/${PROJECT}" dependency:build-classpath -Dmdep.outputFile=/dev/stdout -q 2>&1 | cat > ${cp_file}
  if [[ $? -ne 0 ]]; then
    echo "$Cannot get classpath" &>> ${LOG_DIR}/${PROJECT}.log
    # Cannot get all the jars
    exit 999
  fi
  popd
  
  python3 ${SCRIPT_DIR}/../parse_classpath.py ${cp_file}

  if [[ -n "${JAR_FILE}" ]]; then
    # Instrument jar in JAR_FILE
    while read -r jar; do
      echo "Re-instrument ${jar}" &>> ${LOG_DIR}/${PROJECT}.log
      
      mv "${jar}" "${jar}.old"
      local uninstrumented_jar=$(echo "${jar}" | sed "s/\/repos\//\/repos-without-mop\//")
      cp ${uninstrumented_jar} ${jar}
      
      bash ${SCRIPT_DIR}/../instrumentation/instrument_jar.sh ${PROJECT} "${LOG_DIR}/_$(echo ${jar} | tr / -)" ${jar} ${cp_file} ${SCRIPT_DIR}/aspects/myaspects-${PROJECT}.jar
      if [[ ${status} -ne 0 ]]; then
        echo "Failed to instrument ${jar}" &>> ${LOG_DIR}/${PROJECT}.log
        exit 1
      fi
    done < ${JAR_FILE}
  fi
}

function run() {
  # Get the current BaseAspect for each jar
  cp ${SCRIPT_DIR}/../../mop/BaseAspect_new.aj ${LOG_DIR}

  for base_aspect in $(find ${LOG_DIR}/../ctw -name "BaseAspect.aj"); do
    head -n 1 ${base_aspect} | cut -d '/' -f 3- >> ${LOG_DIR}/pointcuts.txt
  done
 
  pushd ${SCRIPT_DIR}/../../experiments/hot-methods
  python3 gen_base_aspect.py ${TOP5_CSV} ${LOG_DIR}/BaseAspect_new.aj ${LOG_DIR}/pointcuts.txt
  popd
  
  mkdir -p ${SCRIPT_DIR}/aspects

  if [[ ! -f ${SCRIPT_DIR}/aspects/myaspects-${PROJECT}.jar ]]; then
    build_aspects_jar
  fi
  
  instrument_jar
  run_test

  rm -rf "${SCRIPT_DIR}/.classpath.txt"
}

verify_preconditons
run

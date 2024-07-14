#!/bin/bash
#
# Run LTW RV, CTW RV, collect traces, run profiler, then generate charts
# Usage: ./run_all_experiments.sh <repo> <sha> <output-dir> <aspectj-dir> <async-profiler-dir> [steps]
#
REPO=$1
SHA=$2
OUTPUT_DIR=$3
ASPECTJ_DIR=$4
PROFILER_DIR=$5
STEPS=$6
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
PROJECT_NAME=$(echo ${REPO} | tr / -)
LOG_PREFIX="[TSM-CTW]"

source ${SCRIPT_DIR}/experiments/constants.sh

if [[ -z ${REPO} || -z ${SHA} || -z ${OUTPUT_DIR} || ! -d ${ASPECTJ_DIR} || ! -f ${PROFILER_DIR} ]]; then
  echo "Usage bash run_all_experiments.sh <repo> <sha> <output-dir> <aspectj-dir> <async-profiler-dir> [steps]"
  exit 1
fi

if [[ -n ${STEPS} ]]; then
  START=$(echo ${STEPS} | cut -d '-' -f 1)
  END=$(echo ${STEPS} | cut -d '-' -f 2)
else
  START=0
  END=100
fi

function setup() {
  echo "${LOG_PREFIX} start setup"
  if [[ ! -f "${MAVEN_HOME}/lib/ext/measure-extension-1.0.jar" ]]; then
    cp ${SCRIPT_DIR}/extensions/measure-extension-1.0.jar ${MAVEN_HOME}/lib/ext/measure-extension-1.0.jar
  fi
  
  if [[ ! -f "${MAVEN_HOME}/lib/ext/ctw-extension-1.0.jar" ]]; then
    cp ${SCRIPT_DIR}/extensions/ctw-extension-1.0.jar ${MAVEN_HOME}/lib/ext/ctw-extension-1.0.jar
  fi
  
  if [[ ! -f "${MAVEN_HOME}/lib/ext/profiler-extension-1.0.jar" ]]; then
    cp ${SCRIPT_DIR}/extensions/profiler-extension-1.0.jar ${MAVEN_HOME}/lib/ext/profiler-extension-1.0.jar
  fi
  echo "${LOG_PREFIX} end setup"
}

function check_ltw_overhead() {
  echo "${LOG_PREFIX} start check_ltw_overhead"
  mkdir -p ${OUTPUT_DIR}
  bash ${SCRIPT_DIR}/experiments/check_projects/check_project.sh ${REPO} ${SHA} ${OUTPUT_DIR}

  local result=${OUTPUT_DIR}/check_project/${PROJECT_NAME}/result.csv

  if [[ ! -f ${result} ]]; then
    echo "${LOG_PREFIX} missing check_project.sh's result.csv"
    exit 1
  fi
  
  if [[ $(cat ${result} | cut -d ',' -f 2) -ne 1 ]]; then
    echo "${LOG_PREFIX} cannot clone project ${REPO}"
    exit 2
  fi
  
  if [[ $(cat ${result} | cut -d ',' -f 3) -ne 1 ]]; then
    echo "${LOG_PREFIX} cannot test project ${REPO}"
    exit 3
  fi
  
  if [[ $(cat ${result} | cut -d ',' -f 4) -ne 1 ]]; then
    echo "${LOG_PREFIX} cannot test project ${REPO} with LTW RV"
    exit 4
  fi
  
  if [[ ${SINGLE_PASS} != true ]]; then
    # Don't care about the result
    echo "${LOG_PREFIX} profiling project"
    bash ${SCRIPT_DIR}/experiments/profile_with_mop.sh ${REPO} ${SHA} ${OUTPUT_DIR} ${PROFILER_DIR}
  fi
  
  if [[ $(cat ${result} | cut -d ',' -f 6) -lt 15000 ]]; then
    echo "${LOG_PREFIX} LTW MOP time too short ${REPO}"
    exit 5
  fi
  
  echo "${LOG_PREFIX} end check_ltw_overhead"
}

function check_ctw_overhead() {
  echo "${LOG_PREFIX} start check_ctw_overhead"
  mkdir -p ${OUTPUT_DIR}/ctw
  mkdir ${SCRIPT_DIR}/compile-time-weaving/projects
  mkdir ${SCRIPT_DIR}/compile-time-weaving/repos
  
  # Setup CTW project and repos
  cp -r ${SCRIPT_DIR}/projects/${PROJECT_NAME} ${SCRIPT_DIR}/compile-time-weaving/projects/${PROJECT_NAME}
  cp -r ${SCRIPT_DIR}/repos/${PROJECT_NAME} ${SCRIPT_DIR}/compile-time-weaving/repos/${PROJECT_NAME}

  # Run CTW
  echo "${REPO},${SHA}" > ${SCRIPT_DIR}/compile-time-weaving/projects.csv
  bash ${SCRIPT_DIR}/compile-time-weaving/run.sh ${SCRIPT_DIR}/compile-time-weaving/projects.csv ${OUTPUT_DIR}/ctw ${SCRIPT_DIR}/mop/props ${ASPECTJ_DIR}
  
  local result=${OUTPUT_DIR}/ctw/${PROJECT_NAME}.log
  if [[ ! -f ${result} || -z $(tail ${result} -n 1 | grep "Finished monitor_project") ]]; then
    echo "${LOG_PREFIX} cannot test project ${REPO} with CTW RV"
    exit 6
  fi

  if [[ $(tail ${result} -n 1 | cut -d ' ' -f 5) -lt 15000 ]]; then
    echo "${LOG_PREFIX} CTW MOP time too short ${REPO}"
    exit 8
  fi
  echo "${LOG_PREFIX} end check_ctw_overhead"
}

function run_profiler_for_mop_and_no_mop() {
  echo "${LOG_PREFIX} start run_profiler_for_mop_and_no_mop"
  mkdir -p ${OUTPUT_DIR}/profiler
  mkdir -p ${SCRIPT_DIR}/compile-time-weaving/projects-without-mop
  mkdir -p ${SCRIPT_DIR}/compile-time-weaving/repos-without-mop
  mkdir -p ${SCRIPT_DIR}/compile-time-weaving/projects-with-mop
  mkdir -p ${SCRIPT_DIR}/compile-time-weaving/repos-with-mop
  
  # Setup projects and repos
  # Copy instrumented projects and repos to with-mop
  mv ${SCRIPT_DIR}/compile-time-weaving/projects/${PROJECT_NAME} ${SCRIPT_DIR}/compile-time-weaving/projects-with-mop/${PROJECT_NAME}
  mv ${SCRIPT_DIR}/compile-time-weaving/repos/${PROJECT_NAME} ${SCRIPT_DIR}/compile-time-weaving/repos-with-mop/${PROJECT_NAME}
  
  # Copy original uninstrumented projects and repos to without-mop
  cp -r ${SCRIPT_DIR}/projects/${PROJECT_NAME} ${SCRIPT_DIR}/compile-time-weaving/projects-without-mop/${PROJECT_NAME}
  cp -r ${SCRIPT_DIR}/repos/${PROJECT_NAME} ${SCRIPT_DIR}/compile-time-weaving/repos-without-mop/${PROJECT_NAME}
  
  echo "${PROJECT_NAME}" > ${SCRIPT_DIR}/compile-time-weaving/projects.txt
  bash ${SCRIPT_DIR}/compile-time-weaving/experiments/profile_projects.sh ${OUTPUT_DIR}/profiler ${SCRIPT_DIR}/compile-time-weaving/projects.txt ${PROFILER_DIR} ${ASPECTJ_DIR} 4
  rm ${SCRIPT_DIR}/compile-time-weaving/projects.txt
  
  if [[ ! -f ${OUTPUT_DIR}/profiler/${PROJECT_NAME}/profile_nomop.jfr || ! -f ${OUTPUT_DIR}/profiler/${PROJECT_NAME}/profile_mop.jfr ]]; then
    echo "${LOG_PREFIX} cannot run profiler (nomop and mop) on project ${REPO}"
    exit 9
  fi
  echo "${LOG_PREFIX} end run_profiler_for_mop_and_no_mop"
}

function get_hot_methods_via_profiler() {
  echo "${LOG_PREFIX} start get_hot_methods_via_profiler"
  pushd ${SCRIPT_DIR}/profiling/JFRReader
  mvn package
  popd

  pushd ${SCRIPT_DIR}/projects/${PROJECT_NAME}
  grep --include "*.java" -rhE "package [a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)*;" . | grep "^package" | cut -d ' ' -f 2 | sed 's/;.*//g' | sort -u > ${SCRIPT_DIR}/packages.txt
  popd
  
  java -jar ${SCRIPT_DIR}/profiling/JFRReader/target/JFRReader-1.0-SNAPSHOT-jar-with-dependencies.jar ${OUTPUT_DIR}/profiler/${PROJECT_NAME}/profile_mop.jfr ${SCRIPT_DIR}/packages.txt hot
  if [[ $? -ne 0 || ! -f "${SCRIPT_DIR}/hot-methods.txt" ]]; then
    echo "${LOG_PREFIX} cannot run find hot methods (time) ${REPO}"
    exit 10
  fi
  
  mv ${SCRIPT_DIR}/hot-methods.txt ${OUTPUT_DIR}/hot-methods-time.txt
  mv ${SCRIPT_DIR}/packages.txt ${OUTPUT_DIR}/profiler/${PROJECT_NAME}/packages.txt
  echo "${LOG_PREFIX} end get_hot_methods_via_profiler"
}

function remove_hot_methods_time() {
  echo "${LOG_PREFIX} start remove_hot_methods_time"
  mkdir -p ${OUTPUT_DIR}/removed-hot-methods-time
  mkdir -p ${SCRIPT_DIR}/compile-time-weaving/projects
  mkdir -p ${SCRIPT_DIR}/compile-time-weaving/repos
  cp -r ${SCRIPT_DIR}/projects/${PROJECT_NAME} ${SCRIPT_DIR}/compile-time-weaving/projects/${PROJECT_NAME}
  cp -r ${SCRIPT_DIR}/repos/${PROJECT_NAME} ${SCRIPT_DIR}/compile-time-weaving/repos/${PROJECT_NAME}

  export OVERRIDE_PRECONDITION=1
  tail -n +2 ${OUTPUT_DIR}/hot-methods-time.txt | head -n 5 | grep "THIRD_PARTY_LIB" > ${OUTPUT_DIR}/classes.txt
  tail -n +2 ${OUTPUT_DIR}/hot-methods-time.txt | head -n 5 | cut -d ',' -f 1 > ${OUTPUT_DIR}/classes.2.txt

  if [[ -s ${OUTPUT_DIR}/classes.txt ]]; then
    cat ${OUTPUT_DIR}/classes.txt | cut -d ',' -f 1 > ${OUTPUT_DIR}/classes.3.txt
    bash ${SCRIPT_DIR}/compile-time-weaving/experiments/get_affected_jars.sh ${OUTPUT_DIR}/classes.3.txt ${SCRIPT_DIR}/compile-time-weaving/repos/${PROJECT_NAME} > ${OUTPUT_DIR}/hot-lib-time.txt

    if [[ ! -s ${OUTPUT_DIR}/hot-lib-time.txt ]]; then
      echo "${LOG_PREFIX} cannot find affected jars (time) ${REPO}" 
      exit 11
    fi

    bash ${SCRIPT_DIR}/compile-time-weaving/experiments/run_hot.sh ${PROJECT_NAME} ${OUTPUT_DIR}/removed-hot-methods-time ${ASPECTJ_DIR} ${OUTPUT_DIR}/classes.2.txt ${OUTPUT_DIR}/hot-lib-time.txt
    mv ${OUTPUT_DIR}/hot-lib-time.txt ${OUTPUT_DIR}/profiler/${PROJECT_NAME}
  else
    bash ${SCRIPT_DIR}/compile-time-weaving/experiments/run_hot.sh ${PROJECT_NAME} ${OUTPUT_DIR}/removed-hot-methods-time ${ASPECTJ_DIR} ${OUTPUT_DIR}/classes.2.txt
  fi
  
  export OVERRIDE_PRECONDITION=0
  
  if [[ -z $(tail -n 1 ${OUTPUT_DIR}/removed-hot-methods-time/${PROJECT_NAME}.log | grep "Test Again: .*, Status: 0") ]]; then
    echo "${LOG_PREFIX} cannot remove hot methods (time) ${REPO}"
    exit 12
  fi
  
  mkdir -p ${SCRIPT_DIR}/compile-time-weaving/projects-without-hot-time
  mkdir -p ${SCRIPT_DIR}/compile-time-weaving/repos-without-hot-time
  mv ${SCRIPT_DIR}/compile-time-weaving/projects/${PROJECT_NAME} ${SCRIPT_DIR}/compile-time-weaving/projects-without-hot-time/${PROJECT_NAME}
  mv ${SCRIPT_DIR}/compile-time-weaving/repos/${PROJECT_NAME} ${SCRIPT_DIR}/compile-time-weaving/repos-without-hot-time/${PROJECT_NAME}
  rm -rf ${OUTPUT_DIR}/classes.txt ${OUTPUT_DIR}/classes.2.txt ${OUTPUT_DIR}/classes.3.txt
  
  mv ${OUTPUT_DIR}/hot-methods-time.txt ${OUTPUT_DIR}/profiler/${PROJECT_NAME}
  echo "${LOG_PREFIX} end remove_hot_methods_time"
}

function run_profiler_for_no_hot_time() {
  echo "${LOG_PREFIX} start run_profiler_for_no_hot_time"
  echo "${PROJECT_NAME}" > ${SCRIPT_DIR}/compile-time-weaving/projects.txt
  bash ${SCRIPT_DIR}/compile-time-weaving/experiments/profile_projects.sh ${OUTPUT_DIR}/profiler ${SCRIPT_DIR}/compile-time-weaving/projects.txt ${PROFILER_DIR} ${ASPECTJ_DIR} 3
  rm ${SCRIPT_DIR}/compile-time-weaving/projects.txt
  
  if [[ ! -f ${OUTPUT_DIR}/profiler/${PROJECT_NAME}/profile_nohot_time.jfr ]]; then
    echo "${LOG_PREFIX} cannot run profiler (nohot-time) on project ${REPO}"
    exit 13
  fi
  echo "${LOG_PREFIX} end run_profiler_for_no_hot_time"
}

function convert_profiler_result() {
  echo "${LOG_PREFIX} start convert_profiler_result"
  
  mkdir -p ${OUTPUT_DIR}/charts
  
  echo "${PROJECT_NAME}" > ${SCRIPT_DIR}/compile-time-weaving/projects.txt
  bash ${SCRIPT_DIR}/profiling/jfr_to_csv.sh ${OUTPUT_DIR}/profiler ${SCRIPT_DIR}/compile-time-weaving/projects.txt ${SCRIPT_DIR}/profiling/JFRReader/target/JFRReader-1.0-SNAPSHOT-jar-with-dependencies.jar parent
  rm ${SCRIPT_DIR}/compile-time-weaving/projects.txt
  
  if [[ ! -f ${OUTPUT_DIR}/profiler/${PROJECT_NAME}/all-output.csv ]]; then
    echo "${LOG_PREFIX} cannot convert JFR to CSV for project ${REPO}"
    exit 14
  fi

  python3 ${SCRIPT_DIR}/profiling/plot_csv.py ${OUTPUT_DIR}/profiler/${PROJECT_NAME}/all-output.csv ${PROJECT_NAME} ${OUTPUT_DIR}/charts
  if [[ ! -f ${OUTPUT_DIR}/charts/${PROJECT_NAME}.png ]]; then
    echo "${LOG_PREFIX} cannot generate profiling chart for project ${REPO}"
    exit 15
  fi
  
  echo "${LOG_PREFIX} end convert_profiler_result"
}

function run_pipeline() {
  if [[ ${START} -le 1 && ${END} -ge 1 ]]; then
    # Step 1
    setup
  fi
  
  if [[ ${START} -le 2 && ${END} -ge 2 ]]; then
    # Step 2
    check_ltw_overhead
  fi
  
  if [[ ${START} -le 3 && ${END} -ge 3 ]]; then
    # Step 3
    check_ctw_overhead
  fi
  
  if [[ ${START} -le 4 && ${END} -ge 4 ]]; then
    # Step 4
    run_profiler_for_mop_and_no_mop
  fi
  
  if [[ ${START} -le 5 && ${END} -ge 5 ]]; then
    # Step 5
    get_hot_methods_via_profiler
  fi
  
  if [[ ${START} -le 6 && ${END} -ge 6 ]]; then
    # Step 6
    remove_hot_methods_time
  fi
  
  if [[ ${START} -le 7 && ${END} -ge 7 ]]; then
    # Step 7
    run_profiler_for_no_hot_time
  fi
  
  if [[ ${START} -le 8 && ${END} -ge 8 ]]; then
    convert_profiler_result
  fi
}

export RVMLOGGINGLEVEL=UNIQUE

uptime
time run_pipeline
uptime

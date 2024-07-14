#!/bin/bash
#
# Build agents that exclude hot methods and run RV and measure time
# Usage: run_without_hot_methods.sh <project-dir> <new-project-dir> <tmp-directory> <extension-directory> <mop-directory> <projects-list> <hot-methods-dir> <output-dir>
# Before running this script, make sure mop directory contains the `make-agent.sh` file
#
PROJECT_DIR=$1
NEW_PROJECT_DIR=$2
TMP_DIR=$3
EXTENSION_DIR=$4
MOP_DIR=$5
PROJECTS_LIST=$6
HOT_METHOD_DIR=$7
OUT_DIR=$8
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

function check_inputs() {
  if [[ ! -d "${PROJECT_DIR}" || -z "${NEW_PROJECT_DIR}" || -z "${TMP_DIR}" || ! -f "${PROJECTS_LIST}" || ! -d "${HOT_METHOD_DIR}" || -z "${OUT_DIR}" ]]; then
    echo "Usage: ./run_without_hot_methods.sh <project-dir> <new-project-dir> <tmp-directory> <extension-directory> <mop-directory> <projects-list> <hot-methods-dir> <hot-methods-dir> <output-dir>"
    exit 1
  fi
  
  if [[ ! -f ${MOP_DIR}/make-agent.sh ]]; then
    echo "make-agent.sh not in mop directory"
    exit 2
  fi
  
  mkdir -p ${NEW_PROJECT_DIR}
  mkdir -p ${OUT_DIR}
  mkdir -p ${MOP_DIR}/nohot-agents
}

# Convert relative path to absolute path
function convert_to_absolute_paths() {
  if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
    PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
  fi
  
  if [[ ! ${NEW_PROJECT_DIR} =~ ^/.* ]]; then
    NEW_PROJECT_DIR=${SCRIPT_DIR}/${NEW_PROJECT_DIR}
  fi
  
  if [[ ! ${EXTENSION_DIR} =~ ^/.* ]]; then
    EXTENSION_DIR=${SCRIPT_DIR}/${EXTENSION_DIR}
  fi
  
  if [[ ! ${MOP_DIR} =~ ^/.* ]]; then
    MOP_DIR=${SCRIPT_DIR}/${MOP_DIR}
  fi
  
  if [[ ! ${OUT_DIR} =~ ^/.* ]]; then
    OUT_DIR=${SCRIPT_DIR}/${OUT_DIR}
  fi
}


function run_track() {
  local project=$1
  mvn install:install-file -Dfile=${MOP_DIR}/nohot-agents/${project}-track-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar"
  
  pushd ${NEW_PROJECT_DIR}/${project}
  mkdir -p ${TMP_DIR}
  rm -rf ${NEW_PROJECT_DIR}/${project}/.traces
  mkdir -p ${NEW_PROJECT_DIR}/${project}/.traces
  
  export TRACEDB_PATH=${NEW_PROJECT_DIR}/${project}/.traces
  mvn -Djava.io.tmpdir=${TMP_DIR} -Dmaven.ext.class.path=${EXTENSION_DIR}/javamop-extension-1.0.jar surefire:test &> ${OUT_DIR}/${project}/track.log
  
  rm -rf ${TMP_DIR}
  popd
}


function run_notrack() {
  local project=$1
  mvn install:install-file -Dfile=${MOP_DIR}/nohot-agents/${project}-notrack-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar"
  
  pushd ${NEW_PROJECT_DIR}/${project}
  mkdir -p ${TMP_DIR}
  export JUNIT_MEASURE_TIME_LISTENER=1
  (time mvn -Djava.io.tmpdir=${TMP_DIR} -Dmaven.ext.class.path=${EXTENSION_DIR}/javamop-extension-1.0.jar surefire:test) &> ${OUT_DIR}/${project}/notrack.log
  export JUNIT_MEASURE_TIME_LISTENER=0
  
  rm -rf ${TMP_DIR}
  popd
}

function run() {
  local project=$1
  
  echo "Running project ${project}"
  cp -r "${PROJECT_DIR}/${project}" "${NEW_PROJECT_DIR}/${project}"
  mkdir -p ${OUT_DIR}/${project}
  
  # Build agents
  python3 ${SCRIPT_DIR}/gen_base_aspect.py ${HOT_METHOD_DIR}/${project}/top5.csv ${OUT_DIR}/${project}/BaseAspect_new.aj &> ${OUT_DIR}/${project}/gen_base_aspect.log
  if [[ $? -ne 0 ]]; then
    echo "Cannot generate base aspect file"
    return 1
  fi
  
  cp ${OUT_DIR}/${project}/BaseAspect_new.aj ${MOP_DIR}/BaseAspect_new.aj
  bash ${MOP_DIR}/make-agent.sh  ${MOP_DIR}/props ${MOP_DIR}/nohot-agents quiet track "${NEW_PROJECT_DIR}/${project}/" ${project}-track-agent ${SCRIPT_DIR}/../../scripts/.trace-db.config stats &> ${OUT_DIR}/${project}/make-agent-track.log
  if [[ $? -ne 0 ]]; then
    echo "Cannot build agent"
    return 1
  fi
  
  bash ${MOP_DIR}/make-agent.sh  ${MOP_DIR}/props ${MOP_DIR}/nohot-agents quiet no-track "${NEW_PROJECT_DIR}/${project}/" ${project}-notrack-agent ${SCRIPT_DIR}/../../scripts/.trace-db.config &> ${OUT_DIR}/${project}/make-agent-notrack.log
  if [[ $? -ne 0 ]]; then
    echo "Cannot build agent"
    return 1
  fi
  
  run_track ${project}
  run_notrack ${project}
}


function run_all() {
  while read -r project; do
    if [[ -d "${PROJECT_DIR}/${project}" ]]; then
      run ${project}
    fi
  done < ${PROJECTS_LIST}
}

export RVMLOGGINGLEVEL=UNIQUE
check_inputs
convert_to_absolute_paths
run_all

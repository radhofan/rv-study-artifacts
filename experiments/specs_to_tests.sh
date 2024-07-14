#!/bin/bash
#
# Map specs to tests
# Usage: specs_to_tests.sh <project-directory> <project-name> <extension-directory> <mop-directory> <specs-file> [log-directory]
#
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

# Convert relative path to absolute path
function convert_to_absolute_paths() {
  if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
    PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
  fi
  
  if [[ ! ${EXTENSION_DIR} =~ ^/.* ]]; then
    EXTENSION_DIR=${SCRIPT_DIR}/${EXTENSION_DIR}
  fi
  
  if [[ ! ${MOP_DIR} =~ ^/.* ]]; then
    MOP_DIR=${SCRIPT_DIR}/${MOP_DIR}
  fi
  
  if [[ ! ${SPECS_FILE} =~ ^/.* ]]; then
    SPECS_FILE=${SCRIPT_DIR}/${SPECS_FILE}
  fi
}

check_inputs() {
  if [[ -z "${SPECS_FILE}" ]]; then
    echo "Usage: specs_to_tests.sh <project-directory> <project-name> <extension-directory> <mop-directory> <specs-file> [log-directory]"
    exit 1
  fi
  
  if [[ -n "${LOG_DIR}" ]]; then
    if [[ ! ${PROJECT_DIR} =~ ^/.*  ]]; then
      LOG_DIR=${SCRIPT_DIR}/${LOG_DIR}
    fi
  else
    LOG_DIR=/tmp/$(uuidgen)
  fi
  
  mkdir -p ${LOG_DIR}/violations
}

function collect_specs_from_test() {
  local testcase=$1
  rm -f violation-counts
  mvn -Dmaven.ext.class.path="${EXTENSION_DIR}/javamop-extension-1.0.jar" surefire:test -Dtest=${testcase} &> ${LOG_DIR}/${testcase}.log
  
  cp violation-counts ${LOG_DIR}/violations/${testcase}.txt &> /dev/null
  
  while read -r spec; do
    local events_count=$(sed -n "/==start ${spec} ==/,/==end ${spec} ==/p" ${LOG_DIR}/${testcase}.log | grep "#event -" | cut -d: -f2 | paste -sd+ | bc -l)
    if [[ ${events_count} != 0 ]]; then
      echo "Test ${testcase} has ${events_count} events related to ${spec}"
    fi
  done < ${SPECS_FILE}
}

function run_tests() {
  pushd "${PROJECT_DIR}/${PROJECT_NAME}"

  local count=0
  while read -r testcase; do
    ((count += 1))
    echo "Running test #${count}: ${testcase}"
    collect_specs_from_test ${testcase}
  done < tests.txt
  
  echo "Finished checking ${count} tests:"
  echo ${LOG_DIR}
  popd
}

PROJECT_DIR=$1
PROJECT_NAME=$(echo $2 | tr / -)
EXTENSION_DIR=$3
MOP_DIR=$4
SPECS_FILE=$5
LOG_DIR=$6

export RVMLOGGINGLEVEL=UNIQUE

check_inputs
convert_to_absolute_paths
run_tests

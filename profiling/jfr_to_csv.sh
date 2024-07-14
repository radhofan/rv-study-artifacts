#!/bin/bash
#
# After running profile_project.sh, convert its jfr files output to a csv file
# Usage: jfr_to_csv.sh <profiler-output-dir> <projects-list> <jfr-reader-jar> [classifier: naive/parent]
#
OUTPUT_DIR=$1
PROJECTS_LIST=$2
READER_JAR_PATH=$3
CLASSIFIER=$4
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

check_inputs() {
  if [[ ! -d "${OUTPUT_DIR}" || ! -f "${PROJECTS_LIST}" || ! -f "${READER_JAR_PATH}" ]]; then
    echo "Usage: ./jfr_to_csv.sh <profiler-output-dir> <projects-list> <jfr-reader-jar> [classifier: naive/parent]"
    exit 1
  fi
  
  if [[ -n "${CLASSIFIER}" ]]; then
    if [[ ${CLASSIFIER} != "naive" && ${CLASSIFIER} != "parent" ]]; then
      echo "Usage: ./jfr_to_csv.sh <profiler-output-dir> <projects-list> <jfr-reader-jar> [classifier: naive/parent]"
      exit 1
    fi
  else
    CLASSIFIER="naive"
  fi

  mkdir -p ${OUTPUT_DIR}
}

function convert_to_absolute_paths() {
  if [[ ! ${OUTPUT_DIR} =~ ^/.* ]]; then
    OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
  fi

  if [[ ! ${PROJECTS_LIST} =~ ^/.* ]]; then
    PROJECTS_LIST=${SCRIPT_DIR}/${PROJECTS_LIST}
  fi

  if [[ ! ${READER_JAR_PATH} =~ ^/.* ]]; then
    READER_JAR_PATH=${SCRIPT_DIR}/${READER_JAR_PATH}
  fi
}

function convert_project() {
  local project=$1

  pushd ${OUTPUT_DIR}/${project}
  if [[ ! -f profile_mop.jfr ]]; then
    echo "profile_mop.jfr is missing"
    return
  fi

  if [[ ! -f profile_nomop.jfr ]]; then
    echo "profile_nomop.jfr is missing"
    return
  fi

  if [[ ! -f profile_nohot_time.jfr ]]; then
    echo "profile_nohot_time.jfr is missing"
    return
  fi

  # Get all project's packages
  if [[ ! -f packages.txt ]]; then
    grep --include "*.java" -rhE "package [a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)*;" . | grep "^package" | cut -d ' ' -f 2 | sed 's/;.*//g' | sort -u > packages.txt
  fi
  
  if [[ -f all-output.csv ]]; then
    local time=$(date +%s)
    mv all-output.csv .all-output.${time}.csv
  fi

  # Convert profile_mop.jfr to all-output.csv
  java -jar ${READER_JAR_PATH} profile_mop.jfr packages.txt ${CLASSIFIER}
  if [[ $? -eq 0 && -f output.csv ]]; then
    sed -n 2p output.csv >> all-output.csv
    rm output.csv
    echo "converted profile_mop.jfr"
  else
    echo "cannot convert profile_mop.jfr"
  fi

  # Convert profile_nomop.jfr to all-output.csv
  java -jar ${READER_JAR_PATH} profile_nomop.jfr packages.txt ${CLASSIFIER}
  if [[ $? -eq 0 && -f output.csv ]]; then
    sed -n 2p output.csv >> all-output.csv
    rm output.csv
    echo "converted profile_nomop.jfr"
  else
    echo "cannot convert profile_nomop.jfr"
  fi

  # Convert profile_nohot.jfr to all-output.csv
  java -jar ${READER_JAR_PATH} profile_nohot_time.jfr packages.txt ${CLASSIFIER}
  if [[ $? -eq 0 && -f output.csv ]]; then
    sed -n 2p output.csv >> all-output.csv
    rm output.csv
    echo "converted profile_nohot_time.jfr"
  else
    echo "cannot convert profile_nohot_time.jfr"
  fi
  popd
}

function convert_all() {
  export PROFILER_PATH=${PROFILER_PATH}
  
  echo "Using ${CLASSIFIER} classifier to convert jfr to csv..."

  while read -r project; do
    echo "Converting ${project}"
    
    convert_project ${project}
  done < ${PROJECTS_LIST}
}


check_inputs
convert_to_absolute_paths
convert_all

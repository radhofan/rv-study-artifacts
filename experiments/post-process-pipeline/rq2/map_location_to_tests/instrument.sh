#!/bin/bash
# Example: ./instrument.sh /home/tsm/word /home/tsm/lines.txt /home/tsm/rv-adequacy/coverage_reporter/
# 
PROJECT_DIR=$1
LOCATION_MAP=$2
COVERAGE_PROJECT=$3
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ ! -d "${PROJECT_DIR}" ]]; then
  echo "Cannot find output directory"
  exit 1
fi

if [[ ! -f "${LOCATION_MAP}" ]]; then
  echo "Cannot find location map"
  exit 1
fi

if [[ ! -d "${COVERAGE_PROJECT}" ]]; then
  echo "Cannot find tool"
  exit 1
fi

while read -r line; do
  class_name=$(echo "${line}" | cut -d ',' -f 1)
  class_name2=$(echo "${line}" | cut -d ',' -f 1)
  lines=$(echo "${line}" | cut -d ',' -f 3-)
  
  pushd ${PROJECT_DIR} &> /dev/null
  
  class_file=$(find $(pwd) -name "${class_name}")
  if [[ -z ${class_file} ]]; then
    class_file=$(find $(pwd) -name "${class_name2}")
  fi
  
  if [[ -z ${class_file} ]]; then
    continue
  fi

  while read -r class; do
    if [[ -n ${class} ]]; then
      pushd ${COVERAGE_PROJECT} &> /dev/null
      echo "${class} - ${lines}"
      mvn exec:java -Dexec.mainClass=edu.illinois.cs.instrumentation.CoverageBlameAdapter -Dexec.args="${class} ${lines}"
      popd &> /dev/null
    fi
  done <<< $(find $(pwd) -name "${class_name}")

  popd  &> /dev/null
done < ${LOCATION_MAP}

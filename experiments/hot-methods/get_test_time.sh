#!/bin/bash
#
# Get hot methods remove test time
# Usage: get_test_time.sh <project-log-dir>
#
PROJECT_DIR=$1

if [[ -z "${PROJECT_DIR}" ]]; then
  echo "Usage: ./get_test_time <project-log-dir>"
  exit 1
fi

for project in $(ls ${PROJECT_DIR}); do
  if [[ ! -d "${PROJECT_DIR}/${project}" ]]; then
    continue
  fi

  time=0
  log="${PROJECT_DIR}/${project}/notrack.log"
  if [[ -f ${log} ]]; then
    time_ms=$(grep "JUnit Total Time" ${log} | cut -d ' ' -f 5)
    if [[ -n ${time_ms} ]]; then
      # JUnit time measure test listener doesn't work for project like parship-roperty
      time=$(echo "scale=3; ${time_ms}/1000" | bc -l)
    fi
  fi
  
  echo "${project},${time}"
done

#!/bin/bash
#
# Remove monitoring code from .aj files
# Usage: remove_monitoring_code.sh <props-dir>
#
PROPS_DIR=$1
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

check_inputs() {
  if [[ ! -d "${PROPS_DIR}" ]]; then
    echo "Usage: ./remove_monitoring_code.sh <props-dir>"
    exit 1
  fi
}

function update_aj_files() {
  for file in $(grep --include="*.aj" -r "MultiSpec_1RuntimeMonitor." ${PROPS_DIR} -l); do
    echo "Replacing ${file}"
    sed -i 's\MultiSpec_1RuntimeMonitor.\//MultiSpec_1RuntimeMonitor.\g' ${file}
  done
}

check_inputs
update_aj_files

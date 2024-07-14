#!/bin/bash

SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
CLASSES=$1
REPO_JARS=$2

function get_methods() {
  pushd ${SCRIPT_DIR} &> /dev/null
  python3 ${SCRIPT_DIR}/get_affect_classes.py ${CLASSES} > ${CLASSES}.tmp
  
  while read -r class; do
    regex="Binary file (.*) matches"
    while read -r jar; do
      if [[ $jar =~ $regex ]]; then
        echo ${BASH_REMATCH[1]}
      fi
    done <<< "$(grep -r "${class}" ${REPO_JARS})"
  done < ${CLASSES}.tmp
  rm ${CLASSES}.tmp
  popd &> /dev/null
}

get_methods | sort | uniq

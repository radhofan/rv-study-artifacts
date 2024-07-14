#!/bin/bash
PROJECT_DIR=$1
PACKAGE=$2
FILENAME=$3
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ ! -f ${SCRIPT_DIR}/find_loop.jar ]]; then
  pushd ${SCRIPT_DIR}/find_loop &> /dev/null
  mvn package &> /dev/null
  cp target/find_loop-1.0-SNAPSHOT-jar-with-dependencies.jar ${SCRIPT_DIR}/find_loop.jar
  popd &> /dev/null
fi

pushd ${PROJECT_DIR} &> /dev/null
find -name ${FILENAME} | xargs grep ${PACKAGE} -l | xargs -n 1 -I {} java -jar ${SCRIPT_DIR}/find_loop.jar "{}"

#!/bin/bash
# Example: ./run_test.sh /home/tsm/word /home/tsm/rv-adequacy/pom_extensions/target/pom-extension-1.0-SNAPSHOT.jar /home/tsm/rv-adequacy/setup.py
# 
PROJECT_DIR=$1
EXTENSION_PATH=$2
SETUP_SCRIPT=$3
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ ! -d "${PROJECT_DIR}" ]]; then
  echo "Cannot find output directory"
  exit 1
fi

if [[ ! -f "${EXTENSION_PATH}" ]]; then
  echo "Cannot find extension jar"
  exit 1
fi

pushd ${PROJECT_DIR} &> /dev/null
if [[ -n $(find -name "pom.xml" | xargs grep "org.junit.jupiter") ]]; then
  echo "JUnit 5"
  
  python3 ${SETUP_SCRIPT} ${PROJECT_DIR} .
  mvn surefire:test -DtestSource=developer -Dmode=blame -Djunit.version=5 -Dmaven.ext.class.path=${EXTENSION_PATH}
else
  echo "JUnit 4"
  
  mvn surefire:test -DtestSource=developer -Dmode=blame -Djunit.version=4 -Dmaven.ext.class.path=${EXTENSION_PATH}
fi

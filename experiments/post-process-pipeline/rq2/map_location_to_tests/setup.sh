#!/bin/bash
# Usage: bash setup.sh <project-dir> <repo-name> <sha>
# 
PROJECT_DIR=$1
REPO=$2
PROJECT_NAME=$(echo ${REPO} | tr / -)
SHA=$3
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ -z "${SHA}" ]]; then
  echo "Usage: bash setup.sh <project-dir> <project-name> <sha>"
  exit 1
fi

mkdir -p ${PROJECT_DIR}

pushd ${PROJECT_DIR} &> /dev/null
git clone https://github.com/${REPO} ${PROJECT_NAME}

pushd ${PROJECT_DIR}/${PROJECT_NAME} &> /dev/null
mvn test-compile
popd &> /dev/null
popd &> /dev/null

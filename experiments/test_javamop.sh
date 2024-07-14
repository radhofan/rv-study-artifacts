#!/bin/bash
# 
# Usage: ./test_javamop.sh <repo-sha> <output-dir> <extensions-dir>
# assume agent is installed in repo OUTPUT_DIR/repo
# mvn -Dmaven.repo.local=${OUTPUT_DIR}/repo install:install-file -Dfile=javamop-stats-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar"
#
REPO_SHA=$1
OUTPUT_DIR=$2
EXTENSIONS_DIR=$3
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

source ${SCRIPT_DIR}/constants.sh
export RVMLOGGINGLEVEL=UNIQUE

if [[ ! -d ${EXTENSIONS_DIR} ]]; then
  echo "cannot find extensions dir"
  exit 1
fi

if [[ ! -d ${OUTPUT_DIR}/repo ]]; then
  echo "missing repo, install javamop agent first!"
  exit 1
fi

if [[ ! -d ${OUTPUT_DIR} ]]; then
  mkdir -p ${OUTPUT_DIR}
fi


repo=$(echo "${REPO_SHA}" | cut -d ',' -f 1)
project=$(echo "${repo}" | tr / -)
sha=$(echo "${REPO_SHA}" | cut -d ',' -f 2)

pushd ${OUTPUT_DIR}
git clone https://github.com/${repo} ${project}
pushd ${project}
git checkout ${sha}
(time timeout 3600 mvn -Dmaven.repo.local=${OUTPUT_DIR}/repo ${SKIP} -Dmaven.ext.class.path="${EXTENSIONS_DIR}/javamop-extension-1.0.jar" test-compile) &>> compile.log
(time timeout 3600 mvn -Dmaven.repo.local=${OUTPUT_DIR}/repo ${SKIP} -Dmaven.ext.class.path="${EXTENSIONS_DIR}/javamop-extension-1.0.jar" surefire:test) &>> test-rv.log
popd
popd

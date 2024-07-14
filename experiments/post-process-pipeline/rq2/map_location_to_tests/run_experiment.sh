#!/bin/bash
# Must  run this script in Docker...
# Usage: bash run_experiment.sh <repo-name> <sha>
# 
REPO=$1
PROJECT_NAME=$(echo ${REPO} | tr / -)
SHA=$2
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ -z "${SHA}" ]]; then
  echo "Usage: bash run_experiment.sh <project-dir> <project-name> <sha>"
  exit 1
fi

mkdir /home/tsm/projects
mkdir /home/tsm/logs

echo "Clone and compie"
(time bash /home/tsm/tsm-rv/experiments/post-process-pipeline/rq2/map_location_to_tests/setup.sh /home/tsm/projects ${REPO} ${SHA}) &> /home/tsm/logs/clone_compile.log
if [[ $? -ne 0 ]]; then
  echo "[TSM-RV] cannot compile"
  exit 1
fi

echo "Instrument"
(time bash /home/tsm/tsm-rv/experiments/post-process-pipeline/rq2/map_location_to_tests/instrument.sh /home/tsm/projects/${PROJECT_NAME} /home/tsm/mapping.csv /home/tsm/rv-adequacy/coverage_reporter) &> /home/tsm/logs/instrument.log
if [[ $? -ne 0 ]]; then
  echo "[TSM-RV] cannot instrument"
  exit 1
fi

echo "Test"
(time bash /home/tsm/tsm-rv/experiments/post-process-pipeline/rq2/map_location_to_tests/run_test.sh /home/tsm/projects/${PROJECT_NAME} /home/tsm/rv-adequacy/pom_extensions/target/pom-extension-1.0-SNAPSHOT.jar /home/tsm/rv-adequacy/setup.py) &> /home/tsm/logs/test.log
if [[ $? -ne 0 ]]; then
  echo "[TSM-RV] cannot test"
  exit 1
fi

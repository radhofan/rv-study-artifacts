#!/bin/bash
#
# Collect traces and find hot methods
# Usage: ./run_hot_methods_experiments.sh <repo> <sha> <output-dir> [by-test: true/false]
#
REPO=$1
SHA=$2
OUTPUT_DIR=$3
BY_TEST=$4
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
PROJECT_NAME=$(echo ${REPO} | tr / -)
LOG_PREFIX="[TSM-CTW]"

source ${SCRIPT_DIR}/experiments/constants.sh

if [[ -z ${REPO} || -z ${SHA} || -z ${OUTPUT_DIR} ]]; then
  echo "Usage bash run_hot_methods_experiments.sh <repo> <sha> <output-dir> [by-test: true/false]"
  exit 1
fi

if [[ ! ${OUTPUT_DIR} =~ ^/.* ]]; then
  OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
fi

function setup() {
  echo "${LOG_PREFIX} start setup"
  if [[ ! -f "${MAVEN_HOME}/lib/ext/measure-extension-1.0.jar" ]]; then
    cp ${SCRIPT_DIR}/extensions/measure-extension-1.0.jar ${MAVEN_HOME}/lib/ext/measure-extension-1.0.jar
  fi
  
  if [[ ! -f "${MAVEN_HOME}/lib/ext/ctw-extension-1.0.jar" ]]; then
    cp ${SCRIPT_DIR}/extensions/ctw-extension-1.0.jar ${MAVEN_HOME}/lib/ext/ctw-extension-1.0.jar
  fi
  
  if [[ ! -f "${MAVEN_HOME}/lib/ext/profiler-extension-1.0.jar" ]]; then
    cp ${SCRIPT_DIR}/extensions/profiler-extension-1.0.jar ${MAVEN_HOME}/lib/ext/profiler-extension-1.0.jar
  fi

  mkdir -p ${OUTPUT_DIR}
  echo "${LOG_PREFIX} end setup"
}

function checkout() {
  echo "${LOG_PREFIX} start checkout"
  mkdir -p ${SCRIPT_DIR}/projects
  mkdir -p ${SCRIPT_DIR}/repos
  
  pushd ${SCRIPT_DIR}/projects
  git clone https://github.com/${REPO} ${PROJECT_NAME} &>> ${OUTPUT_DIR}/checkout.log
  if [[ $? -ne 0 ]]; then
    echo "${LOG_PREFIX} cannot clone repository ${REPO}"
    exit 1
  fi

  pushd ${PROJECT_NAME}
  git checkout ${SHA} &>> ${OUTPUT_DIR}/checkout.log
  if [[ $? -ne 0 ]]; then
    echo "${LOG_PREFIX} cannot checkout repository ${REPO}"
    exit 1
  fi
  
  if [[ -f .gitmodules ]]; then
    git submodule update --init --recursive &>> ${OUTPUT_DIR}/checkout.log
    if [[ $? -ne 0 ]]; then
      echo "${LOG_PREFIX} cannot update submodule ${REPO}"
      exit 1
    fi
  fi
  popd
  popd

  echo "${LOG_PREFIX} end checkout"
}

function run_test() {
  echo "${LOG_PREFIX} start run_test"
  local repo="${SCRIPT_DIR}/repos/${PROJECT_NAME}"
  
  pushd ${SCRIPT_DIR}/projects/${PROJECT_NAME}
  mkdir -p /tmp/tsm-rv-1
  timeout ${TIMEOUT} mvn -Dmaven.repo.local="${repo}" -Djava.io.tmpdir=/tmp/tsm-rv-1 ${SKIP} test-compile &>> ${OUTPUT_DIR}/run_test.log
  if [[ $? -ne 0 ]]; then
    echo "${LOG_PREFIX} cannot compile project ${REPO}"
    exit 1
  fi


  timeout ${TIMEOUT} mvn -Dmaven.repo.local="${repo}" -Djava.io.tmpdir=/tmp/tsm-rv-1 ${SKIP} surefire:test &>> ${OUTPUT_DIR}/run_test.log
  if [[ $? -ne 0 ]]; then
    echo "${LOG_PREFIX} cannot test project ${REPO}"
    exit 1
  fi

  popd
  echo "${LOG_PREFIX} end run_test"
}

function setup_traces_collection() {
  local repo="${SCRIPT_DIR}/repos/${PROJECT_NAME}"
  mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
  mkdir -p ${SCRIPT_DIR}/projects/${PROJECT_NAME}/.all-traces
  
  # Install JUnit time listener
  pushd ${SCRIPT_DIR}/experiments/junit-measure-time
  mvn -Dmaven.repo.local="${repo}" install
  popd
  
  if [[ ! -f ${SCRIPT_DIR}/scripts/.trace-db.config ]]; then
    echo -e "db=memory\ndumpDB=false" >  ${SCRIPT_DIR}/scripts/.trace-db.config
  fi
  
  mvn install:install-file -Dmaven.repo.local="${repo}" -Dfile=${SCRIPT_DIR}/mop/agents/violations-ajc/track-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" &>> ${OUTPUT_DIR}/collect_traces.log
  
  export JUNIT_MEASURE_TIME_LISTENER=1
  export COLLECT_TRACES=1
  export COLLECT_MONITORS=1
  export MAVEN_OPTS="-Xmx500g -XX:-UseGCOverheadLimit"
}

function collect_traces() {
  echo "${LOG_PREFIX} start collect_traces"
  local repo="${SCRIPT_DIR}/repos/${PROJECT_NAME}"
  pushd ${SCRIPT_DIR}/projects/${PROJECT_NAME}
  
  export TRACEDB_PATH=${SCRIPT_DIR}/projects/${PROJECT_NAME}/.all-traces
  (time timeout ${TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local="${repo}" -Dsurefire.exitTimeout=86400 -Dmaven.ext.class.path=${SCRIPT_DIR}/extensions/javamop-extension-1.0.jar ${SKIP} surefire:test) &>> ${OUTPUT_DIR}/collect_traces.log
  if [[ $? -ne 0 ]]; then
    echo "${LOG_PREFIX} Cannot collect traces ${REPO}"
    exit 1
  fi
  
  if [[ ! -f "${TRACEDB_PATH}/unique-traces.txt" || ! -f "${TRACEDB_PATH}/specs-frequency.csv" || ! -f "${TRACEDB_PATH}/locations.txt" || ! -f "${TRACEDB_PATH}/traces.txt" ]]; then
    echo "${LOG_PREFIX} Cannot find collected traces ${REPO}"
    exit 1
  fi
  popd
  
  pushd ${SCRIPT_DIR}/scripts/projects/tracemop/scripts
  mv ${TRACEDB_PATH}/unique-traces.txt ${TRACEDB_PATH}/traces-id.txt
  python3 count-traces-frequency.py ${TRACEDB_PATH}
  if [[ $? -ne 0 || ! -f "${TRACEDB_PATH}/unique-traces.txt" ]]; then
    echo "${LOG_PREFIX} Cannot post-process traces ${REPO}"
    exit 1
  fi
  popd
  echo "${LOG_PREFIX} end collect_traces"
}

function collect_traces_by_test() {
  echo "${LOG_PREFIX} start collect_traces_by_test"
  local repo="${SCRIPT_DIR}/repos/${PROJECT_NAME}"
  pushd ${SCRIPT_DIR}/projects/${PROJECT_NAME}
  
  for test_class in $(ls target/surefire-reports/*.xml); do
    for test in $(python3 ${SCRIPT_DIR}/experiments/get_junit_testcases.py ${test_class}); do
      echo "${LOG_PREFIX} collecting ${test}"
      
      mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
      
      export TRACEDB_PATH=${SCRIPT_DIR}/projects/${PROJECT_NAME}/.all-traces/${test}
      mkdir -p ${TRACEDB_PATH}
  
      (time timeout ${TIMEOUT} mvn -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.repo.local="${repo}" -Dsurefire.exitTimeout=86400 -Dmaven.ext.class.path=${SCRIPT_DIR}/extensions/javamop-extension-1.0.jar ${SKIP} -Dtest=${test} surefire:test) &>> ${OUTPUT_DIR}/collect_traces-${test}.log
      
      if [[ $? -ne 0 ]]; then
        echo "${LOG_PREFIX} Cannot collect traces ${REPO} for test ${test}"
        exit 1
      fi
      
      if [[ ! -f "${TRACEDB_PATH}/unique-traces.txt" || ! -f "${TRACEDB_PATH}/specs-frequency.csv" || ! -f "${TRACEDB_PATH}/locations.txt" || ! -f "${TRACEDB_PATH}/traces.txt" ]]; then
        echo "${LOG_PREFIX} (WARNING) Cannot find collected traces ${REPO} for test ${test}"
        echo "${test},no trace" >> ${OUTPUT_DIR}/report.csv
      else
        pushd ${SCRIPT_DIR}/scripts/projects/tracemop/scripts
        mv ${TRACEDB_PATH}/unique-traces.txt ${TRACEDB_PATH}/traces-id.txt
        python3 count-traces-frequency.py ${TRACEDB_PATH}
        if [[ $? -ne 0 || ! -f "${TRACEDB_PATH}/unique-traces.txt" ]]; then
          echo "${LOG_PREFIX} Cannot post-process traces ${REPO}"
          exit 1
        fi
        
        echo "${test},OK" >> ${OUTPUT_DIR}/report.csv
        popd
      fi
    done
  done

  popd
  echo "${LOG_PREFIX} end collect_traces_by_test"
}

function get_hot_methods() {
  echo "${LOG_PREFIX} start get_hot_methods"
  mkdir -p ${OUTPUT_DIR}/hot-methods
  mkdir -p ${OUTPUT_DIR}/hot-methods-top5
  
  if [[ ${BY_TEST} == "true" ]]; then
    echo "by-test mode is on: will not find hot methods... (for now)"
    echo "${LOG_PREFIX} end get_hot_methods"
    return 0
  fi

  echo "${PROJECT_NAME}" > ${SCRIPT_DIR}/projects.txt
  pushd ${SCRIPT_DIR}/experiments/hot-methods

  bash ${SCRIPT_DIR}/experiments/hot-methods/run_all.sh ${SCRIPT_DIR}/projects ${SCRIPT_DIR}/projects.txt ${OUTPUT_DIR}/hot-methods false
  if [[ $? -ne 0 ]]; then
    echo "${LOG_PREFIX} Cannot get hot methods ${REPO}"
    exit 1
  fi
  
  bash ${SCRIPT_DIR}/experiments/hot-methods/generate_csv.sh ${SCRIPT_DIR}/projects ${SCRIPT_DIR}/projects.txt ${OUTPUT_DIR}/hot-methods ${OUTPUT_DIR}/hot-methods-top5 false
  if [[ $? -ne 0 ]]; then
    echo "${LOG_PREFIX} Cannot get top 5 hot methods ${REPO}"
    exit 1
  fi

  popd
  rm ${SCRIPT_DIR}/projects.txt
  echo "${LOG_PREFIX} end get_hot_methods"
}

export RVMLOGGINGLEVEL=UNIQUE
setup
checkout
run_test
setup_traces_collection

if [[ ${BY_TEST} == "true" ]]; then
  collect_traces_by_test
else
  collect_traces
fi

get_hot_methods

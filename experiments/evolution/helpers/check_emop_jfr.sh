#!/bin/bash
#
# Usage: check_emop_jfr.sh <emop-logs-dir> <ctw-log-dir> <projects-list> <working-dir> <profiler-reader-jar>
#
EMOP_LOGS_DIR=$1
CTW_LOGS_DIR=$2
PROJECTS_LIST=$3
WORKING_DIR=$4
PROFILER_READER_JAR=$5
SCRIPT_DIR=$(cd $(dirname $0) && pwd)

source ${SCRIPT_DIR}/../constants.sh

function check_input() {
  if [[ ! -d ${EMOP_LOGS_DIR} || ! -d ${CTW_LOGS_DIR} || -z ${WORKING_DIR} || ! -f ${PROJECTS_LIST} ]]; then
    echo "Usage bash check_emop_jfr.sh <emop-logs-dir> <ctw-log-dir> <projects-list> <working-dir> <profiler-reader-jar>"
    exit 1
  fi
  
  if [[ ! ${EMOP_LOGS_DIR} =~ ^/.* ]]; then
    EMOP_LOGS_DIR=${SCRIPT_DIR}/${EMOP_LOGS_DIR}
  fi
  
  if [[ ! ${CTW_LOGS_DIR} =~ ^/.* ]]; then
    CTW_LOGS_DIR=${SCRIPT_DIR}/${CTW_LOGS_DIR}
  fi
  
  if [[ ! ${WORKING_DIR} =~ ^/.* ]]; then
    WORKING_DIR=${SCRIPT_DIR}/${WORKING_DIR}
  fi
  
  if [[ ! -f "${PROFILER_READER_JAR}" ]]; then
    echo "Cannot find profiler-reader-jar"
    exit 1
  fi
  
  mkdir -p ${WORKING_DIR}/projects
  mkdir -p ${WORKING_DIR}/packages
}

function get_packages() {
  local project=$1
  local sha=$2

  if [[ ! -d ${WORKING_DIR}/projects/${project} ]]; then
    pushd ${WORKING_DIR}/projects &> /dev/null
    git clone ${CTW_LOGS_DIR}/${project}/output/project_download_jar ${project} &> /dev/null
    popd &> /dev/null
  
    mkdir -p ${WORKING_DIR}/packages/${project}
  fi
    
  pushd ${WORKING_DIR}/projects/${project} &> /dev/null
  git checkout $sha &> /dev/null
  popd &> /dev/null

  grep --text --include "*.java" -rhE "package [a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)*;" ${WORKING_DIR}/projects/${project} | grep "^package" | cut -d ' ' -f 2 | sed 's/;.*//g' > ${WORKING_DIR}/packages/${project}/${sha}.txt
}


function get_profiler() {
  local project=$1
  local sha=$2
  echo "> Reading ${project} - ${sha}"

  timeout 3600s java -jar ${PROFILER_READER_JAR} ${sha_dir}/test-rv-profiler/profile.jfr ${WORKING_DIR}/packages/${project}/${sha}.txt rv
  status=$?
  if [[ ${status} -eq 0 && -f output.csv ]]; then
    local samples=$(sed -n 2p output.csv)
    local samples_total=$(sed -n 3p output.csv)
    echo "${project},${sha},${samples},${samples_total}" >> ${SCRIPT_DIR}/profiler-emop-mop.csv

    rm output.csv
  else
    echo "${project},${sha},cannot run JFR reader on mop" >> ${SCRIPT_DIR}/profiler-data-${CLASSIFIER}.csv
  fi

  timeout 3600s java -jar ${PROFILER_READER_JAR} ${sha_dir}/emop_ps1c-profiler/profile.jfr ${WORKING_DIR}/packages/${project}/${sha}.txt rv
  status=$?
  if [[ ${status} -eq 0 && -f output.csv ]]; then
    local samples=$(sed -n 2p output.csv)
    local samples_total=$(sed -n 3p output.csv)
    echo "${project},${sha},${samples},${samples_total}" >> ${SCRIPT_DIR}/profiler-emop-ps1c.csv
    
    rm output.csv
  else
    echo "${project},${sha},cannot run JFR reader on ps1c" >> ${SCRIPT_DIR}/profiler-data-${CLASSIFIER}.csv
  fi
  
  timeout 3600s java -jar ${PROFILER_READER_JAR} ${sha_dir}/emop_ps3cl-profiler/profile.jfr ${WORKING_DIR}/packages/${project}/${sha}.txt rv
  status=$?
  if [[ ${status} -eq 0 && -f output.csv ]]; then
    local samples=$(sed -n 2p output.csv)
    local samples_total=$(sed -n 3p output.csv)
    echo "${project},${sha},${samples},${samples_total}" >> ${SCRIPT_DIR}/profiler-emop-ps3cl.csv

    rm output.csv
  else
    echo "${project},${sha},cannot run JFR reader on ps3cl" >> ${SCRIPT_DIR}/profiler-data-${CLASSIFIER}.csv
  fi
}

function get_results() {
  while read -r project; do
    if [[ ! -d ${EMOP_LOGS_DIR}/${project} ]]; then
      echo "${project},no emop run"
      continue
    fi
    
    if [[ ! -d ${CTW_LOGS_DIR}/${project} ]]; then
      echo "${project},no ctw run"
      continue
    fi
    
    local emop_result="${EMOP_LOGS_DIR}/${project}/logs/report.csv"
    if [[ ! -f ${emop_result} ]]; then
      echo "${project},no emop report" >> ${SCRIPT_DIR}/profiler-emop-error.csv
      continue
    fi

    for line in $(cat ${emop_result}); do
      sha=$(echo ${line} | cut -d ',' -f 1)

      sha_dir="${EMOP_LOGS_DIR}/${project}/logs/${sha}"
      if [[ -f ${sha_dir}/emop_ps1c-profiler/profile.jfr && ! -f ${sha_dir}/emop_ps3cl-profiler/profile.jfr ]]; then
        echo "${project},${sha},missing ps3cl profiler" >> ${SCRIPT_DIR}/profiler-emop-error.csv
      elif [[ ! -f ${sha_dir}/emop_ps1c-profiler/profile.jfr && -f ${sha_dir}/emop_ps3cl-profiler/profile.jfr ]]; then
        echo "${project},${sha},missing ps1c profiler" >> ${SCRIPT_DIR}/profiler-emop-error.csv
      elif [[ -f ${sha_dir}/emop_ps1c-profiler/profile.jfr && ! -f ${sha_dir}/test-rv-profiler/profile.jfr ]]; then
        echo "${project},${sha},missing mop profiler" >> ${SCRIPT_DIR}/profiler-emop-error.csv
      elif [[ -f ${sha_dir}/emop_ps1c-profiler/profile.jfr && -f ${sha_dir}/emop_ps3cl-profiler/profile.jfr && -f ${sha_dir}/test-rv-profiler/profile.jfr ]]; then
        get_packages ${project} ${sha}
    
        get_profiler ${project} ${sha}
      fi
    done
  done < ${PROJECTS_LIST}
}

check_input
get_results

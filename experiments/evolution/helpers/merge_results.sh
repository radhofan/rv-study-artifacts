#!/bin/bash
#
# Usage: merge_results.sh <emop-logs-dir> <ctw-logs-dir> <output-dir> <projects-list>
#
EMOP_LOGS_DIR=$1
CTW_LOGS_DIR=$2
OUTPUT_DIR=$3
PROJECTS_LIST=$4
SCRIPT_DIR=$(cd $(dirname $0) && pwd)

source ${SCRIPT_DIR}/../constants.sh

function check_input() {
  if [[ ! -d ${EMOP_LOGS_DIR} || ! -d ${CTW_LOGS_DIR} || ! -f ${PROJECTS_LIST} ]]; then
    echo "Usage bash merge_results.sh <emop-logs-dir> <ctw-logs-dir> <output-dir> <projects-list>"
    exit 1
  fi
  
  if [[ ! ${EMOP_LOGS_DIR} =~ ^/.* ]]; then
    EMOP_LOGS_DIR=${SCRIPT_DIR}/${EMOP_LOGS_DIR}
  fi
  
  if [[ ! ${CTW_LOGS_DIR} =~ ^/.* ]]; then
    CTW_LOGS_DIR=${SCRIPT_DIR}/${CTW_LOGS_DIR}
  fi
  
  if [[ ! ${OUTPUT_DIR} =~ ^/.* ]]; then
    OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
  fi
  
  mkdir -p ${OUTPUT_DIR}
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
    local ctw_result="${CTW_LOGS_DIR}/${project}/logs/report.csv"
    if [[ ! -f ${emop_result} ]]; then
      echo "${project},no emop report"
      continue
    fi
    
    if [[ ! -f ${ctw_result} ]]; then
      echo "${project},no ctw report"
      continue
    fi
    
    echo "project,sha,test time,test status,mop time,mop status,ps1c time,ps1c status,ps3cl time,ps3cl status,ctw download status,ctw compile time,ctw compile status,ctw instr time,ctw instr status,ctw mop time,ctw mop status,ctw e2e time,base rv,instr source time" >> ${OUTPUT_DIR}/${project}.csv
    for line in $(cat ${emop_result}); do
      sha=$(echo ${line} | cut -d ',' -f 1)
      local base_rv=0
      local instrument_time_if_source_only=-1
      
      if [[ -n $(grep --text "Reverting to Base RV" ${EMOP_LOGS_DIR}/${project}/logs/${sha}/emop_ps1c.log) ]]; then
        base_rv=1
      fi

      emop=$(echo ${line} | tr -d '\n')
      if [[ -n $(grep ${sha} ${ctw_result}) ]]; then
        ctw=$(grep ${sha} ${ctw_result} | cut -d ',' -f 2- | tr -d '\n')
      else
        ctw="no commit in ctw"
      fi
      
      local instr_log=${CTW_LOGS_DIR}/${project}/logs/${sha}/instrument.log
      local source_instr_log=${CTW_LOGS_DIR}/${project}/logs/${sha}/.evolution_ctw/logs/instrumentation/source.log
      if [[ -f ${instr_log} && -f ${source_instr_log} ]]; then
        if [[ -n $(grep "Re-instrumented source and lib" ${instr_log}) ]]; then
          # Reinstrumented source and jars
          local instr_source_libs_time=$(grep "Re-instrumented source and lib" ${instr_log} | cut -d '(' -f 2 | cut -d ' ' -f 1)
          local total_instr_time=$(tail ${instr_log} -n 1 | cut -d ' ' -f 3)
          local instr_source_time=$(grep "Re-instrumented source" ${source_instr_log} | cut -d '(' -f 2 | cut -d ' ' -f 1)

          instrument_time_if_source_only=$(echo "${total_instr_time} - ${instr_source_libs_time} + ${instr_source_time}" | bc -l)
          # Instrument source e2e time = Instrument all e2e time - Instrument source and jars time + Instrument source time
        fi
      fi

      echo "${project},${emop},${ctw},${base_rv},${instrument_time_if_source_only}" >> ${OUTPUT_DIR}/${project}.csv
    done
  done < ${PROJECTS_LIST}
}

check_input
get_results

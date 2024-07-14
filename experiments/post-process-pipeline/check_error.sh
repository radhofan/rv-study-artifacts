#!/bin/bash
#
# Check run_all_experiments.sh's output
# Usage: ./check_error.sh <output-dir>
#
OUTPUT_DIR=$1
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ ! -d "${OUTPUT_DIR}" ]]; then
  echo "Cannot find output directory"
  exit 1
fi


UNKNOWN=()
CHECK_PROJECT=()
CLONE_PROJECT=()
TESTS=()
RV_LTW_TESTS=()
RV_LTW_TIME=()
RV_CTW_TESTS=()
RV_CTW_TIME_STATUS=()
RV_CTW_TIME=()
MOP_PROFILER=()
FIND_HOT_METHODS=()
FIND_HOT_METHODS_JARS=()
REMOVE_HOT_METHODS=()
NOHOT_PROFILER=()
JFR_CSV=()
CHARTS=()
OK_PROJECTS=()


function check_status() {
  pushd ${OUTPUT_DIR} > /dev/null

  for project in $(ls); do
    local last_line=$(tac ${project}/docker.log | grep "TSM" -m 1)
    if [[ -z "${last_line}" ]]; then
      echo "${project},unknown"
      UNKNOWN+=(${project})
      continue
    fi
    
    if [[ ${last_line} == *"missing check_project.sh"* ]]; then
      echo "${project},check_project failed"
      CHECK_PROJECT+=(${project})
      continue
    fi

    if [[ ${last_line} == *"cannot clone project"* ]]; then
      echo "${project},clone failed"
      CLONE_PROJECT+=(${project})
      continue
    fi

    if [[ ${last_line} == *"cannot test project"* && ${last_line} != *"with LTW RV"* && ${last_line} != *"with CTW RV"* ]]; then
      echo "${project},test failed"
      TESTS+=(${project})
      continue
    fi
    
    if [[ ${last_line} == *"cannot test project"* && ${last_line} == *"with LTW RV"* ]]; then
      echo "${project},regular javamop (ltw) failed"
      RV_LTW_TESTS+=(${project})
      continue
    fi
    
    if [[ ${last_line} == *"LTW MOP time too short"* ]]; then
      if [[ ! -f "${project}/logs/check_project/${project}/result.csv" ]]; then
        echo "${project},unknown"
        UNKNOWN+=(${project})
        continue
      else
        if [[ $(cut -d ',' -f 5 "${project}/logs/check_project/${project}/result.csv") == "-1" ]]; then
          echo "${project},test failed"
          TESTS+=(${project})
          continue
        fi
        
        if [[ $(cut -d ',' -f 6 "${project}/logs/check_project/${project}/result.csv") == "-1" ]]; then
          echo "${project},regular javamop (ltw) failed"
          RV_LTW_TESTS+=(${project})
          continue
        fi
      fi

      echo "${project},ltw time too short"
      RV_LTW_TIME+=(${project})
      continue
    fi
    
    if [[ ${last_line} == *"cannot test project"* && ${last_line} == *"with CTW RV"* ]]; then
      echo "${project},ctw failed"
      RV_CTW_TESTS+=(${project})
      continue
    fi
    
    if [[ ${last_line} == *"cannot measure CTW time"* ]]; then
      echo "${project},ctw time measure failed"
      RV_CTW_TIME_STATUS+=(${project})
      continue
    fi
    
    if [[ ${last_line} == *"CTW MOP time too short"* ]]; then
      echo "${project},ctw time too short"
      RV_CTW_TIME+=(${project})
      continue
    fi
    
    if [[ ${last_line} == *"cannot run profiler (nomop and mop) on project"* ]]; then
      echo "${project},mop profiler failed"
      MOP_PROFILER+=(${project})
      continue
    fi
    
    if [[ ${last_line} == *"cannot run find hot methods (time)"* ]]; then
      echo "${project},finding hot methods failed"
      FIND_HOT_METHODS+=(${project})
      continue
    fi
    
    if [[ ${last_line} == *"cannot find affected jars (time)"* ]]; then
      echo "${project},finding hot methods jars failed"
      FIND_HOT_METHODS_JARS+=(${project})
      continue
    fi
    
    if [[ ${last_line} == *"cannot remove hot methods (time)"* ]]; then
      echo "${project},cannot remove hot methods"
      REMOVE_HOT_METHODS+=(${project})
      continue
    fi
    
    if [[ ${last_line} == *"cannot run profiler (nohot-time) on project"* ]]; then
      echo "${project},cannot run profiler after removed hot methods"
      NOHOT_PROFILER+=(${project})
      continue
    fi
    
    if [[ ${last_line} == *"cannot convert JFR to CSV for project"* ]]; then
      echo "${project},jfr to csv failed"
      JFR_CSV+=(${project})
      continue
    fi
      
    if [[ ${last_line} == *"cannot generate profiling chart for project"* ]]; then
      echo "${project},generate charts failed"
      CHARTS+=(${project})
      continue
    fi
    
    if [[ ${last_line} == *"end convert_profiler_result"* ]]; then
      echo "${project},OK"
      OK_PROJECTS+=(${project})
      continue
    fi
      
    echo "${project},unknown"
    UNKNOWN+=(${project})
  done

  popd > /dev/null
}

check_status

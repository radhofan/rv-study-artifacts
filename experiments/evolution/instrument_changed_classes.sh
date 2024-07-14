#!/bin/bash
#
# Instrument changed classes only
# Usage: instrument_changed_classes.sh <project-dir> <classpath-file> 
#
PROJECT_DIR=$1
CP_FILE=$2
SCRIPT_DIR=$(cd $(dirname $0) && pwd)

source ${SCRIPT_DIR}/../constants.sh

function check_input() {
  if [[ ! -d ${PROJECT_DIR} || ! -f ${CP_FILE} ]]; then
    echo "Usage bash instrument_changed_classes.sh <project-dir> <classpath-file>"
    exit 1
  fi
  
  if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
    PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
  fi
  
  mkdir -p /tmp/tsm-rv-instr && chmod -R +w /tmp/tsm-rv-instr && rm -rf /tmp/tsm-rv-instr && mkdir -p /tmp/tsm-rv-instr
  JAR_CP=$(cat ${CP_FILE})
}

function reinstrument_classes() {
  if [[ -d /tmp/tsm-rv/instr/classes ]]; then
    # Instrument uninstrumented bytecode and store it to target/tmp-classes
    echo "Instrumenting classes"
    local reinstrument_classes_start=$(date +%s%3N)
    
    ajc -Xlint:ignore -1.8 -encoding UTF-8 -showWeaveInfo -aspectpath ${SCRIPT_DIR}/../../compile-time-weaving/myaspects.jar -classpath ${JAR_CP}:${SCRIPT_DIR}/../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${CLASSPATH}:${PROJECT_DIR}/target/classes -inpath /tmp/tsm-rv/instr/classes -d ${PROJECT_DIR}/target/tmp-classes
    local status=$?
    
    local reinstrument_classes_end=$(date +%s%3N)
    echo "Instrumented classes! ($((reinstrument_classes_end - reinstrument_classes_start)) ms)"
    
    rm -rf /tmp/tsm-rv/instr/classes
    return ${status}
  else
    echo "Don't need to re-instrument classes"
  fi
}

function reinstrument_test_classes() {
  if [[ -d /tmp/tsm-rv/instr/test-classes ]]; then
    # Instrument uninstrumented bytecode and store it to target/tmp-test-classes
    echo "Instrumenting test-classes"
    local reinstrument_test_classes_start=$(date +%s%3N)
    
    ajc -Xlint:ignore -1.8 -encoding UTF-8 -showWeaveInfo -aspectpath ${SCRIPT_DIR}/../../compile-time-weaving/myaspects.jar -classpath ${JAR_CP}:${SCRIPT_DIR}/../../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${CLASSPATH}:${PROJECT_DIR}/target/classes:${CLASSPATH}:${PROJECT_DIR}/target/test-classes -inpath /tmp/tsm-rv/instr/test-classes -d ${PROJECT_DIR}/target/tmp-test-classes
    local status=$?
    
    local reinstrument_test_classes_end=$(date +%s%3N)
    echo "Instrumented test-classes! ($((reinstrument_test_classes_end - reinstrument_test_classes_start)) ms)"
    
    rm -rf /tmp/tsm-rv/instr/test-classes
    return ${status}
  else
    echo "Don't need to re-instrument test-classes"
  fi
}

function reinstrument() {
  local reinstrument_start=$(date +%s%3N)
  pushd ${PROJECT_DIR}
  
  # Copy instrumented bytecode to tmp-classes
  cp -r ${PROJECT_DIR}/.evolution_ctw/instrumented-classes ${PROJECT_DIR}/target/tmp-classes
  cp -r ${PROJECT_DIR}/.evolution_ctw/instrumented-test-classes ${PROJECT_DIR}/target/tmp-test-classes
  
  local find_diff_start=$(date +%s%3N)
  
  echo "Diffing classes"
  # Copy all the changed .class file to /tmp/tsm-rv/instr/classes and /tmp/tsm-rv/instr/test-classes
  while read -r difference; do
    # If difference is one of the following
    #   Only in target/classes: A.class
    #   Files target/classes/A.class and .evolution_ctw/uninstrumented-classes/B.class differ
    # then file should be target/classes/A.class
    if [[ -n ${difference} ]]; then
      # difference can be empty...
      file=""
      echo "Parsing diff: $difference"
      differ_regex="Files (target/classes/.*) and (.*)"
      if [[ ${difference} =~ ${differ_regex} ]]; then
        file=${BASH_REMATCH[1]}
      else
        only_in_regex="Only in (target/classes.*): (.*)"
        if [[ ${difference} =~ ${only_in_regex} ]]; then
          file="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        fi
      fi
      
      if [[ -n ${file} ]]; then
        # If match
        local dest=$(dirname $(echo "${file}" | cut -d '/' -f 3-))
        
        if [[ -d ${file} ]]; then
          # new directory
          mkdir -p /tmp/tsm-rv/instr/classes/${dest}
          cp -r ${file} /tmp/tsm-rv/instr/classes/${dest}
          
          # ajc will NOT copy non *.class file back to target/tmp-classes
          # so we have to find all the non-class file and copy it
          while read -r resource_file; do
            if [[ -n ${resource_file} ]]; then
              local resource_dest=$(dirname "$(echo ${resource_file} | cut -d '/' -f 3-)")
              mkdir -p ${PROJECT_DIR}/target/tmp-classes/${resource_dest}
              cp ${resource_file} ${PROJECT_DIR}/target/tmp-classes/${resource_dest}
              
              echo "Copy non .class file from ${resource_file} to ${PROJECT_DIR}/target/tmp-classes/${resource_dest}"
            fi
          done <<< $(find ${file} -type f ! -name "*.class")  # Search all non *.class file in ${file} directory
          
          echo "Found new directory in classes, instrument directory: ${file}"
        elif [[ ${file} == *class ]]; then
          mkdir -p /tmp/tsm-rv/instr/classes/${dest}
          
          # If file is target/classes/hello/world/A$B.class, then we want to copy
          # target/classes/hello/world/A* to /tmp/tsm-rv/instr/classes/hello/world/
          if [[ ${file} == *\$* ]]; then
            local dir_name=$(dirname ${file})
            local name_before_first_dollar_sign=$(basename ${file} | cut -d '$' -f 1)
            cp ${dir_name}/${name_before_first_dollar_sign}* /tmp/tsm-rv/instr/classes/${dest}
            
            echo "Found new classes: ${dir_name}/${name_before_first_dollar_sign}*"
          else
            cp ${file} /tmp/tsm-rv/instr/classes/${dest}

            # If file is target/classes/hello/world/A.class, then we want to copy
            # target/classes/hello/world/A$*.class to /tmp/tsm-rv/instr/classes/hello/world/
            cp "$(dirname ${file})/$(basename ${file} .class)$"* /tmp/tsm-rv/instr/classes/${dest} || :
            echo "Found new class: ${file}"
          fi
        else
          # it is not a directory and not a .class file, so it must be resources
          mkdir -p target/tmp-classes/${dest}
          cp ${file} ${PROJECT_DIR}/target/tmp-classes/${dest}
          
          echo "Found new file: ${file}"
        fi
      fi
    else
      only_in_regex="Only in (.evolution_ctw/uninstrumented-classes.*): (.*)"
      if [[ ${difference} =~ ${only_in_regex} ]]; then
        # In old uninstrumented target, but not new. We should remove the instrumented class.
        file="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        local deleted_file=${PROJECT_DIR}/target/tmp-classes/$(echo "${file}" | cut -d '/' -f 3-)
        rm -rf ${deleted_file}
        
        echo "File ${file} in old uninstrumented code and not in new. Deleted ${deleted_file}"
      fi
    fi
  done <<< "$(diff -qr target/classes .evolution_ctw/uninstrumented-classes)"

  echo "Diffing test-classes"
  while read -r difference; do
    # If difference is one of the following
    #   Only in target/test-classes: A.class
    #   Files target/test-classes/A.class and .evolution_ctw/uninstrumented-test-classes/B.class differ
    # then file should be target/test-classes/A.class
    if [[ -n ${difference} ]]; then
      # difference can be empty...
      file=""
      echo "Parsing diff: $difference"
      differ_regex="Files (target/test-classes/.*) and (.*)"
      if [[ ${difference} =~ ${differ_regex} ]]; then
        file=${BASH_REMATCH[1]}
      else
        only_in_regex="Only in (target/test-classes.*): (.*)"
        if [[ ${difference} =~ ${only_in_regex} ]]; then
          file="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        fi
      fi
      
      if [[ -n ${file} ]]; then
        # If match
        local dest=$(dirname $(echo "${file}" | cut -d '/' -f 3-))
        
        if [[ -d ${file} ]]; then
          # new directory
          mkdir -p /tmp/tsm-rv/instr/test-classes/${dest}
          cp -r ${file} /tmp/tsm-rv/instr/test-classes/${dest}
          
          # ajc will NOT copy non *.class file back to target/tmp-test-classes
          # so we have to find all the non-class file and copy it
          while read -r resource_file; do
            if [[ -n ${resource_file} ]]; then
              local resource_dest=$(dirname "$(echo ${resource_file} | cut -d '/' -f 3-)")
              mkdir -p ${PROJECT_DIR}/target/tmp-test-classes/${resource_dest}
              cp ${resource_file} ${PROJECT_DIR}/target/tmp-test-classes/${resource_dest}
              
              echo "Copy non .class file from ${resource_file} to ${PROJECT_DIR}/target/tmp-test-classes/${resource_dest}"
            fi
          done <<< $(find ${file} -type f ! -name "*.class")  # Search all non *.class file in ${file} directory
          
          echo "Found new directory in test-classes, instrument directory: ${file}"
        elif [[ ${file} == *class ]]; then
          mkdir -p /tmp/tsm-rv/instr/test-classes/${dest}
          
          # If file is target/test-classes/hello/world/A$B.class, then we want to copy
          # target/test-classes/hello/world/A* to /tmp/tsm-rv/instr/test-classes/hello/world/
          if [[ ${file} == *\$* ]]; then
            local dir_name=$(dirname ${file})
            local name_before_first_dollar_sign=$(basename ${file} | cut -d '$' -f 1)
            cp ${dir_name}/${name_before_first_dollar_sign}* /tmp/tsm-rv/instr/test-classes/${dest}
            
            echo "Found new test-classes: ${dir_name}/${name_before_first_dollar_sign}*"
          else
            cp ${file} /tmp/tsm-rv/instr/test-classes/${dest}

            # If file is target/test-classes/hello/world/A.class, then we want to copy
            # target/test-classes/hello/world/A$*.class to /tmp/tsm-rv/instr/test-classes/hello/world/
            cp "$(dirname ${file})/$(basename ${file} .class)$"* /tmp/tsm-rv/instr/test-classes/${dest} || :
            echo "Found new test-class: ${file}"
          fi
        else
          # it is not a directory and not a .class file, so it must be resources
          mkdir -p target/tmp-test-classes/${dest}
          cp ${file} ${PROJECT_DIR}/target/tmp-test-classes/${dest}
          
          echo "Found new test-file: ${file}"
        fi
      else
        only_in_regex="Only in (.evolution_ctw/uninstrumented-test-classes.*): (.*)"
        if [[ ${difference} =~ ${only_in_regex} ]]; then
          # In old uninstrumented target, but not new. We should remove the instrumented class.
          file="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
          local deleted_file=${PROJECT_DIR}/target/tmp-test-classes/$(echo "${file}" | cut -d '/' -f 3-)
          rm -rf ${deleted_file}
          
          echo "File ${file} in old uninstrumented code and not in new. Deleted ${deleted_file}"
        fi
      fi
    fi
  done <<< "$(diff -qr target/test-classes .evolution_ctw/uninstrumented-test-classes)"
  local find_diff_end=$(date +%s%3N)
  echo "Found source diff! ($((find_diff_end - find_diff_start)) ms)"
  
  reinstrument_classes
  local classes_status=$?
  
  reinstrument_test_classes
  local test_classes_status=$?
  
  local reinstrument_end=$(date +%s%3N)
  echo "Re-instrumented source! ($((reinstrument_end - reinstrument_start)) ms)"
  
  if [[ ${classes_status} -ne 0 || ${test_classes_status} -ne 0 ]]; then
    rm -rf ${PROJECT_DIR}/target/tmp-classes ${PROJECT_DIR}/target/tmp-test-classes
    exit 1
  else
    # No error, store uninstrumented bytecode then save instrumented bytecode to target/classes and target/test-classes
    rm -rf ${PROJECT_DIR}/.evolution_ctw/uninstrumented-classes ${PROJECT_DIR}/.evolution_ctw/uninstrumented-test-classes
    mv ${PROJECT_DIR}/target/classes ${PROJECT_DIR}/.evolution_ctw/uninstrumented-classes
    mv ${PROJECT_DIR}/target/test-classes ${PROJECT_DIR}/.evolution_ctw/uninstrumented-test-classes

    # save instrumented bytecode to target/classes and .evolution_ctw/instrumented-classes
    rm -rf ${PROJECT_DIR}/.evolution_ctw/instrumented-classes ${PROJECT_DIR}/.evolution_ctw/instrumented-test-classes
    cp -r ${PROJECT_DIR}/target/tmp-classes ${PROJECT_DIR}/.evolution_ctw/instrumented-classes
    cp -r ${PROJECT_DIR}/target/tmp-test-classes ${PROJECT_DIR}/.evolution_ctw/instrumented-test-classes
    mv ${PROJECT_DIR}/target/tmp-classes ${PROJECT_DIR}/target/classes
    mv ${PROJECT_DIR}/target/tmp-test-classes ${PROJECT_DIR}/target/test-classes
    exit 0
  fi
}

check_input
reinstrument

#!/bin/bash
#
# Run JFR reader on multiple projects (Run profile_with_mop.sh and check_profiler.sh first)
# Usage: ./check_jfr.sh <output-dir> <projects-list> <profiler-reader-jar> <classifier>
#
OUTPUT_DIR=$1
PROJECTS_LIST=$2
PROFILER_READER_JAR=$3
CLASSIFIER=$4
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ ! -d "${OUTPUT_DIR}" ]]; then
  echo "Cannot find output directory"
  exit 1
fi

if [[ ! -f "${PROJECTS_LIST}" ]]; then
  echo "Cannot find projects list"
  exit 1
fi

if [[ ! -f "${PROFILER_READER_JAR}" ]]; then
  echo "Cannot find profiler-reader-jar"
  exit 1
fi

if [[ ${CLASSIFIER} != "violation" && ${CLASSIFIER} != "rv" && ${CLASSIFIER} != "overall" && ${CLASSIFIER} != "gc" ]]; then
  echo "Unknown classifier: ${CLASSIFIER}"
  exit 1
fi

function read_projects() {
  while read -r project; do
    echo "Start processing ${project}"
    pushd ${OUTPUT_DIR}/${project} &> /dev/null
    for jfr in $(find logs/mop-profiling/${project} -name "profile.jfr*"); do
      if [[ -z ${jfr} ]]; then
        echo "${project},no jfr file" >> ${SCRIPT_DIR}/profiler-data-${CLASSIFIER}.csv
        continue
      fi

      local module_name=$(echo "${jfr}" | rev | cut -d '/' -f 1 | rev)
      echo "> Start reading JFR file ${jfr} for module ${module_name}"
      
      if [[ ! -f "logs/mop-profiling/${project}/packages.txt" ]]; then
        grep --include "*.java" -rhE "package [a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)*;" projects-orig/projects/${project} | grep "^package" | cut -d ' ' -f 2 | sed 's/;.*//g' | sort -u > logs/mop-profiling/${project}/packages.txt
      fi
      
      if [[ ${CLASSIFIER} == "overall" ]]; then
        timeout 3600s java -jar ${PROFILER_READER_JAR} ${jfr} logs/mop-profiling/${project}/packages.txt ${CLASSIFIER} logs/mop-profiling/${project}/test-classes.txt logs/mop-profiling/${project}/test-methods.txt logs/mop-profiling/${project}/test-fixtures.txt
        status=$?
      else
        timeout 3600s java -jar ${PROFILER_READER_JAR} ${jfr} logs/mop-profiling/${project}/packages.txt ${CLASSIFIER}
        status=$?
      fi
      
      if [[ ${status} -eq 0 && -f output.csv ]]; then
        local samples=$(sed -n 2p output.csv)
        if [[ ${CLASSIFIER} == "rv" || ${CLASSIFIER} == "overall" || ${CLASSIFIER} == "gc" ]]; then
          local samples_total=$(sed -n 3p output.csv)
          echo "${project},${module_name},${samples},${samples_total}" >> ${SCRIPT_DIR}/profiler-data-${CLASSIFIER}.csv
        else
          echo "${project},${module_name},${samples}" >> ${SCRIPT_DIR}/profiler-data-${CLASSIFIER}.csv
        fi
        rm output.csv
      else
        echo "${project},cannot run JFR reader" >> ${SCRIPT_DIR}/profiler-data-${CLASSIFIER}.csv
      fi
    done
    popd &> /dev/null
  done < ${PROJECTS_LIST}
}

read_projects

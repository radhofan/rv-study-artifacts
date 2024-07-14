#!/bin/bash
#
# View project hot method stats
# Usage: view_stats_per_project.sh <csv-dir> <projects-dir> [show: true/false]
# Given the output directory of `generate_csv.sh`, view each project stats
# Output a csv file: project, traces T/all traces ratio, trace O/all traces ratio
# If show is true, then it will list out methods name instead
#
CSV_DIR=$1
PROJECTS_DIR=$2
SHOW=$3

function check_inputs() {
  if [[ ! -d "${CSV_DIR}" || ! -d ${PROJECTS_DIR} ]]; then
    echo "Usage: ./view_stats_per_project.sh <csv-dir> <projects-dir> [show: true/false]"
    exit 1
  fi
}

function show_methods() {
  for project in $(ls ${CSV_DIR}); do
    grep --include "*.java" -rhE "package [a-z0-9_]+(\.[a-z0-9_]+)*;" ${PROJECTS_DIR}/${project} | sort -u | cut -d ' ' -f 2 | cut -d ';' -f 1 > .packages.txt

    local i=1
    local methods=""

    for method in $(cut -d ',' -f 1 ${CSV_DIR}/${project}/top5.csv); do
      # If method is a.b.c.D.foo
      # package should be a.b.c
      if [[ $(echo ${method} | grep -o "\." | wc -l) -ge 2 ]]; then
        local package=$(echo ${method} | rev | cut -d '.' -f 3- | rev)
        if [[ -z $(grep ${package} .packages.txt) ]]; then
          methods="${methods},${i} ${method}"
          
          sed -n ${i}p ${CSV_DIR}/${project}/top5.csv >> .filtered.txt
        fi
      else
        # method is a, or a.b
        echo "${project} ${method} cannot find package"
      fi
      ((i++))
    done
    
    if [[ -f .filtered.txt ]]; then
      local ratioT=$(awk -F ',' '{printf "%.4f\n", 100*$6/$2}' .filtered.txt | paste -sd+ | bc -l)
      local ratioO=$(awk -F ',' '{printf "%.4f\n", 100*$7/$2}' .filtered.txt | paste -sd+ | bc -l)
      echo "${project},${ratioT},${ratioO},${methods}"
      rm -rf .filtered.txt
    else
      echo "${project},0,0"
    fi
  done
  
  rm -f .packages.txt
}

function check_stats() {
  echo "project,traces T/all traces ratio,trace O/all traces ratio"
  for project in $(ls ${CSV_DIR}); do
    # Column 2 is all traces, column 6 is all traces that contain at least 1 event from hot method,
    # column 7 is all traces that contain only event from hot method
    local ratioT=$(awk -F ',' '{printf "%.4f\n", 100*$6/$2}' ${CSV_DIR}/${project}/top5.csv | paste -sd+ | bc -l)
    local ratioO=$(awk -F ',' '{printf "%.4f\n", 100*$7/$2}' ${CSV_DIR}/${project}/top5.csv | paste -sd+ | bc -l)
    
    echo "${project},${ratioT},${ratioO}"
  done
}

check_inputs

if [[ ${SHOW} == "true" ]]; then
  show_methods
else
  check_stats
fi


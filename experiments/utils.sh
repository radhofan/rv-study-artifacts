#!/bin/bash

function move_violations() {
  local directory=$1
  local filename=$2
  for violation in $(find -name "violation-counts"); do
    local name=$(echo "${violation}" | rev | cut -d '/' -f 2 | rev)
    if [[ ${name} != "." ]]; then
      # Is MMMP, add module name to file name
      mv ${violation} ${directory}/${filename}_${name}
    else
      mv ${violation} ${directory}/${filename}
    fi
  done
}

function delete_violations() {
  for violation in $(find -name "violation-counts"); do
    rm ${violation}
  done
}

function move_jfr() {
  local directory=$1
  local filename=$2
  for jfr in $(find -name "profile.jfr"); do
    local name=$(echo "${jfr}" | rev | cut -d '/' -f 2 | rev)
    if [[ ${name} != "." ]]; then
      # Is MMMP, add module name to file name
      mv ${jfr} ${directory}/${filename}_${name}
    else
      mv ${jfr} ${directory}/${filename}
    fi
  done
}

#!/bin/bash
#
# Run treat_special on a set of projects
# Usage: patch_projects.sh <projects-list>
#

PROJECTS_LIST=$1
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ ! -f "${PROJECTS_LIST}" ]]; then
  echo "Cannot find ${PROJECTS_LIST}"
  exit 1
fi

. ${SCRIPT_DIR}/../experiments/treat_special.sh

while read -r project; do
  if [[ -d "${SCRIPT_DIR}/projects/${project}" ]]; then
    pushd "${SCRIPT_DIR}/projects/${project}"
    treat_special ${project}
    popd
  fi
done < ${PROJECTS_LIST}

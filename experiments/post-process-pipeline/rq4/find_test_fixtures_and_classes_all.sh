#!/bin/bash
#
# Find all the test fixture and classes for all projects
# Usage: find_test_fixtures_and_classes_all.sh <projects-dir> <projects-list>
#
PROJECTS_DIR=$1
PROJECTS_LIST=$2
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ -z ${PROJECTS_DIR} || ! -d ${PROJECTS_DIR} || ! -f ${PROJECTS_LIST} ]]; then
	echo "Usage: bash find_test_fixtures_and_classes_all.sh <projects-dir> <projects-list>"
	exit 1
fi

while read -r project; do
	echo "bash ${SCRIPT_DIR}/find_test_fixtures_and_classes.sh ${PROJECTS_DIR}/${project}/projects-orig/projects/${project} ${PROJECTS_DIR}/${project}/logs/mop-profiling/${project}" >> ${SCRIPT_DIR}/commands.txt
done < ${PROJECTS_LIST}

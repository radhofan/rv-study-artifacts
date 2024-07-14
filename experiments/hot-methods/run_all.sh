#!/bin/bash
#
# Find hot methods for all given projects
# Usage: run_all.sh <project-dir> <projects-list> <log-dir> [is-test-by-test: true]
# This script will find project in project-dir, copy it to tmp-dir, run hot_methods_locator.py, then save the log to log-dir
#
PROJECT_DIR=$1
PROJECTS_LIST=$2
LOG_DIR=$3
TEST_BY_TEST=$4
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

check_inputs() {
	if [[ -z "${PROJECT_DIR}" || -z "${PROJECTS_LIST}" || -z "${LOG_DIR}" ]]; then
		echo "Usage: ./run_all.sh <project-dir> <projects-list> <log-dir> [is-test-by-test: true]"
		exit 1
	fi
	
	if [[ -z "${TEST_BY_TEST}" ]]; then
		TEST_BY_TEST=true
	fi
}

# Convert relative path to absolute path
function convert_to_absolute_paths() {
	if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
		PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
	fi
	
	if [[ ! ${LOG_DIR} =~ ^/.* ]]; then
		LOG_DIR=${SCRIPT_DIR}/${LOG_DIR}
	fi
}

function run_hot_methods_locator_on_project() {
	local project=$1
	echo "Running ${project}..."

	if [[ ${TEST_BY_TEST} == true ]]; then
		python3 ${SCRIPT_DIR}/hot_methods_locator.py ${PROJECT_DIR}/${project} &> ${LOG_DIR}/${project}.log
	else
		python3 ${SCRIPT_DIR}/hot_methods_locator.py ${PROJECT_DIR}/${project}/.all-traces &> ${LOG_DIR}/${project}.log
	fi
}

function run_all() {
	mkdir -p ${LOG_DIR}

	while read -r project; do
		if [[ -d "${PROJECT_DIR}/${project}" ]]; then
			run_hot_methods_locator_on_project ${project}
		fi
	done < ${PROJECTS_LIST}
}

check_inputs
convert_to_absolute_paths
run_all

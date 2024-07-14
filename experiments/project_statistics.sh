#!/bin/bash
# Get project statistics: LOC, code coverage
# Usage: project_statistics.sh <repo> <sha> <log-dir>
#
REPO=$1
SHA=$2
LOG_DIR=$3
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
PROJECT_NAME=$(echo ${REPO} | tr / -)

source ${SCRIPT_DIR}/constants.sh
SKIP_WITH_JACOCO="-Dcheckstyle.skip -Drat.skip -Denforcer.skip -Danimal.sniffer.skip -Dmaven.javadoc.skip -Dfindbugs.skip -Dwarbucks.skip -Dmodernizer.skip -Dimpsort.skip -Dpmd.skip -Dxjc.skip -Dinvoker.skip -DskipDocs -DskipITs -Dmaven.plugin.skip -Dlombok.delombok.skip -Dlicense.skipUpdateLicense"

if [[ -z ${REPO} || -z ${SHA} ]]; then
	echo "Usage bash check_project.sh <repo> <sha> <log-dir>"
	exit 1
fi

PROJECT_DIR=${SCRIPT_DIR}/../projects
LOG_PATH=${LOG_DIR}/statistics/${PROJECT_NAME}
EXTENSIONS_DIR=${SCRIPT_DIR}/../extensions

mkdir -p ${PROJECT_DIR}
mkdir -p ${LOG_DIR}/statistics/${PROJECT_NAME}

function clone() {
	export GIT_TERMINAL_PROMPT=0
	echo "${PROJECT_NAME},0,0,0" > ${LOG_PATH}/status.csv
	
	timeout 180s git clone "https://github.com/${REPO}" ${PROJECT_DIR}/${PROJECT_NAME} &>> ${LOG_PATH}/clone.log
	local status=$?
	if [[ ${status} -ne 0 ]]; then
		exit 1
	fi
	
	pushd ${PROJECT_DIR}/${PROJECT_NAME}
	git checkout ${SHA} &>> ${LOG_PATH}/clone.log
	local status=$?
	if [[ ${status} -ne 0 ]]; then
		exit 1
	fi
	
	if [[ -f .gitmodules ]]; then
		timeout 180s git submodule update --init --recursive &>> ${LOG_PATH}/clone.log
		local status=$?
		if [[ ${status} -ne 0 ]]; then
			exit 1
		fi
	fi
	popd
	
	echo "${PROJECT_NAME},1,0,0" > ${LOG_PATH}/status.csv
}

function get_loc() {
	cloc ${PROJECT_DIR}/${PROJECT_NAME} &> ${LOG_PATH}/cloc.txt
	if [[ ${status} -ne 0 ]]; then
		exit 1
	fi
	
	echo "${PROJECT_NAME},1,1,0" > ${LOG_PATH}/status.csv
}

function run_jacoco() {
	pushd ${PROJECT_DIR}/${PROJECT_NAME}
	for pom in $(find -name "pom.xml"); do
		if [[ -n $(grep -e "maven-surefire-plugin" -e "<argLine>" ${pom}) ]]; then
			# use argLine
			if [[ -z $(grep -e "\${argLine}" -e "@{argLine}" ${pom}) ]]; then
				# not using @{argLine} and ${argLine}
				sed -i 's/<argLine>/<argLine>@{argLine} /g' ${pom}
				echo "Adding @{argLine} to ${pom}" >> ${LOG_PATH}/jacoco-test.log
			fi
		fi
	done

	export RUN_JACOCO_EXTENSION=1
	(time timeout ${TIMEOUT} mvn -Dmaven.ext.class.path="${EXTENSIONS_DIR}/jacoco-extension-1.0.jar" ${SKIP_WITH_JACOCO} test) &>> ${LOG_PATH}/jacoco-test.log
	local status=$?
	if [[ ${status} -ne 0 ]]; then
		if [[ -n $(grep "Could not find or load main class" ${LOG_PATH}/jacoco-test.log) ]]; then
			# REPLACE @{argLine} with ${argLine}
			for pom in $(find -name "pom.xml"); do
				if [[ -n $(grep -e "maven-surefire-plugin" -e "<argLine>" ${pom}) ]]; then
					# use argLine
					sed -i 's/<argLine>@{argLine} /<argLine>${argLine} /g' ${pom}
					echo "Adding ${argLine} to ${pom}" >> ${LOG_PATH}/jacoco-test-again.log
				fi
			done
			
			(time timeout ${TIMEOUT} mvn -Dmaven.ext.class.path="${EXTENSIONS_DIR}/jacoco-extension-1.0.jar" ${SKIP_WITH_JACOCO} test) &>> ${LOG_PATH}/jacoco-test-again.log
			local status=$?
			if [[ ${status} -ne 0 ]]; then
				exit 1
			fi
		else
			exit 1
		fi
	fi
	
	if [[ -z $(grep "Tests run" ${LOG_PATH}/jacoco-test.log) ]]; then
		# NOT RUNNING TEST, TRY AGAIN WITH SUREFIRE:TEST
		(time timeout ${TIMEOUT} mvn -Dmaven.ext.class.path="${EXTENSIONS_DIR}/jacoco-extension-1.0.jar" ${SKIP_WITH_JACOCO} surefire:test) &>> ${LOG_PATH}/jacoco-test-again.log
		local status=$?
		if [[ ${status} -ne 0 ]]; then
			exit 1
		fi
	fi
	
	popd
	
	echo "${PROJECT_NAME},1,1,1" > ${LOG_PATH}/status.csv
}

clone
get_loc
run_jacoco

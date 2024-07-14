#!/bin/bash
# Run profiler with MOP
# Usage: profile_with_mop.sh <repo> <sha> <log-dir> <path-to-profiler>
#
REPO=$1
SHA=$2
LOG_DIR=$3
PROFILER_PATH=$4
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
PROJECT_NAME=$(echo ${REPO} | tr / -)

source ${SCRIPT_DIR}/constants.sh
source ${SCRIPT_DIR}/utils.sh

if [[ -z ${REPO} || -z ${SHA} || ! -f ${PROFILER_PATH} ]]; then
	echo "Usage bash profile_with_mop.sh <repo> <sha> <log-dir> <path-to-profiler>"
	exit 1
fi

PROJECT_DIR=${SCRIPT_DIR}/../projects
REPO_DIR=${SCRIPT_DIR}/../repos
LOG_PATH=${LOG_DIR}/mop-profiling/${PROJECT_NAME}
EXTENSIONS_DIR=${SCRIPT_DIR}/../extensions

mkdir -p ${PROJECT_DIR}
mkdir -p ${REPO_DIR}
mkdir -p ${LOG_DIR}/mop-profiling/${PROJECT_NAME}

if [[ ! ${PROFILER_PATH} =~ ^/.* ]]; then
	PROFILER_PATH=${SCRIPT_DIR}/${PROFILER_PATH}
fi

if [[ ! -f "${MAVEN_HOME}/lib/ext/profiler-extension-1.0.jar" ]]; then
	cp ${SCRIPT_DIR}/../extensions/profiler-extension-1.0.jar ${MAVEN_HOME}/lib/ext/profiler-extension-1.0.jar
fi

function clone() {
	export GIT_TERMINAL_PROMPT=0
	echo "${PROJECT_NAME},0,0,0" > ${LOG_PATH}/status.csv
	
	if [[ -d ${PROJECT_DIR}/${PROJECT_NAME} ]]; then
		# Already have repo, no need to clone...
		echo "${PROJECT_NAME},1,0,0" > ${LOG_PATH}/status.csv
		return 0
	fi
	
	timeout 180s git clone "https://github.com/${REPO}" ${PROJECT_DIR}/${PROJECT_NAME} &>> ${LOG_PATH}/setup.log
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

function run_profiler() {
	mkdir -p /tmp/tsm-rv && chmod -R +w /tmp/tsm-rv && rm -rf /tmp/tsm-rv && mkdir -p /tmp/tsm-rv
	delete_violations

	mvn -Dmaven.repo.local=${REPO_DIR}/${PROJECT_NAME} install:install-file -Dfile=${SCRIPT_DIR}/../mop/agents/no-track-agent.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" &>> ${LOG_PATH}/setup.log

	export PROFILER_PATH=${PROFILER_PATH}
	export COLLECT_TRACES=1
	
	pushd ${PROJECT_DIR}/${PROJECT_NAME}
	(time timeout ${TIMEOUT} mvn -Dmaven.repo.local=${REPO_DIR}/${PROJECT_NAME} -Djava.io.tmpdir=/tmp/tsm-rv -Dmaven.ext.class.path="${EXTENSIONS_DIR}/javamop-extension-1.0.jar" "${SKIP}" test) &> ${LOG_PATH}/test-rv.log
	delete_violations
	
	local status=$?
	if [[ ${status} -ne 0 ]]; then
		exit 1
	fi
	
	echo "${PROJECT_NAME},1,1,0" > ${LOG_PATH}/status.csv
	
	if [[ -n $(find -name "profile.jfr") ]]; then
		move_jfr ${LOG_PATH} profile.jfr
	else
		exit 1
	fi
	popd
	
	echo "${PROJECT_NAME},1,1,1" > ${LOG_PATH}/status.csv
}

export RVMLOGGINGLEVEL=UNIQUE
clone
run_profiler

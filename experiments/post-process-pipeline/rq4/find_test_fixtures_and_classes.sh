#!/bin/bash
#
# Find all the test fixture and classes
# Usage: find_test_fixtures_and_classes.sh <project-dir> <dest-dir>
#
PROJECT_DIR=$1
DEST_DIR=$2
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ -z ${PROJECT_DIR} || ! -d ${PROJECT_DIR} || ! -d ${DEST_DIR} ]]; then
	echo "Usage: bash find_test_fixtures_and_classes.sh <project-dir> <dest-dir>"
	exit 1
fi

if [[ ! -f ${SCRIPT_DIR}/get_test_fixtures.jar ]]; then
	pushd ${SCRIPT_DIR}/find_test_fixtures &> /dev/null
	mvn package
	cp target/find_test_fixtures-1.0-SNAPSHOT-jar-with-dependencies.jar ${SCRIPT_DIR}/get_test_fixtures.jar
	popd &> /dev/null
fi

if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
	PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
fi

if [[ ! ${DEST_DIR} =~ ^/.* ]]; then
	DEST_DIR=${SCRIPT_DIR}/${DEST_DIR}
fi


function get_test_info() {
	rm -f ${DEST_DIR}/tmp.txt ${DEST_DIR}/error.txt
	rm -f ${DEST_DIR}/test-fixtures.txt && touch ${DEST_DIR}/test-fixtures.txt
	rm -f ${DEST_DIR}/test-classes.txt && touch ${DEST_DIR}/test-classes.txt
	rm -rf ${DEST_DIR}/test-methods.txt && touch ${DEST_DIR}/test-methods.txt
	
	local error=false
	
	for file in $(find . -type d -name "test" -prune -exec find {} -name "*.java" \;); do
		if [[ ${file} == *"/src/main/"* || ${file} == *"/target/"*  || ${file} == *"/test/resources/"* || ${file} == *"module-info.java"* || ! -f ${file} ]]; then
			# Ignore files in src directory
			continue
		fi
	
		java -jar ${SCRIPT_DIR}/get_test_fixtures.jar ${file} >> ${DEST_DIR}/tmp.txt
		if [[ $? -ne 0 ]]; then
			echo "${PROJECT_DIR},${file}" >> ${DEST_DIR}/error.txt
			error=true
		fi
	done
	
	if [[ ${error} == "true" ]]; then
		return
	fi
	
	if [[ ! -s ${DEST_DIR}/tmp.txt ]]; then
		return
	fi

	grep "class: " ${DEST_DIR}/tmp.txt | cut -d ' ' -f 2 > ${DEST_DIR}/test-classes.txt
	grep "fixture: " ${DEST_DIR}/tmp.txt | cut -d ' ' -f 2 > ${DEST_DIR}/test-fixtures.txt
	grep "test: " ${DEST_DIR}/tmp.txt | cut -d ' ' -f 2 > ${DEST_DIR}/test-methods.txt

	rm -f ${DEST_DIR}/tmp.txt
}

pushd ${PROJECT_DIR} &> /dev/null
get_test_info
popd &> /dev/null

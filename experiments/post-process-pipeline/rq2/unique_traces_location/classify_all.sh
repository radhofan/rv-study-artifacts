OUTPUT=$1
PROJECT=$2
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ ! -d ${OUTPUT} ]]; then
    echo "Cannot find output directory"
    exit 1
fi

if [[ ! -d ${OUTPUT}/${PROJECT} ]]; then
    echo "Cannot find project"
    exit 1
fi

if [[ ! ${OUTPUT} =~ ^/.* ]]; then
    OUTPUT=${SCRIPT_DIR}/${OUTPUT}
fi

if [[ ! ${PROJECTS_LIST} =~ ^/.* ]]; then
    PROJECTS_LIST=${SCRIPT_DIR}/${PROJECTS_LIST}
fi

project=${PROJECT}
mkdir -p ${SCRIPT_DIR}/unique-traces-classification

pushd ${OUTPUT} &> /dev/null
if [[ ! -d ${OUTPUT}/${project}/projects/${project} ]]; then
    echo "${project},not found" > ${SCRIPT_DIR}/unique-traces-classification/${project}.csv
    continue
fi

if [[ ! -d ${OUTPUT}/${project}/projects/${project}/.all-traces/ || ! -f ${OUTPUT}/${project}/projects/${project}/.all-traces/unique-traces.txt || ! -f ${OUTPUT}/${project}/projects/${project}/.all-traces/locations.txt ]]; then
    echo "${project},no traces" > ${SCRIPT_DIR}/unique-traces-classification/${project}.csv
    continue
fi

if [[ ! -f ${OUTPUT}/${project}/logs/packages.txt ]]; then
    pushd ${OUTPUT}/${project}/projects/${project} &> /dev/null
    grep --include "*.java" -rhE "package [a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)*;" . | grep "^package" | cut -d ' ' -f 2 | sed 's/;.*//g' | sort -u >> ${OUTPUT}/${project}/logs/packages.txt
    popd &> /dev/null
fi

result=$(python3 ${SCRIPT_DIR}/classify.py ${OUTPUT}/${project} ${project})
echo "${project},${result}"
echo "${project},${result}" > ${SCRIPT_DIR}/unique-traces-classification/${project}.csv

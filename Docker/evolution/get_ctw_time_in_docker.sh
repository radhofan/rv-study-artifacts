#!/bin/bash
#
# Run get_ctw_time.sh in Docker
# Before running this script, run `docker login`
# Usage: get_ctw_time_in_docker.sh <projects-list> <sha-dir> <output-dir> [timeout=86400s]
# sha directory must contains file: <project-name>.txt
#
PROJECTS_LIST=$1
SHA_DIR=$2
OUTPUT_DIR=$3
TIMEOUT=$4

function check_input() {
  if [[ ! -d ${SHA_DIR} || ! -f ${PROJECTS_LIST} || -z ${OUTPUT_DIR} ]]; then
    echo "Usage: get_ctw_time_in_docker.sh <projects-list> <sha-dir> <output-dir> [timeout=86400s]"
    exit 1
  fi

  if [[ ! ${SHA_DIR} =~ ^/.* ]]; then
    SHA_DIR=${SCRIPT_DIR}/${SHA_DIR}
  fi

  if [[ ! ${OUTPUT_DIR} =~ ^/.* ]]; then
    OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
  fi

  OUTPUT_DIR=${OUTPUT_DIR}/get_ctw_time

  mkdir -p ${OUTPUT_DIR}

  if [[ ! -s ${PROJECTS_LIST} ]]; then
    echo "${PROJECTS_LIST} is empty..."
    exit 0
  fi

  if [[ -z $(grep "###" ${PROJECTS_LIST}) ]]; then
    echo "You must end your projects-list file with ###"
    exit 1
  fi

  if [[ -z ${TIMEOUT} ]]; then
    TIMEOUT=86400s
  fi
}


function run_project() {
  local repo=$1
  local project_name=$(echo ${repo} | tr / -)

  if [[ ! -f ${SHA_DIR}/${project_name}.txt ]]; then
    echo "Skip ${project_name} because its sha file is not in sha-directory"
    return
  fi

  echo "Running ${project_name}"
  mkdir -p ${OUTPUT_DIR}/${project_name}

  local id=$(docker run -itd --name ${project_name} rvpaper:latest)
  docker exec -w /home/tsm/tsm-rv ${id} git pull

  docker cp ${SHA_DIR}/${project_name}.txt ${id}:/home/tsm/sha.txt

  timeout ${TIMEOUT} docker exec -w /home/tsm/tsm-rv -e M2_HOME=/home/tsm/apache-maven -e MAVEN_HOME=/home/tsm/apache-maven -e CLASSPATH=/home/tsm/aspectj-1.9.7/lib/aspectjtools.jar:/home/tsm/aspectj-1.9.7/lib/aspectjrt.jar:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar: -e PATH=/home/tsm/apache-maven/bin:/usr/lib/jvm/java-8-openjdk/bin:/home/tsm/aspectj-1.9.7/bin:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin ${id} timeout ${TIMEOUT} bash experiments/evolution/get_ctw_time.sh /home/tsm/sha.txt ${repo} /home/tsm/output /home/tsm/logs /home/tsm/aspectj-1.9.7 &> ${OUTPUT_DIR}/${project_name}/docker.log

  docker cp ${id}:/home/tsm/logs/${project_name} ${OUTPUT_DIR}/${project_name}/logs
  docker cp ${id}:/home/tsm/output ${OUTPUT_DIR}/${project_name}/output

  docker rm -f ${id}
}

function run_all() {
  while true; do
    if [[ ! -s ${PROJECTS_LIST} ]]; then
      echo "${PROJECTS_LIST} is empty..."
      exit 0
    fi

    local project=$(head -n 1 ${PROJECTS_LIST})
    if [[ ${project} == "###" ]]; then
      echo "Finished running all projects"
      exit 0
    fi

    if [[ -z $(grep "###" ${PROJECTS_LIST}) ]]; then
      echo "You must end your projects-list file with ###"
      exit 1
    fi

    sed -i 1d ${PROJECTS_LIST}
    echo $project >> ${PROJECTS_LIST}
    run_project ${project}
  done
}

check_input
run_all

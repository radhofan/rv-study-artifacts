#!/bin/bash
#
# Instrument project in Docker
# Before running this script, run `docker login` first.
# Usage: ./ctw_in_docker.sh <projects-list> <output-dir> [timeout=10800] [tsm-rv-branch] [ctw-threads]
#
PROJECTS_LIST=$1
OUTPUT_DIR=$2
TIMEOUT=$3
BRANCH=$4
THREADS=$5
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

function check_input() {
  if [[ ! -f ${PROJECTS_LIST} || -z ${OUTPUT_DIR} ]]; then
    echo "Usage: ctw_in_docker.sh <projects-list> <output-dir>"
    exit 1
  fi
  
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
    TIMEOUT=10800s
  fi
  
  if [[ -z ${THREADS} ]]; then
    THREADS=20
  fi
}

function run_project() {
  local project=$1
  local repo=$(echo ${project} | cut -d ',' -f 1)
  local sha=$(echo ${project} | cut -d ',' -f 2)
  local project_name=$(echo ${repo} | tr / -)
  
  echo "Running ${project}"
  mkdir -p ${OUTPUT_DIR}/${project_name}
  
  local id=$(docker run -itd --name ${project_name} rvpaper:latest)
  docker exec -w /home/tsm/tsm-rv ${id} git pull
  
  if [[ -n ${BRANCH} ]]; then
    docker exec -w /home/tsm/tsm-rv ${id} git checkout ${BRANCH}
  fi
  
  docker exec -w /home/tsm/tsm-rv ${id} sed -i "s/TIMEOUT=.*/TIMEOUT=${TIMEOUT}/" experiments/constants.sh
  docker exec -w /home/tsm/tsm-rv ${id} sed -i "s/INSTRUMENTATION_THREADS=.*/INSTRUMENTATION_THREADS=${THREADS}/" experiments/constants.sh

  timeout ${TIMEOUT} docker exec -w /home/tsm/tsm-rv -e M2_HOME=/home/tsm/apache-maven -e MAVEN_HOME=/home/tsm/apache-maven -e CLASSPATH=/home/tsm/aspectj-1.9.7/lib/aspectjtools.jar:/home/tsm/aspectj-1.9.7/lib/aspectjrt.jar:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar: -e PATH=/home/tsm/apache-maven/bin:/usr/lib/jvm/java-8-openjdk/bin:/home/tsm/aspectj-1.9.7/bin:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin ${id} timeout ${TIMEOUT} bash run_compile_time_weaving.sh ${repo} ${sha} /home/tsm/logs /home/tsm/aspectj-1.9.7 &> ${OUTPUT_DIR}/${project_name}/docker.log

  mkdir -p ${OUTPUT_DIR}/${project_name}/projects-orig
  mkdir -p ${OUTPUT_DIR}/${project_name}/repos-orig
  docker cp ${id}:/home/tsm/logs ${OUTPUT_DIR}/${project_name}
  docker cp ${id}:/home/tsm/tsm-rv/projects/ ${OUTPUT_DIR}/${project_name}/projects-orig
  docker cp ${id}:/home/tsm/tsm-rv/compile-time-weaving/projects/ ${OUTPUT_DIR}/${project_name}
  docker cp ${id}:/home/tsm/tsm-rv/repos/ ${OUTPUT_DIR}/${project_name}/repos-orig
  docker cp ${id}:/home/tsm/tsm-rv/compile-time-weaving/repos/ ${OUTPUT_DIR}/${project_name}
  
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

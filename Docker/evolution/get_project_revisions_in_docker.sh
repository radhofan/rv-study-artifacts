#!/bin/bash
#
# Run get_project_revisions.sh in Docker
# Before running this script, run `docker login` first.
# Usage: get_project_revisions_in_docker.sh <project> <revisions> <output-dir> [timeout=86400s]
#
PROJECT=$1
REVISIONS=$2
OUTPUT_DIR=$3
TIMEOUT=$4

function check_input() {
  if [[ -z ${PROJECT} || -z ${OUTPUT_DIR} ]]; then
    echo "Usage: get_project_revisions_in_docker.sh <project> <revisions> <output-dir> [timeout=86400s]"
    exit 1
  fi
  
  mkdir -p ${OUTPUT_DIR}
  
  if [[ -z ${TIMEOUT} ]]; then
    TIMEOUT=86400s
  fi
}


function run_project() {
  local repo=$(echo ${PROJECT} | cut -d ',' -f 1)
  local sha=$(echo ${PROJECT} | cut -d ',' -f 2)
  local project_name=$(echo ${repo} | tr / -)
  
  echo "Running ${project}"
  mkdir -p ${OUTPUT_DIR}/${project_name}
  
  local id=$(docker run -itd --name ${project_name} rvpaper:latest)
  docker exec -w /home/tsm/tsm-rv ${id} git pull
  
  docker exec -w /home/tsm/tsm-rv ${id} mv mop/agents/violations-ajc/no-track-agent.jar mop/agents/no-track-agent.jar
  
  timeout ${TIMEOUT} docker exec -w /home/tsm/tsm-rv -e M2_HOME=/home/tsm/apache-maven -e MAVEN_HOME=/home/tsm/apache-maven -e CLASSPATH=/home/tsm/aspectj-1.9.7/lib/aspectjtools.jar:/home/tsm/aspectj-1.9.7/lib/aspectjrt.jar:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar: -e PATH=/home/tsm/apache-maven/bin:/usr/lib/jvm/java-8-openjdk/bin:/home/tsm/aspectj-1.9.7/bin:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin ${id} timeout ${TIMEOUT} bash experiments/evolution/get_project_revisions.sh ${REVISIONS} ${repo} ${sha} /home/tsm/output /home/tsm/logs &> ${OUTPUT_DIR}/${project_name}/docker.log
  
  docker cp ${id}:/home/tsm/logs/${project_name} ${OUTPUT_DIR}/${project_name}/logs
  docker cp ${id}:/home/tsm/output/${project_name} ${OUTPUT_DIR}/${project_name}/output
  
  docker rm -f ${id}
}

check_input
run_project

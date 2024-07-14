#!/bin/bash
#
# Run get_test_and_mop_time.sh in Docker
# Before running this script, run `docker login` and `get_project_revisions_in_docker.sh` first
# Usage: get_test_and_mop_time_in_docker.sh <revision-output> <projects-list> <output-dir> [timeout=86400s]
#
REVISION_OUTPUT=$1
PROJECTS_LIST=$2
OUTPUT_DIR=$3
TIMEOUT=$4

function check_input() {
  if [[ ! -d ${REVISION_OUTPUT} || ! -f ${PROJECTS_LIST} || -z ${OUTPUT_DIR} ]]; then
    echo "Usage: get_test_and_mop_time_in_docker.sh <revision-output> <projects-list> <output-dir> [timeout=86400s]"
    exit 1
  fi
  
  if [[ ! ${REVISION_OUTPUT} =~ ^/.* ]]; then
    REVISION_OUTPUT=${SCRIPT_DIR}/${REVISION_OUTPUT}
  fi

  if [[ ! ${OUTPUT_DIR} =~ ^/.* ]]; then
    OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
  fi
  
  OUTPUT_DIR=${OUTPUT_DIR}/get_test_and_mop_time
  
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

  echo "Running ${project_name}"
  mkdir -p ${OUTPUT_DIR}/${project_name}
  
  local id=$(docker run -itd --name ${project_name} rvpaper:latest)
  docker exec -w /home/tsm/tsm-rv ${id} git pull
  
  docker exec -w /home/tsm/tsm-rv ${id} mv mop/agents/violations-ajc/no-track-agent.jar mop/agents/no-track-agent.jar
  
  docker cp ${REVISION_OUTPUT}/${project_name}/logs/commits-check.txt ${id}:/home/tsm/commits-check.txt
  docker cp ${REVISION_OUTPUT}/${project_name}/output ${id}:/home/tsm/output
  docker exec -u 0 ${id} sudo chown -R tsm:tsm /home/tsm/output
  
  timeout ${TIMEOUT} docker exec -w /home/tsm/tsm-rv -e M2_HOME=/home/tsm/apache-maven -e MAVEN_HOME=/home/tsm/apache-maven -e CLASSPATH=/home/tsm/aspectj-1.9.7/lib/aspectjtools.jar:/home/tsm/aspectj-1.9.7/lib/aspectjrt.jar:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar: -e PATH=/home/tsm/apache-maven/bin:/usr/lib/jvm/java-8-openjdk/bin:/home/tsm/aspectj-1.9.7/bin:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin ${id} timeout ${TIMEOUT} bash experiments/evolution/get_test_and_mop_time.sh /home/tsm/commits-check.txt ${project_name} /home/tsm/output/project /home/tsm/output/repo /home/tsm/logs &> ${OUTPUT_DIR}/${project_name}/docker.log
  
  docker cp ${id}:/home/tsm/logs/${project_name} ${OUTPUT_DIR}/${project_name}/logs

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

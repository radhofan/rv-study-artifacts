#!/bin/bash
#
# Run experiments in Docker
# Before running this script, run `docker login` first.
# Usage: ./experiments_in_docker.sh -p <projects-list> -o <output-dir> [-c <check-project-timeout=3600s> -a <timeout=10800s> -b <tsm-rv-branch> -s <steps> -v <violation=ajc/stack> -d <single-pass> -t <ctw-thread>]
#

while getopts :p:o:c:a:b:s:v:d:t: opts; do
  case "${opts}" in
    p ) PROJECTS_LIST="${OPTARG}" ;;
    o ) OUTPUT_DIR="${OPTARG}" ;;
    c ) CHECK_PROJECT_TIMEOUT="${OPTARG}" ;;
    a ) TIMEOUT="${OPTARG}" ;;
    b ) BRANCH="${OPTARG}" ;;
    s ) STEPS="${OPTARG}" ;;
    v ) VIOLATION="${OPTARG}" ;;
    d ) SINGLE_PASS="${OPTARG}" ;;
    t ) CTW_THREADS="${OPTARG}" ;;
  esac
done
shift $((${OPTIND} - 1))

SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

function check_input() {
  if [[ ! -f ${PROJECTS_LIST} || -z ${OUTPUT_DIR} ]]; then
    echo "Usage: bash experiments_in_docker.sh -p <projects-list> -o <output-dir> [-c <check-project-timeout=3600s> -a <timeout=10800s> -b <tsm-rv-branch> -s <steps> <violation=ajc/stack> -p <single-pass>]"
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
}

function run_project() {
  local project=$1
  local repo=$(echo ${project} | cut -d ',' -f 1)
  local sha=$(echo ${project} | cut -d ',' -f 2)
  local project_name=$(echo ${repo} | tr / -)
  
  echo "Running ${project}"
  mkdir -p ${OUTPUT_DIR}/${project_name}
  
  local image="rvpaper:latest"
  if [[ $(uname -i) == "aarch64" ]]; then
    echo "WARNING: Using ARM version... Profiler will not work."
    image="rvpaper:latest-arm"
  fi

  local id=$(docker run -itd --name ${project_name} ${image})
  docker exec -w /home/tsm/tsm-rv ${id} git pull
  
  if [[ -n ${BRANCH} ]]; then
    docker exec -w /home/tsm/tsm-rv ${id} git checkout ${BRANCH}
  fi
  
  docker exec -w /home/tsm/tsm-rv ${id} sed -i "s/TIMEOUT=.*/TIMEOUT=${TIMEOUT}/" experiments/constants.sh
  
  if [[ -n ${CHECK_PROJECT_TIMEOUT} ]]; then
    docker exec -w /home/tsm/tsm-rv ${id} sed -i "s/CHECK_PROJECT_TIMEOUT=.*/CHECK_PROJECT_TIMEOUT=${CHECK_PROJECT_TIMEOUT}/" experiments/constants.sh
  fi
  
  if [[ ${SINGLE_PASS} == "true" ]]; then
    docker exec -w /home/tsm/tsm-rv ${id} sed -i "s/SINGLE_PASS=false/SINGLE_PASS=true/" experiments/constants.sh
  fi
  
  if [[ -n ${CTW_THREADS} ]]; then
    docker exec -w /home/tsm/tsm-rv ${id} sed -i "s/INSTRUMENTATION_THREADS=.*/INSTRUMENTATION_THREADS=${CTW_THREADS}/" experiments/constants.sh
  fi
  
  if [[ ${VIOLATION} == "ajc" ]]; then
    docker exec -w /home/tsm/tsm-rv ${id} mv mop/agents/violations-ajc/no-track-agent.jar mop/agents/no-track-agent.jar
    docker exec -w /home/tsm/tsm-rv ${id} mv mop/agents/violations-ajc/stats-agent.jar mop/agents/stats-agent.jar
  fi

  timeout ${TIMEOUT} docker exec -w /home/tsm/tsm-rv -e M2_HOME=/home/tsm/apache-maven -e MAVEN_HOME=/home/tsm/apache-maven -e CLASSPATH=/home/tsm/aspectj-1.9.7/lib/aspectjtools.jar:/home/tsm/aspectj-1.9.7/lib/aspectjrt.jar:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar: -e PATH=/home/tsm/apache-maven/bin:/usr/lib/jvm/java-8-openjdk/bin:/home/tsm/aspectj-1.9.7/bin:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin ${id} timeout ${TIMEOUT} bash run_all_experiments.sh ${repo} ${sha} /home/tsm/logs /home/tsm/aspectj-1.9.7 /home/tsm/async-profiler-2.9-linux-x64/build/libasyncProfiler.so ${STEPS} &> ${OUTPUT_DIR}/${project_name}/docker.log

  mkdir -p ${OUTPUT_DIR}/${project_name}/projects-orig
  mkdir -p ${OUTPUT_DIR}/${project_name}/repos-orig
  docker cp ${id}:/home/tsm/logs ${OUTPUT_DIR}/${project_name}
  docker cp ${id}:/home/tsm/tsm-rv/compile-time-weaving/experiments/aspects/ ${OUTPUT_DIR}/${project_name}
  docker cp ${id}:/home/tsm/tsm-rv/projects/ ${OUTPUT_DIR}/${project_name}/projects-orig
  docker cp ${id}:/home/tsm/tsm-rv/compile-time-weaving/projects/ ${OUTPUT_DIR}/${project_name}
  docker cp ${id}:/home/tsm/tsm-rv/compile-time-weaving/projects-with-mop/ ${OUTPUT_DIR}/${project_name}
  docker cp ${id}:/home/tsm/tsm-rv/compile-time-weaving/projects-without-hot-time/ ${OUTPUT_DIR}/${project_name}
  docker cp ${id}:/home/tsm/tsm-rv/compile-time-weaving/projects-without-mop/ ${OUTPUT_DIR}/${project_name}
  docker cp ${id}:/home/tsm/tsm-rv/repos/ ${OUTPUT_DIR}/${project_name}/repos-orig
  docker cp ${id}:/home/tsm/tsm-rv/compile-time-weaving/repos/ ${OUTPUT_DIR}/${project_name}
  docker cp ${id}:/home/tsm/tsm-rv/compile-time-weaving/repos-with-mop/ ${OUTPUT_DIR}/${project_name}
  docker cp ${id}:/home/tsm/tsm-rv/compile-time-weaving/repos-without-hot-time/ ${OUTPUT_DIR}/${project_name}
  docker cp ${id}:/home/tsm/tsm-rv/compile-time-weaving/repos-without-mop/ ${OUTPUT_DIR}/${project_name}
  
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

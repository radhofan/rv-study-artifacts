#!/bin/bash
#
# Run projects with JavaMOP using compile time weaving
# Usage: run.sh <projects-list> <log-dir> <props-dir> <aspectj-dir> [option: instrument/monitor]
# projects-list: a file contains projects' name and sha (project_name,sha)
# log-dir: path to log directory
# props-dir: path to mop files
# aspectj-dir: path to AspectJ's directory
#
PROJECTS_LIST=$1
LOG_DIR=$2
PROPS_DIR=$3
ASPECTJ_DIR=$4
INSTRUMENT_OPTION=$5
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

LOG_PREFIX="[TSM-CTW]"

function show_arguments() {
  echo "PROJECTS_LIST: ${PROJECTS_LIST}"
  echo "LOG_DIR: ${LOG_DIR}"
  echo "PROPS_DIR: ${PROPS_DIR}"
  echo "ASPECTJ_DIR: ${ASPECTJ_DIR}"
}

function check_inputs() {
  show_arguments

  if [[ ! -f "${PROJECTS_LIST}" || -z "${LOG_DIR}" || ! -d "${PROPS_DIR}" ]]; then
    echo "Usage: ./run.sh <projects-list> <log-dir> <props-dir> <aspectj-dir> [option: instrument/monitor]"
    echo "projects-list: a file contains projects' name and sha (project_name,sha)"
    echo "log-dir: path to log directory"
    echo "props-dir: path to mop files"
    echo "aspectj-dir: path to AspectJ's directory"
    exit 1
  fi
  
  if [[ ! -f "${ASPECTJ_DIR}/lib/aspectjrt.jar" ]]; then
    echo "Cannot find AspectJ"
    exit 2
  fi
  
  mkdir -p "${SCRIPT_DIR}/projects/"
}

function convert_to_absolute_paths() {
  if [[ ! ${PROJECTS_LIST} =~ ^/.* ]]; then
    PROJECTS_LIST=${SCRIPT_DIR}/${PROJECTS_LIST}
  fi
  
  if [[ ! ${LOG_DIR} =~ ^/.* ]]; then
    LOG_DIR=${SCRIPT_DIR}/${LOG_DIR}
  fi
  
  if [[ ! ${PROPS_DIR} =~ ^/.* ]]; then
    PROPS_DIR=${SCRIPT_DIR}/${PROPS_DIR}
  fi
  
  if [[ ! ${ASPECTJ_DIR} =~ ^/.* ]]; then
    ASPECTJ_DIR=${SCRIPT_DIR}/${ASPECTJ_DIR}
  fi
}

function setup() {
  if [[ ! -f "${SCRIPT_DIR}/../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar" ]]; then
    echo "Missing rv-monitor-rt.jar"
    build_javamop
  fi
  
  if [[ ! -f "${MAVEN_HOME}/lib/ext/ctw-extension-1.0.jar" ]]; then
    echo "Missing compile time weaving maven extension..."
    build_extension
  fi
  
  if [[ ! -f "${SCRIPT_DIR}/myaspects.jar" ]]; then
    echo "Missing aspects jar"
    build_aspects_jar
  fi
}

function build_javamop() {
  mkdir -p "${SCRIPT_DIR}/../scripts/projects"

  pushd "${SCRIPT_DIR}/../scripts/projects"
  
  pushd tracemop
  bash scripts/install-javaparser.sh
  mvn install -DskipTests
  popd
  popd
}

function build_extension() {
  mkdir -p ${SCRIPT_DIR}/../extensions

  if [[ -f "${SCRIPT_DIR}/../extensions/ctw-extension-1.0.jar" ]]; then
    cp "${SCRIPT_DIR}/../extensions/ctw-extension-1.0.jar" "${MAVEN_HOME}/lib/ext/ctw-extension-1.0.jar"
  else
    pushd ${SCRIPT_DIR}/../javamop-maven-extension
    mvn package
    cp "${SCRIPT_DIR}/../javamop-maven-extension/ctw-extension/target/ctw-extension-1.0.jar"  "${SCRIPT_DIR}/../extensions/ctw-extension-1.0.jar"
    cp "${SCRIPT_DIR}/../extensions/ctw-extension-1.0.jar" "${MAVEN_HOME}/lib/ext/ctw-extension-1.0.jar"
  fi
}

function build_aspects_jar() {
  local orig_classpath=${CLASSPATH}
  local orig_path=${PATH}
  local script_project_dir="${SCRIPT_DIR}/../scripts/projects"

  export PATH=${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/bin:${script_project_dir}/tracemop/javamop/target/release/javamop/javamop/bin:${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${PATH}
  export CLASSPATH=${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${CLASSPATH}

  local tmp_props=/tmp/tsm-rv-props
  rm -rf /tmp/tsm-rv-props
  cp -r ${PROPS_DIR} ${tmp_props}

  # Generate .aj files and MultiSpec_1RuntimeMonitor.java
  cp ${SCRIPT_DIR}/../mop/BaseAspect_new.aj ${tmp_props}/BaseAspect.aj
  
  for spec in ${tmp_props}/*.mop; do
    javamop -baseaspect ${tmp_props}/BaseAspect.aj -emop ${spec} -internalBehaviorObserving # Generate .aj
  done
  
  rm -rf ${tmp_props}/classes/mop; mkdir -p ${tmp_props}/classes/mop
  rv-monitor -merge -d ${tmp_props}/classes/mop/ ${tmp_props}/*.rvm -locationFromAjc # Generate MultiSpec_1RuntimeMonitor.java

  cp ${tmp_props}/classes/mop/MultiSpec_1RuntimeMonitor.java ${tmp_props}/MultiSpec_1RuntimeMonitor.java
  rm -rf ${tmp_props}/classes/ ${tmp_props}/*.mop ${tmp_props}/*.rvm  # Only keep .aj and MultiSpec_1RuntimeMonitor.java

  pushd ${SCRIPT_DIR}
  ajc -Xlint:ignore -1.8 -encoding UTF-8 -showWeaveInfo -verbose -outjar myaspects.jar ${tmp_props}/*
  popd
  
  rm -rf ${tmp_props}
  
  export CLASSPATH=${orig_classpath}
  export PATH=${orig_path}
}

function run_all() {
  while read -r project; do
    local project_name=$(echo ${project} | cut -d ',' -f 1)
    local project_sha=$(echo ${project} | cut -d ',' -f 2)
    local project=$(echo ${project_name} | tr / -)
    
    echo "Cloning ${project_name}"
    
    if [[ ! -d "${SCRIPT_DIR}/projects/${project}" ]]; then
      # Clone project to ${SCRIPT_DIR}/projects/${project}
      if [[ -d "${SCRIPT_DIR}/../scripts/projects/${project}" ]]; then
        git clone "${SCRIPT_DIR}/../scripts/projects/${project}" "${SCRIPT_DIR}/projects/${project}"
      else
        git clone "https://github.com/${project_name}" "${SCRIPT_DIR}/projects/${project}"
        if [[ $? != 0 ]]; then
          echo "Failed to clone ${project}"
          continue
        fi
      fi
      
      # Checkout the commit
      pushd "${SCRIPT_DIR}/projects/${project}"
      git checkout ${project_sha}
      if [[ -f .gitmodules ]]; then
        git submodule update --init --recursive
      fi
      popd
    fi
    
    local project_dir="${SCRIPT_DIR}/projects/${project}" 
    local repo_dir="${SCRIPT_DIR}/repos"
    local myaspects="${SCRIPT_DIR}/myaspects.jar"
    local aspectjrt="${ASPECTJ_DIR}/lib/aspectjrt.jar"
    local monitorrt="${SCRIPT_DIR}/../scripts/projects/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar"
    
    echo "Instrumenting ${project_name}"
    bash ${SCRIPT_DIR}/run_project.sh ${project_dir} ${project} ${repo_dir} ${LOG_DIR} ${myaspects} ${aspectjrt} ${monitorrt} ${INSTRUMENT_OPTION}
  done < ${PROJECTS_LIST}
  
  echo "Finished running all with status $?"
}

check_inputs
convert_to_absolute_paths
setup
run_all

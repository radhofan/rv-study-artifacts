#!/bin/bash

SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
TSM_DIR="${SCRIPT_DIR}/tsm-rv"
PROJECT_DIR="${TSM_DIR}/scripts/projects"

function clone_repository() {
  echo "Cloning tsm-rv repository"
  pushd ${SCRIPT_DIR}
  git clone https://github.com/papersubmission321/rv tsm-rv
  
  mkdir -p ${TSM_DIR}/extensions
  mkdir -p ${TSM_DIR}/mop/agents
  mkdir -p ${PROJECT_DIR}
  popd
}

function install_javamop() {
  echo "Installing JavaMOP"
  pushd ${PROJECT_DIR}
  pushd tracemop
  bash scripts/install-javaparser.sh
  mvn install -DskipTests
  popd
  popd
}

function build_agents() {
  export PATH=${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/bin:${PROJECT_DIR}/tracemop/javamop/target/release/javamop/javamop/bin:${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${PATH}
  export CLASSPATH=${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${CLASSPATH}
  
  pushd ${TSM_DIR}/scripts
  echo -e "db=memory\ndumpDB=false" > .trace-db.config
  cp ${TSM_DIR}/scripts/make-agent.sh ${TSM_DIR}/mop
  cp -r ${TSM_DIR}/mop/props ${TSM_DIR}/mop/props.tmp
  
  mkdir -p ${TSM_DIR}/mop/agents/violations-ajc
  
  ### VIOLATION LOCATIONS FROM STACK:
  
  if [[ ! -f ${TSM_DIR}/mop/agents/track-agent.jar ]]; then
    # track, no stats
    bash ${TSM_DIR}/mop/make-agent.sh ${TSM_DIR}/mop/props.tmp ${TSM_DIR}/mop/agents quiet track ${TSM_DIR} track-agent ${TSM_DIR}/scripts/.trace-db.config no-stats false
  fi
  
  if [[ ! -f ${TSM_DIR}/mop/agents/no-track-agent.jar ]]; then
    # no track, no stats
    bash ${TSM_DIR}/mop/make-agent.sh ${TSM_DIR}/mop/props.tmp ${TSM_DIR}/mop/agents quiet no-track ${TSM_DIR} no-track-agent ${TSM_DIR}/scripts/.trace-db.config no-stats false
  fi
  
  if [[ ! -f ${TSM_DIR}/mop/agents/track-stats-agent.jar ]]; then
    # track, stats
    bash ${TSM_DIR}/mop/make-agent.sh ${TSM_DIR}/mop/props.tmp ${TSM_DIR}/mop/agents quiet track ${TSM_DIR} track-stats-agent ${TSM_DIR}/scripts/.trace-db.config stats false
  fi
  
  if [[ ! -f ${TSM_DIR}/mop/agents/stats-agent.jar ]]; then
    # no track, stats
    bash ${TSM_DIR}/mop/make-agent.sh ${TSM_DIR}/mop/props.tmp ${TSM_DIR}/mop/agents quiet no-track ${TSM_DIR} stats-agent ${TSM_DIR}/scripts/.trace-db.config stats false
  fi
  
  ### VIOLATION LOCATIONS FROM AJC
  
  if [[ ! -f ${TSM_DIR}/mop/agents/violations-ajc/track-agent.jar ]]; then
    # track, no stats
    bash ${TSM_DIR}/mop/make-agent.sh ${TSM_DIR}/mop/props.tmp ${TSM_DIR}/mop/agents/violations-ajc quiet track ${TSM_DIR} track-agent ${TSM_DIR}/scripts/.trace-db.config
  fi
  
  if [[ ! -f ${TSM_DIR}/mop/agents/violations-ajc/no-track-agent.jar ]]; then
    # no track, no stats
    bash ${TSM_DIR}/mop/make-agent.sh ${TSM_DIR}/mop/props.tmp ${TSM_DIR}/mop/agents/violations-ajc quiet no-track ${TSM_DIR} no-track-agent ${TSM_DIR}/scripts/.trace-db.config
  fi
  
  if [[ ! -f ${TSM_DIR}/mop/agents/violations-ajc/track-stats-agent.jar ]]; then
    # track, stats
    bash ${TSM_DIR}/mop/make-agent.sh ${TSM_DIR}/mop/props.tmp ${TSM_DIR}/mop/agents/violations-ajc quiet track ${TSM_DIR} track-stats-agent ${TSM_DIR}/scripts/.trace-db.config stats
  fi
  
  if [[ ! -f ${TSM_DIR}/mop/agents/violations-ajc/stats-agent.jar ]]; then
    # no track, stats
    bash ${TSM_DIR}/mop/make-agent.sh ${TSM_DIR}/mop/props.tmp ${TSM_DIR}/mop/agents/violations-ajc quiet no-track ${TSM_DIR} stats-agent ${TSM_DIR}/scripts/.trace-db.config stats
  fi
  
  rm -rf ${TSM_DIR}/mop/props.tmp
}

function install_listener() {
  echo "Installing junit-test-listener"
  pushd ${TSM_DIR}/junit-test-listener
  mvn clean install
  popd
}

function build_extensions() {
  echo "Installing maven extensions"
  if [[ ! -f ${TSM_DIR}/extensions/javamop-extension-1.0.jar || ! -f ${TSM_DIR}/extensions/junit-extension-1.0.jar || ! -f ${TSM_DIR}/extensions/ctw-extension-1.0.jar || ! -f ${TSM_DIR}/extensions/profiler-extension-1.0.jar || ! -f ${TSM_DIR}/extensions/builddir-extension-1.0.jar || ! -f ${TSM_DIR}/extensions/measure-extension-1.0.jar || ! -f ${TSM_DIR}/extensions/jacoco-extension-1.0.jar ]]; then
    pushd ${SCRIPT_DIR}/tsm-rv/javamop-maven-extension
    mvn package
    mv javamop-extension/target/javamop-extension-*.jar ${TSM_DIR}/extensions
    mv junit-extension/target/junit-extension-*.jar ${TSM_DIR}/extensions
    mv ctw-extension/target/ctw-extension-*.jar ${TSM_DIR}/extensions
    mv profiler-extension/target/profiler-extension-*.jar ${TSM_DIR}/extensions
    mv builddir-extension/target/builddir-extension-*.jar ${TSM_DIR}/extensions
    mv measure-extension/target/measure-extension-*.jar ${TSM_DIR}/extensions
    mv jacoco-extension/target/jacoco-extension-*.jar ${TSM_DIR}/extensions
    popd
  fi
}

function build_aspects_jar() {
  local orig_classpath=${CLASSPATH}
  local orig_path=${PATH}
  local script_project_dir="${TSM_DIR}/scripts/projects"
  
  export PATH=${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/bin:${script_project_dir}/tracemop/javamop/target/release/javamop/javamop/bin:${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${PATH}
  export CLASSPATH=${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${script_project_dir}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${CLASSPATH}
  
  local tmp_props=/tmp/tsm-rv-props
  rm -rf /tmp/tsm-rv-props
  cp -r ${TSM_DIR}/mop/props ${tmp_props}
  
  # Generate .aj files and MultiSpec_1RuntimeMonitor.java
  cp ${TSM_DIR}/mop/BaseAspect_new.aj ${tmp_props}/BaseAspect.aj
  
  for spec in ${tmp_props}/*.mop; do
    javamop -baseaspect ${tmp_props}/BaseAspect.aj -emop ${spec} -internalBehaviorObserving # Generate .aj
  done
  
  rm -rf ${tmp_props}/classes/mop; mkdir -p ${tmp_props}/classes/mop
  rv-monitor -merge -d ${tmp_props}/classes/mop/ ${tmp_props}/*.rvm -locationFromAjc # Generate MultiSpec_1RuntimeMonitor.java
  
  cp ${tmp_props}/classes/mop/MultiSpec_1RuntimeMonitor.java ${tmp_props}/MultiSpec_1RuntimeMonitor.java
  rm -rf ${tmp_props}/classes/ ${tmp_props}/*.mop ${tmp_props}/*.rvm  # Only keep .aj and MultiSpec_1RuntimeMonitor.java
  
  pushd ${TSM_DIR}/compile-time-weaving
  ajc -Xlint:ignore -1.8 -encoding UTF-8 -showWeaveInfo -verbose -outjar myaspects.jar ${tmp_props}/*
  popd
  
  rm -rf ${tmp_props}
  
  export CLASSPATH=${orig_classpath}
  export PATH=${orig_path}
}

function setup() {
  clone_repository
  install_javamop
  build_agents
  install_listener
  build_extensions
  build_aspects_jar
}

if [[ $1 == "force" ]]; then
  rm -rf ${TSM_DIR}/extensions
  rm -rf ${TSM_DIR}/mop/agents
fi
setup

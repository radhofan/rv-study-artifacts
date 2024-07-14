#!/bin/bash
#
REPO_PATH=$1
MY_ASPECTS_JAR=$2
ASPECTJRT_JAR=$3
RV_MONITOR_RT_JAR=$4
LOG_PATH=$5
INSTALL_JUNIT_MEASURE_TIME=$6
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

if [[ ! -d "${REPO_PATH}" ]]; then
  echo "Cannot find local repository"
  exit 1
fi

if [[ ! -f "${MY_ASPECTS_JAR}" || ! -f "${ASPECTJRT_JAR}" || ! -f "${RV_MONITOR_RT_JAR}" ]]; then
  echo "Missing jar"
  exit 1
fi

status=0
mvn -Dmaven.repo.local="${REPO_PATH}" install:install-file -Dfile=${MY_ASPECTS_JAR} -DgroupId="javamop-aspect" -DartifactId="javamop-aspect" -Dversion="1.0" -Dpackaging="jar" &>> ${LOG_PATH}
if [[ $? -ne 0 ]]; then
  status=1
fi

mvn -Dmaven.repo.local="${REPO_PATH}" install:install-file -Dfile=${ASPECTJRT_JAR} -DgroupId="aspectjrt" -DartifactId="aspectjrt" -Dversion="1.0" -Dpackaging="jar" &>> ${LOG_PATH}
if [[ $? -ne 0 ]]; then
  status=1
fi

# So that the AspectJ plugin will not download jar again
mvn -Dmaven.repo.local="${REPO_PATH}" install:install-file -Dfile=${ASPECTJRT_JAR} -DgroupId="org.aspectj" -DartifactId="aspectjrt" -Dversion="1.9.7" -Dpackaging="jar" &>> ${LOG_PATH}
if [[ $? -ne 0 ]]; then
  status=1
fi

mvn -Dmaven.repo.local="${REPO_PATH}" install:install-file -Dfile=${RV_MONITOR_RT_JAR} -DgroupId="rv-monitor-rt" -DartifactId="rv-monitor-rt" -Dversion="1.0" -Dpackaging="jar" &>> ${LOG_PATH}
if [[ $? -ne 0 ]]; then
  status=1
fi

pom="${REPO_PATH}/rv-monitor-rt/rv-monitor-rt/1.0/rv-monitor-rt-1.0.pom"
if [[ -n $(sed -n '2p' ${pom} || grep "parent") && -n $(sed -n '6p' ${pom} || grep "parent") ]]; then
  # Crazy way to fix could not resolve dependencies
  # It removes the <parent> </parent> block
  sed -i '2,6d' ${pom}
fi

if [[ ${INSTALL_JUNIT_MEASURE_TIME} == true ]]; then
  pushd ${SCRIPT_DIR}/../../experiments/junit-measure-time
  mvn -Dmaven.repo.local="${REPO_PATH}" install
  popd
fi

exit ${status}

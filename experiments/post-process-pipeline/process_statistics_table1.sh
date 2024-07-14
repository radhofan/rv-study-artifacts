#!/bin/bash
PROJECTS_DIR=$1
PROJECTS_LIST=$2

if [[ ! -d ${PROJECTS_DIR} || ! -f ${PROJECTS_LIST} ]]; then
  echo "Missing arguments projects-dir and/or projects-list"
  exit 1
fi

echo "project,branch,line,num_of_commits,first_commit_timestamp,sloc"

while read -r project; do
  if [[ ! -d ${PROJECTS_DIR}/${project}/projects/${project} ]]; then
    continue
  fi
  
  if [[ ! -f "${PROJECTS_DIR}/${project}/logs/statistics/${project}/cloc.txt" ]]; then
    continue
  fi

  pushd ${PROJECTS_DIR}/${project}/projects/${project} &> /dev/null
  total_branch_coverage=0
  total_line_coverage=0
  has_code_coverage=false
  sloc=$(grep "Java " "${PROJECTS_DIR}/${project}/logs/statistics/${project}/cloc.txt" | tr -s ' ' | cut -d ' ' -f 5)
  for jacoco in $(find -name "jacoco.csv"); do
    if [[ ! -s ${jacoco} ]]; then
      continue
    fi

    has_code_coverage=true
    total=$(echo "$(tail -n +2 ${jacoco} | cut -d ',' -f 7 | paste -sd+) + $(tail -n +2 ${jacoco} | cut -d ',' -f 6 | paste -sd+)" | bc -l)
    if [[ ${total} != "0" ]]; then
      branch_coverage=$(echo "($(tail -n +2 ${jacoco} | cut -d ',' -f 7 | paste -sd+))/(${total})" | bc -l)
    else
      branch_coverage=0
    fi
    
    total=$(echo "$(tail -n +2 ${jacoco} | cut -d ',' -f 9 | paste -sd+) + $(tail -n +2 ${jacoco} | cut -d ',' -f 8 | paste -sd+)" | bc -l)
    if [[ ${total} != "0" ]]; then
      line_coverage=$(echo "($(tail -n +2 ${jacoco} | cut -d ',' -f 9 | paste -sd+))/(${total})" | bc -l)
    else
      line_coverage=0
    fi
    
    total_branch_coverage=$(echo "${total_branch_coverage} + ${branch_coverage}" | bc -l)
    total_line_coverage=$(echo "${total_line_coverage} + ${line_coverage}" | bc -l)
  done
  num_of_commits=$(git rev-list --count HEAD)
  first_commit_date=$(git log --reverse --format="format:%at" | head -n 1)
  
  if [[ ${has_code_coverage} == "false" ]]; then
    total_branch_coverage=-1
    total_line_coverage=-1
  fi
  
  echo "${project},${total_branch_coverage},${total_line_coverage},${num_of_commits},${first_commit_date},${sloc}"
  popd &> /dev/null
done < ${PROJECTS_LIST}

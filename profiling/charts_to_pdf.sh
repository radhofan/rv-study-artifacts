#!/bin/bash
#
# Put all the pie charts into a single PDF
# Need to run plot_csv.py to generate the pie charts first
# Usage: charts_to_pdf.sh <projects-list> <charts-dir>
#
PROJECTS_LIST=$1
CHARTS_DIR=$2
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

check_inputs() {
  if [[ ! -f "${PROJECTS_LIST}" || ! -d "${CHARTS_DIR}" ]]; then
    echo "Usage: ./charts_to_pdf.sh <projects-list> <charts-dir>"
    exit 1
  fi
}

create_latex() {
  echo """
\documentclass[12pt]{article}
\usepackage{graphicx}
\usepackage{nopageno}
\usepackage[left=0cm, right=0cm, top=0cm, bottom=0.5cm]{geometry}

\begin{document}
""" >> report.tex
  
  local i=0
  while read -r project; do
    echo "${project}" >> report.tex
    echo "" >> report.tex
    echo "\centerline{\includegraphics[width=0.9\paperwidth]{${CHARTS_DIR}/${project}}}" >> report.tex
    
    ((i++))
    
    if [[ $i != 0 && $((i % 4)) == 0 ]]; then
      echo "\newpage" >> report.tex
    fi
  done < ${PROJECTS_LIST}
  
  echo "\end{document}" >> report.tex
}

check_inputs
create_latex
pdflatex report.tex
rm report.aux report.log report.tex

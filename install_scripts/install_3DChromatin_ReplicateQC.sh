#!/bin/bash

usage(){
cat <<EOF
usage: `basename $0` options
Installs HiCRep, HiC-Spector, QuASAR-Rep and QuASAR-QC.
OPTIONS
   -h               Show this message and exit
   --pathtopython   Path to python. DEFAULT: python
   --pathtor        Path to R. DEFAULT: R
   --rlib           Path to R libraries. DEFAULT=''
   --pathtobedtools Path to bedtools. DEFAULT=bedtools
   --modules        Names of modules to be loaded. Comma-delimited. This can be used on computing clusters with shared installations, and will be loaded as 'module load modulename'. DEFAULT=''

EOF
}

ARGS=`getopt -o "h" -l "pathtopython:,pathtor:,rlib:,pathtobedtools:,modules:" -- "$@"`
#eval set -- "$ARGS"

#DEFAULTS
PATHTOPYTHON="python"
PATHTOR="R"
RLIB=""
PATHTOBEDTOOLS=""
MODULES=""

while [ $# -gt 0 ]; do
    case $1 in
    -h) usage; exit 1;;
    --pathtopython) PATHTOPYTHON=$2; shift 2;;
    --pathtor) PATHTOR=$2; shift 2;;
    --rlib) RLIB=$2; shift 2;;
    --pathtobedtools) PATHTOBEDTOOLS=$2; shift 2;;
    --modules) MODULES=$2; shift 2;;
    *) usage; exit 1;;
    esac          
done

#============================
# install location
#============================
dir_of_script="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
repo_dir=$(dirname ${dir_of_script})

#============================
# install different software
#============================
mkdir -p ${repo_dir}/software

#if any modules should be loaded, load them now
for modulename in $(echo ${MODULES} | sed 's/,/ /g');
do
    module load ${modulename}
done

pythondir=$(dirname ${PATHTOPYTHON})

#get genomedisco
#===================
git clone https://github.com/kundajelab/genomedisco.git ${repo_dir}/software/genomedisco
rlibtext=""
if [[ ${RLIB} != "" ]];
then
    rlibtext="--rlib ${RLIB}"
fi

bedtoolstext=""
if [[ ${PATHTOBEDTOOLS} != "" ]];
then
    bedtoolstext="--pathtobedtools ${PATHTOBEDTOOLS}"
fi

modulestext=""
if [[ ${MODULES} != "" ]];
then
    modulestext="--modules ${MODULES}"
fi

#install genomedisco
${repo_dir}/software/genomedisco/install_scripts/install_genomedisco.sh --pathtopython ${PATHTOPYTHON} --pathtor ${PATHTOR} ${rlibtext} ${bedtoolstext} ${modulestext}

#install other software
pythondir=$(dirname ${PATHTOPYTHON})

#hicrep
#======
export R_LIBS="$(echo ${RLIB})"
export R_LIBS_USER=${R_LIBS}
if [[ ${RLIB} == "" ]];
then
    libtext=""
else
    libtext=",lib=\"${RLIB}\""
fi

cmd="${PATHTOR}script install_R_packages.R"
eval "${cmd}"
#cmd="${PATHTOR} -e 'source(\"https://bioconductor.org/biocLite.R\");biocLite(\"hicrep\"${libtext})'"
#eval "${cmd}"
#cmd="${PATHTOR} -e 'install.packages(\"reshape2\"${libtext},repos=\"http://cran.rstudio.com/\")'"
#eval "${cmd}"

#HiC-Spector
#===========
git clone https://github.com/gersteinlab/HiC-spector ${repo_dir}/software/HiC-spector

#QuASAR
#======
git clone https://github.com/bxlab/hifive ${repo_dir}/software/hifive
cd ${repo_dir}/software/hifive
${pythondir}/python setup.py install --user
${pythondir}/pip install h5py
${pythondir}/conda install -c anaconda mpi4py

#==================
#make a bashrc file
#==================
bashrc_file=${repo_dir}/software/genomedisco/scripts/bashrc.allMethods
bashrc_file_disco=${repo_dir}/software/genomedisco/scripts/bashrc.genomedisco

#for genomedisco
echo "CODEDIR=${repo_dir}/software/genomedisco" > ${bashrc_file}
echo "mypython=${PATHTOPYTHON}" >> ${bashrc_file}
echo "export PYTHONPATH=\""'$'"{PYTHONPATH}:"'$'"{CODEDIR}:"'$'"{CODEDIR}/genomedisco/comparison_types/\"" >> ${bashrc_file}

#add any module load commands
for modulename in $(echo ${MODULES} | sed 's/,/ /g');
do
    echo "module load ${modulename}" >> ${bashrc_file}
done

#point to R libraries
if [[ ${RLIB} != "" ]];
then
    echo "export R_LIBS=\"$(echo ${RLIB})\"" >> ${bashrc_file}
    echo "export R_LIBS_USER="'$'"{R_LIBS}" >> ${bashrc_file}
fi

#point to bedtools
echo "mybedtools=${PATHTOBEDTOOLS}" >> ${bashrc_file}

#point to hifive
echo "myhifive=${pythondir}/hifive" >> ${bashrc_file}

cat ${bashrc_file} > ${bashrc_file_disco}
#=============================================

#finally make a softlink for the code
ln -s ${repo_dir}/software/genomedisco/reproducibility_analysis/3DChromatin_ReplicateQC.py ${repo_dir}/3DChromatin_ReplicateQC.py

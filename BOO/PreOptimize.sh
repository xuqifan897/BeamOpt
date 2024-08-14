#3!/bin/bash

logFile="/data/qifan/projects/FastDoseWorkplace/BOOval/LUNG/experiment/PreOptimize.log"
matlab -nodisplay -batch "run('/data/qifan/projects/BeamOpt/BOO/PreOptimize_IMRT.m');" > ${logFile} 2>&1 &

# logFile="/data/qifan/projects/FastDoseWorkplace/BOOval/LUNG/experiment/Optimize.log"
# matlab -nodisplay -batch "run('/data/qifan/projects/BeamOpt/BOO/Main_4piIMRT_spine02_cpu.m');" > ${logFile} 2>&1 &
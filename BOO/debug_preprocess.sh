#!/bin/bash

# must match MIM structure names
BBox="external"  # bounding box - dose is calculated in this box (speedup runtime)
dicomdata="/data/qifan/FastDoseWorkplace/BOOval/HN02/data"
configfile="/data/qifan/FastDoseWorkplace/BOOval/HN02/experiment/config.json"
beamlist="/data/qifan/FastDoseWorkplace/BOOval/HN02/beamlist.txt"
structures="/data/qifan/FastDoseWorkplace/BOOval/HN02/structures.json"

# Quality settings
voxelsize='0.25'  # [units: cm]
sparsity='1e-4'  # probably don't need to change ever

export DOSECALC_DATA="/data/qifan/BeamOpt/CCCS/data"

expFolder="/data/qifan/FastDoseWorkplace/BOOval/HN02/experiment"
preprocess_exe="/data/qifan/BeamOpt/CCCS/build/dosecalc-preprocess/dosecalc-preprocess"
dosecalc_exe="/data/qifan/BeamOpt/CCCS/build/dosecalc-beamlet/dosecalc-beamlet"
cd ${expFolder}

# call preprocess, save a log of the output automatically
${preprocess_exe} \
    --dicom=${dicomdata} \
    --beamlist=${beamlist} \
    --structures=${structures} \
    --config=${configfile} \
    --bbox-roi=${BBox} \
    --voxsize=${voxelsize} \
    --device=1 \
    --verbose

# b /data/qifan/BeamOpt/CCCS/dosecalc-preprocess/cudaMemFunctions.cu:180
# b /data/qifan/BeamOpt/CCCS/dosecalc-preprocess/kernels.cuh:38
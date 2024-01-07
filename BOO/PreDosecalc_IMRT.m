restoredefaultpath;
addpath(genpath('BOO_QL'), '-end');
addpath(genpath('CERR2016'), '-end');
addpath(genpath('CERRaddins'), '-end');
addpath(genpath('utilities'), '-end');
addpath(genpath('beamlogs'), '-end');

patientName = 'patient1';
patientFolder = '/data/qifan/FastDoseWorkplace/BOOval/HN02';
dataFolder = fullfile(patientFolder, 'data');
expFolder = fullfile(patientFolder, 'experiment');
beamlogfile = 'head_beamlog.mat';
PrescriptionDose = 20;

if ~ isfolder(expFolder)
    mkdir(expFolder)
end

%% load to CERR
OutputFileName = fullfile(expFolder, [patientName, '.mat']);
CERRImportDicom_QL(dataFolder, OutputFileName);
% CERR('CERRSLICEVIEWER')
% sliceCallBack_QL('OPENNEWPLANC', OutputFileName);

%% generate beam_list file
load('4pi_angles.mat');
load(beamlogfile);

MLCangle = 0; % MLC angle is set to zero;
Gantry = theta_VarianIEC(beamlog_iso==1,1);
Couch = theta_VarianIEC(beamlog_iso==1,2);
MLCangles = MLCangle*ones(length(Gantry),1);
Angles = [Gantry Couch MLCangles];

beamlistFile = fullfile(patientFolder, 'beamlist.txt');
fileID = fopen(beamlistFile, 'w');
for ii = 1:size(Angles, 1)
    fprintf(fileID, '%6.4f %6.4f %6.4f \n', Angles(ii, :));
end

%% generate structures.json file
baseFileNames = dir(fullfile(dataFolder, '*.dcm'));
count2 = 0;
for ii = 1:length(baseFileNames)
    FileName = baseFileNames(ii).name;
    fullFileName = fullfile(dataFolder, FileName);
    info = dicominfo(fullFileName);
    if(strcmp(info.Modality,'RTSTRUCT'))
        RTstructfiles = FileName;
        if(count2>1)
            error('Multiple RT structure files!')
        end
        count2 = count2 + 1;
    end
end
RTstructInfo = dicominfo(fullfile(dataFolder, RTstructfiles));
allstructs = fieldnames(RTstructInfo.StructureSetROISequence);
for ii = 1:length(allstructs)
    structures{ii} = RTstructInfo.StructureSetROISequence.(allstructs{ii}).ROIName;
end

jsonFileName = fullfile(patientFolder, 'structures.json');
SaveStructureFileOnly(structures, jsonFileName, PrescriptionDose);
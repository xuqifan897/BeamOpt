restoredefaultpath;
addpath(genpath('BOO_QL'), '-end');
addpath(genpath('CERR2016'), '-end');
addpath(genpath('CERRaddins'), '-end');
addpath(genpath('utilities'), '-end');
addpath(genpath('beamlogs'), '-end');

clearvars -except M
close all
clc

patientName = 'HN02';
patFolder = fullfile('/data/qifan/FastDoseWorkplace/BOOval', patientName);
optFolder = fullfile(patFolder, 'experiment');

% OutputFileName = fullfile(patFolder, [patientName, '.mat']);
% CERR('CERRSLICEVIEWER');
% sliceCallBack_QL('OPENNEWPLANC', OutputFileName);

load(fullfile(optFolder, [patientName, '_M.mat']), 'M', 'dose_data', 'masks');
InfoNum = 0;
load(fullfile(optFolder, ['StructureInfo', num2str(InfoNum), '.mat']), 'StructureInfo');

ParamsNum = 0;
load(fullfile(optFolder, ['params', num2str(ParamsNum), '.mat']), 'params');

DS = 1;
[A, Weight] = CreateA(M, StructureInfo, DS);
ATrans = A';

[Dx, Dy] = CreateDxDyFMO(params.BeamletLog0);
D = [Dx; Dy];

%% Change parameters if needed
params.numBeamsWeWant = 20;
params.stepSize = 1e-04;
params.beamWeight = 50;
params.ChangeWeightsTrigger = 1000;
params.maxIter = 8000;
params.showTrigger = 500;

%% beam selection
seed = 2;  % for random number generator
rng(seed);
tic;


% profile on
[xFista,costsFista,activeBeams,activeNorms,topN] = BOO_IMRT_L2OneHalf_cpu_QL(A,ATrans,D,Weight,params);
% profile report


timeBeamSelect = toc;
figure;semilog(costsFista)
BOOresult = struct('patientName',patientName,...
    'params',params,'StructureInfo',StructureInfo,'xFista',xFista,...
    'activeBeams',activeBeams,'activeNorms',activeNorms,...
    'costsFista',costsFista,'timeBeamSelect',timeBeamSelect);

%% Show selected beams
finalBeams = activeBeams;
finalBeamsVarianIEC = params.beamVarianIEC(finalBeams,:);
gantryVarianIEC = finalBeamsVarianIEC(:,1);
couchVarianIEC = finalBeamsVarianIEC(:,2);

PTV = StructureInfo(1).Mask;
BODY = StructureInfo(2).Mask;
draw_beammask_QL(params.beamfpangles(finalBeams,:),BODY,PTV);

%% Polish step
paramsPolish = params;
paramsPolish.maxIter = 500;
tic
[xPolish,costsDF_polish, costs_polish] = polish_BOO_IMRT_cpu(finalBeams,A,D,Weights,paramsPolish);
% [xPolish,costsDF_polish,costs_polish] = polish_BOO_IMRT_gpu_QL(finalBeams,A,D,Weights,paramsPolish); % Recommend to use gpu mode for FMO
timePolish = toc;
figure;semilogy(costsDF_polish)

%% Visualize and save results
dose = M*xPolish; dose = reshape(dose,size(PTV)); dose(BODY==0&PTV==0)=0;
planName = [patientName ' Info' num2str(InfoNum)...
    ' params' num2str(ParamsNum) ' beam' num2str(nnz(finalBeams))];
addDoseToGui_dvo(dose,[planName])

if(~exist(fullfile(optFolder,[patientName '_DoseInfo.mat']),'file'))
    DoseInfo = [];
else
    load(fullfile(optFolder,[patientName '_DoseInfo.mat']),'DoseInfo');
end
PlanIndex = length(DoseInfo)+1;
DoseInfo(PlanIndex).Data = dose;
DoseInfo(PlanIndex).Name = planName;
DoseInfo(PlanIndex).CostDF = costsDF_polish(end);
DoseInfo(PlanIndex).Date = datestr(datetime);
save(fullfile(optFolder,[patientName '_DoseInfo.mat']),'DoseInfo','-v7.3');

strNum = [1,3:numel(StructureInfo)-2];
numBins = 200;
scale = plotDVH_QL(DoseInfo([end]), strNum, StructureInfo, numBins, 0);

result = struct('patientName',patientName,'dose',dose,'finalBeams',finalBeams,...
    'xPolish',xPolish,'timePolish',timePolish,'costsDF_polish',costsDF_polish,...
    'params',params,'StructureInfo',StructureInfo,...
    'gantryVarianIEC',gantryVarianIEC,'couchVarianIEC',couchVarianIEC,...
    'paramsPolish',paramsPolish,'BOOresult',BOOresult,'planName',planName);
save(fullfile(optFolder,['result ' planName '.mat']),'result')

selected_angles = struct('gantryVarianIEC',gantryVarianIEC,'couchVarianIEC',couchVarianIEC);
T = struct2table(selected_angles);
filename = fullfile(optFolder,['selected_angles_',planName,'.csv']);
writetable(T,filename)
function [inflMap, colXCoord, rowYCoord, colDividerXCoord, rowDividerYCoord, rowLeafPositions,MLCopeningSize] = getLSInfluenceMapFactorNoBar(LS,leak)
%"getLSInfluenceMap"
%   Gets an image of the influence generated by the beam described in LS.
%   Use getDICOMLeafPositions to generate LS.
%
%JRA&KZ 02/8/05
%
%Usage:
%   function inflMap = getLSInfluenceMap(LS);
%
% Copyright 2010, Joseph O. Deasy, on behalf of the CERR development team.
% 
% This file is part of The Computational Environment for Radiotherapy Research (CERR).
% 
% CERR development has been led by:  Aditya Apte, Divya Khullar, James Alaly, and Joseph O. Deasy.
% 
% CERR has been financially supported by the US National Institutes of Health under multiple grants.
% 
% CERR is distributed under the terms of the Lesser GNU Public License. 
% 
%     This version of CERR is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
% 
% CERR is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY;
% without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
% See the GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with CERR.  If not, see <http://www.gnu.org/licenses/>.

%Maximum precision of leaf position, in mm. Varian End and Side Accuracy 1.0 mm at
%isocenter. End and Side Repeatability 0.5 mm
precision = .5; 

%Get x max, min and round to precision value.

%If X jaws dosn't exist in DICOM
if ~isfield(LS,'xLimits')
    xMax = ceil(max(vertcat(LS.xLeafPositions{:}),[],1) / precision) * precision;
    xMin = floor(min(vertcat(LS.xLeafPositions{:}),[],1) / precision) * precision;
    LS.xLimits{1}(1) = xMin;
    LS.xLimits{1}(2) = xMax;
end

xMax = ceil(max(vertcat(LS.xLimits{:}),[],1) / precision) * precision;
xMin = floor(min(vertcat(LS.xLimits{:}),[],1) / precision) * precision;
fieldSize.x = max(xMax) - min(xMin);
fieldLim.x  = [max(xMax) min(xMin)];

yMax = ceil(max(vertcat(LS.yLimits{:}),[],1) / precision) * precision;
yMin = floor(min(vertcat(LS.yLimits{:}),[],1) / precision) * precision;
fieldSize.y = max(yMax) - min(yMin);
fieldLim.y  = [max(yMax) min(yMin)];

yRes = precision;
nyElements = ceil(fieldSize.y/yRes);
xRes = precision;
nxElements = ceil(fieldSize.x/xRes);

inflMap=zeros(nyElements, nxElements);
colDividerXCoord = linspace(fieldLim.x(2), fieldLim.x(1), nxElements+1);
rowDividerYCoord = linspace(fieldLim.y(2), fieldLim.y(1), nyElements+1);

if isfield(LS, 'yLeafPositions')
    rowLeafPositions = round(interp1(rowDividerYCoord, 1:nyElements+1, LS.yLeafPositions,'linear', 'extrap'));
    rowLeafPositions = clip(rowLeafPositions, 1, nyElements+1, 'limits');
    leafBoundariesToKeep = [diff(rowLeafPositions)>0;true];
    rowLeafPositions = rowLeafPositions(leafBoundariesToKeep);
    leavesToKeep = leafBoundariesToKeep(1:end-1);
else
    LS.xLeafPositions{1} = [xMin xMax];
    LS.meterSetWeight = {1};
    rowLeafPositions = [1 nyElements+1];
    leavesToKeep = 1;
end

if length(LS.meterSetWeight) == 1
    doses = LS.meterSetWeight{:};
else
    doses = [0 diff([LS.meterSetWeight{:}])];
end

% backupMap = inflMap;
%h = waitbar(0,['Generating Fluence Map From MLC Positions For Beam ',num2str(beamIndex)],'Name','Please wait...');

%HCF - head scatter radiation parametrs for varian 2100CD Zhu, MedPhys,
%Vol. 31, No 9 , Sept 2004
if LS.energy == 6 && strcmpi(LS.manufacturer(1),'V')
    A1 = 0.0013;
    A2 = 0.078;
    K = 1.5;
    LAMDA = 7.69;
elseif LS.energy == 18 && strcmpi(LS.manufacturer(1),'V')
    A1 = 0.0013;
    A2 = 0.082;
    K = 1.5;
    LAMDA = 8.16;
elseif LS.energy == 6 && strcmpi(LS.manufacturer(1),'E')
    A1 = 0.0005;
    A2 = 0.072;
    K = 1.2;
    LAMDA = 9.85;
elseif LS.energy == 18 && strcmpi(LS.manufacturer(1),'E')
    A1 = 0.0004;
    A2 = 0.088;
    K = 1.2;
    LAMDA = 8.57;
elseif LS.energy == 6 && strcmpi(LS.manufacturer(1),'S')
    A1 = 0.0004;
    A2 = 0.094;
    K = 1.5;
    LAMDA = 9.8;
elseif LS.energy == 18 && strcmpi(LS.manufacturer(1),'S')
    A1 = 0.0004;
    A2 = 0.099;
    K = 1.5;
    LAMDA = 9.52;
else
    errordlg('This MLC Manufacturer or Energy is not supported or Missed Info in DICOM');
    return
end

for i=1:length(LS.xLeafPositions)
    %    inflMap = backupMap;
    nLeaves = length(LS.xLeafPositions{i})/2;

    if length(LS.xLimits) > 1
        jpL = LS.xLimits{i}(1);
        jpR = LS.xLimits{i}(2);
    else
        jpL = LS.xLimits{1}(1);
        jpR = LS.xLimits{1}(2);
    end

    lpL = LS.xLeafPositions{i}(1:nLeaves);
    lpR = LS.xLeafPositions{i}(nLeaves+1:end);
    lpLK = lpL(leavesToKeep);
    lpRK = lpR(leavesToKeep);
    
    MLCopeningSize(:,i) = lpRK - lpLK;
    
    lpLCols = interp1(colDividerXCoord, 1:nxElements+1, lpLK, 'linear', 'extrap');
    lpRCols = interp1(colDividerXCoord, 1:nxElements+1, lpRK, 'linear', 'extrap');

    %Column divider positions of jaws.
    jpLCol = interp1(colDividerXCoord, 1:nxElements+1, jpL, 'linear', 'extrap');
    jpRCol = interp1(colDividerXCoord, 1:nxElements+1, jpR, 'linear', 'extrap');
    
    jpLCol = round(jpLCol);
    jpRCol = round(jpRCol);

    lpLCols = clip(lpLCols, jpLCol, jpRCol, 'limits');
    lpRCols = clip(lpRCols, jpLCol, jpRCol, 'limits');

    lpLCols = round(lpLCols);
    lpRCols = round(lpRCols);
    
   for j=1:length(lpLCols)
        %HCF from output ratio for MLC fields Zhu, MedPhys
        F_X = abs(lpLCols(j) - (lpRCols(j)-1))*precision/10;
        F_Y = abs(rowLeafPositions(j+1) - rowLeafPositions(j))*precision/10;
        F = (1+K)*F_X * F_Y/(K*F_X + F_Y);
        HCF = (1+A1*F)*(1+A2*(erf(F/LAMDA))^2)/((1+A1*10)*(1+A2*(erf(10/LAMDA))^2));
        inflMap(rowLeafPositions(j):rowLeafPositions(j+1)-1, lpLCols(j):lpRCols(j)-1) = inflMap(rowLeafPositions(j):rowLeafPositions(j+1)-1, lpLCols(j):lpRCols(j)-1) + HCF*doses(i);
        inflMap(rowLeafPositions(j):rowLeafPositions(j+1)-1, jpLCol:lpLCols(j)-1) = inflMap(rowLeafPositions(j):rowLeafPositions(j+1)-1, jpLCol:lpLCols(j)-1) + leak*doses(i);
        inflMap(rowLeafPositions(j):rowLeafPositions(j+1)-1, lpRCols(j):jpRCol-1) = inflMap(rowLeafPositions(j):rowLeafPositions(j+1)-1, lpRCols(j):jpRCol-1) + leak*doses(i);
    end
    
    %waitbar(i/length(LS.xLeafPositions));
    %    frame = inflMap;
    %    imagesc(inflMap);
    %    mi(:,:,i) = inflMap;
    %    inflMap(inflMap == 0) = 1;
    %    inflMap(inflMap ~= 0) = 2;
    %    colormap([0 0 0; 1 1 1]);
    %    %mi(:,:,i) = inflMap;
    %    %mi(i) = im2frame(inflMap, [0 0 0; 1 1 1]);
    %    drawnow;
    %    pause(.006);
end
%close(h);
colXCoord = colDividerXCoord(1:end-1) + precision/2;
rowYCoord = rowDividerYCoord(1:end-1) + precision/2;
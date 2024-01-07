function dicomrt_plotfluence(fluence,part,sgmnt,ftype,xgrid,ygrid,imtype,normtype)
% dicomrt_plotfluence(fluence,part,sgmnt,ftype,xgrid,ygrid,imtype,normtype)
%
% Plots fluence map.
%
% fluence   is a cell array containing the fluence map characteristic of a 
%           phase space file as generated by dicomrt_phspmap
% part      indicates the type of particle for which fluence maps will be plotted
%           = 1 photons (default), 2 electrons, 3 positrons  (OPTIONAL)
% sgmnt     vector  (OPTIONAL) which indicates wheater plot fluence map for each 
%           individual segment and weather plot beam segments into a single or 
%           separate figure
%           sgmnt(1) = 0 (default), no segment plot
%           sgmnt(1) ~= 0 segment plot
%           sgmnt(2) = 0 beam segments in the same figure
%           sgmnt(2) ~= 0 beam segments in separate figures
%           sgmnt(3) = beam number to plot, if sgmnt(2) ~= 0 
%                      not considered if sgmnt(2) = 0 
% ftype     indicates the type of fluence being plotted (OPTIONAL)
%           ~= 0 energy fluence, = 0 fluence (default)
% xgrid     is an array containing the coordinates of the fluence map in the X direction
% ygrid     is an array containing the coordinates of the fluence map in the Y direction
%           (xgrid and ygrid are returned by dicomrt_phspmap)
% imtype    indicates the type of image to plot (OPTIONAL)
%           ~= 0 imagesc, = 0 surfl (default)
% normtype  indicates how to normalise quantities
%           =0 (default) normalised to MUs (based on the provided normalisation factor)
%           =1 normalised to the total number of particles from original source
%
% Example:
%
% dicomrt_plotfluence(A,1,1) plots photon fluence maps stored in A for all
% segments for each beam
% dicomrt_plotfluence(A) plots total photon fluence maps stored in A only
% for each beam
%
% See also: dicomrt_phspmap
%
% Copyright (C) 2002 Emiliano Spezi (emiliano.spezi@physics.org) 

% Check number of argument
error(nargchk(1,8,nargin))

% Check cases
if iscell(fluence)~=1
   error('dicomrt_plotfluence: Input is not a valid argument. Exit now!');
   return
end

if exist('sgmnt')==0
    sgmnt=[0 0 0]; % plot only total fluence
elseif exist('sgmnt')~=0 
    if length(sgmnt)~=3
        error('dicomrt_plotfluence: The OPTIONAL parameter sgmnt must have vector length = 3. Exit now !');
    end
end

if exist('part')==0
    part=1; % default to photons
end

if exist('ftype')==0
    ftype=0; % default to fluence
end

if exist('imtype')==0
    imtype=0; % default to surfl
end

if exist('normtype')==0
    normtype=0; % default to MU norm
end

% Default plot parameters
maxcol=2;
maxrow=4;

if normtype~=0
    F=1;
else
    F=8.7502e+013;
end

% [dose/part] to [dose/MU] conversion factor F
% determined from the followinf formula:
% ADMC [Gy/part] * F = ADMeas [Gy/MU]
%
% where ADMC = Average dose from MC between 5 and 15 cm deep
%       ADMeas = Average measured dose between 5 and 15 cm deep
% F=8.7502e+013; % The value was obtained from calibration experiment with the following BEAM parameters:
%               NBRSPL=30;      % # of brem photons after splitting (because IBRSPL=1, see BEAM manual for details)
%               IRRLTT=0;       % e- Russian Roulette no 
%               IREJCT_GLOBAL=1;% range rejection yes using ESAVE_GLOBAL below
%               ESAVE_GLOBAL=2; % 
%               ESTEPE=0;
%               SMAX=0;
%               ECUTIN=0.7;
%               PCUTIN=0.01;
%
%               and DOSXYZ parameters:
%               ECUTIN=0.700;
%               PCUTIN=0.01;
%               SMAX=0;
%               ESTEPE:0.25;
%               DSURROUND=[60,0,0,0];
%
%               Standard and "ad-hoc" built materials  were taken from 521icru.pegs4dat.
%               See dicomrt_BEAMexport and dicomrt_DOSXYZexport for further details.
    
% prepare lables and titles
labelX=('X axis (cm)');
labelY=('Y axis (cm)');
if part==1
    if ftype==0
        labelZ=('Photons/cm^{2}/MU');
        title_attach=': photon fluence map: beam ';
        maintitle=('Photon Fluence');
    else
        labelZ=('Photons/cm^{2}/MU/MeV');
        title_attach=': photon energy fluence map: beam ';
        maintitle=('Photon Energy Fluence');
    end
elseif part==2
    if ftype==0
        labelZ=('electrons/cm^{2}/MU');
        title_attach=': electron fluence map: beam ';
        maintitle=('Electron Fluence');
    else
        labelZ=('electrons/cm^{2}/MU/MeV');
        title_attach=': electron energy fluence map: beam ';
        maintitle=('Electron Energy Fluence');
    end
elseif part==3
    if ftype==0
        labelZ=('positrons/cm^{2}/MU');
        title_attach=': positron fluence map: beam ';
        maintitle=('Positron Fluence');
    else
        labelZ=('positrons/cm^{2}/MU/MeV');
        title_attach=': positron energy fluence map: beam ';
        maintitle=('Positron Energy Fluence');
    end
else
    error('dicomrt_plotfluence: PART can be 1(=photons), 2(=electrons) or 3(=positrons). Exit now !');
end

if sgmnt(1)~=0 & sgmnt(2)==0% plot segments components requested
    disp(' ')
    disp('Segment fluence option requested');
    disp(['A total of : ',num2str(maxcol*maxrow),' fluences are being plotted per beam']);
    plotopt = input ('Do you want to change these defaults ? Y/N [N]','s');
    if plotopt == 'Y' | plotopt == 'y';
        tempcol = input('Input number of colums you want to use: ');
        if isempty(maxcol) | ischar(maxcol)
           warning('dicomrt_plotfluence: parameters did not change !');
        else
           maxcol=tempcol;
        end
        temprow = input('Input number of rows you want to use: ');
        if isempty(maxcol) | ischar(maxcol)
             warning('dicomrt_plotfluence: parameters did not change !');
        else
             maxrow=temprow;
        end
    end
    % start plotting
    for i=1:size(fluence,1) % loop over beams
        beamnumber=[inputname(1),title_attach,int2str(i)];
        handle2=figure;
        %set(handle2,'Name',beamnumber,'Interpreter','none');
        set(handle2,'Name',beamnumber);
        %set(handle2,'Position',[0.6345 6.3452 20.3046 15.2284]);
        hold
        for j=1:size(fluence{i,2},2) % loop over segments
            % prepare lables and titles
            segmentnumber=['segment ',int2str(j)];
            % plot fluence map
            subplot(maxrow,maxcol,j);
            if imtype~=0
                handle=imagesc(fluence{i,2}{j}(:,:,part)*F);
                colormap hot;
            else
                handle=surfl(fluence{i,2}{j}(:,:,part)*F);
                colormap gray;
            end
            title(segmentnumber,'FontWeight','bold','FontSize',10,'Interpreter','none');
            xlabel(labelX,'FontSize',8);
            ylabel(labelY,'FontSize',8);
            zlabel(labelZ,'FontSize',8);
            set(gca,'FontSize',10);
            shading interp;
            if exist('xgrid')==1
                if isequal(xgrid,0)~=1
                    set(handle,'XData',xgrid);
                end
            end
            if exist('ygrid')==1
                if isequal(ygrid,0)~=1
                    set(handle,'YData',ygrid);
                end
            end
            axis tight;
        end
    end % total beam fluence only
elseif sgmnt(1)~=0 & sgmnt(2)~=0 & sgmnt(3)~=0% plot segments components requested for beam sgmnt(3)
    disp(['Segment fluence option requested ONLY for beam :',num2str(sgmnt(3))]);
    disp('Plotting segments map on different figures');
    % start plotting
    for j=1:size(fluence{sgmnt(3),2},2) % loop over segments
        % prepare lables and titles
        segmentnumber=['segment ',int2str(j)];
        beamnumber=[inputname(1),title_attach,int2str(sgmnt(3)),' ',segmentnumber];
        handle2=figure;
        %set(handle2,'Name',beamnumber,'Interpreter','none');
        set(handle2,'Name',beamnumber);
        set(handle2,'NumberTitle','off');
        % plot fluence map
        if imtype~=0
            handle=imagesc(fluence{sgmnt(3),2}{j}(:,:,part)*F);
            colormap hot;
        else
            handle=surfl(fluence{sgmnt(3),2}{j}(:,:,part)*F);
            colormap gray;
        end
        title(['Fluence map beam ',int2str(sgmnt(3)),' ',segmentnumber],'FontSize',18,'Interpreter','none');
        xlabel(labelX,'FontSize',14);
        ylabel(labelY,'FontSize',14);
        zlabel(labelZ,'FontSize',14);
        shading interp;
        if exist('xgrid')==1
            if isequal(xgrid,0)~=1
                set(handle,'XData',xgrid);
            end
        end
        if exist('ygrid')==1
            if isequal(ygrid,0)~=1
                set(handle,'YData',ygrid);
            end
        end
        axis tight;
    end
elseif sgmnt(1)~=0 & sgmnt(2)~=0 & sgmnt(3)==0% plot segments components requested for all beams (hot!)
    disp(['Segment fluence option requested ONLY for beam :',num2str(sgmnt(3))]);
    disp('Plotting segments map on different figures');
    % start plotting
    for i=1:size(fluence,1) % loop over beams
        for j=1:size(fluence{i,2},2) % loop over segments
            % prepare lables and titles
            segmentnumber=['segment ',int2str(j)];
            beamnumber=[inputname(1),title_attach,int2str(i),' ',segmentnumber];
            handle2=figure;
            %set(handle2,'Name',beamnumber,'Interpreter','none');
            set(handle2,'Name',beamnumber);
            set(handle2,'NumberTitle','off');
            % plot fluence map
            if imtype~=0
                handle=imagesc(fluence{i,2}{j}(:,:,part)*F);
                colormap hot;
            else
                handle=surfl(fluence{i,2}{j}(:,:,part)*F);
                colormap gray;
            end
            title(segmentnumber,'FontWeight','bold','FontSize',10,'Interpreter','none');
            xlabel(labelX,'FontSize',12);
            ylabel(labelY,'FontSize',12);
            zlabel(labelZ,'FontSize',12);
            set(gca,'FontSize',12);
            shading interp;
            if exist('xgrid')==1
                if isequal(xgrid,0)~=1
                    set(handle,'XData',xgrid);
                end
            end
            if exist('ygrid')==1
                if isequal(ygrid,0)~=1
                    set(handle,'YData',ygrid);
                end
            end
            axis tight;
        end
    end % total beam fluence only    
elseif sgmnt(1)==0 % no segment plot
    for i=1:size(fluence,1) % loop over beams
        beamnumber=[inputname(1),title_attach,int2str(i)];
        % plot total fluence into a separate
        handle1=figure;
        if imtype ~=0
            imagesc(fluence{i,1}(:,:,part)*F);
            colormap hot;
        else
            surfl(fluence{i,1}(:,:,part)*F);
            colormap gray;
        end
        set(handle1,'Name',beamnumber);
        title(maintitle,'FontSize',18,'Interpreter','none');
        xlabel(labelX,'FontSize',12);
        ylabel(labelY,'FontSize',12);
        zlabel(labelZ,'FontSize',12);
        shading interp;
        if exist('xgrid')==1
            if isequal(xgrid,0)~=1
                set(handle,'XData',xgrid);
            end
        end
        if exist('ygrid')==1
            if isequal(ygrid,0)~=1
                set(handle,'YData',ygrid);
            end
        end
        axis tight;
    end
end

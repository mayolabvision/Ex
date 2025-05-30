function runex(xmlFile,varargin)
% function runex(xmlFile,varargin)
%
% main Ex function.
%
% xmlFile: the xml file name for the desired experiment
%
% Optional arguments:
%
% repeats: the number of blocks to run. overrides the variable
%   'rpts' in the xml file. Must be a positive integer.
% saveMat (default true): if true, data (including the trial-by-trial event
%   codes) are written to a local .mat file. if false, no file is created.
% useDatabase (default true): if true, a sqlite database will be created/used 
%   to keep track of notes/saved files/times/etc. at a location defined by: 
%      fullfile(params.localDataDir, 'database', 'experimentInfo.db')
%   where params is defined in exGlobals.m
% fullScreen (default true): runs the local runex interface GUI in full
%   screen mode (strongly recommended for good timing)
% demoMode (default false): if true, turns off file saving and many other
%   parameters for system testing.
% subjectID: a string of that is the subject ID (default will prompt you)
% experimenter: a string of that is the experimenter (default will prompt you)
% sessionNumber: a non-negative value that is the session number (default
%   is that this is determined by the database, or prompted)
%
%
% LAST MODIFIED:
% 05 Jan 23 -- revamped input parameters and outfile saving
% 28 Sept 21 -- on/off flag for database
% 22Nov19 by MAS/XZ - new version, github release work

%% Can uncomment this if you want to speed up PTB startup (but has a risk if any system software/hardware changes)
Screen('Preference', 'SkipSyncTests', 0);

%% initialize global variables
clear global behav allCodes params;
clear plotDisplay;

global eyeHistory eyeHistoryCurrentPos;
global trialCodes thisTrialCodes trialTic allCodes;
global trialMessage trialData exPrint;
global wins params codes calibration stats;
global behav outfilename;
global audioHandle;
global debug; %#ok<NUSED> This will be assigned by exGlobals
global sockets socketsDatComp bciSockets;
global bciCursorTraj; % only used when bci cursor is enabled
global typingNotes;
global notes;
global sqlDb;
%global sessionNumber;
typingNotes = false;

%% Startup message
thisFileInfo = dir(which(mfilename));
fprintf('*****Running RUNEX (last modified %s). Started %s*****\n\n',thisFileInfo.date,datestr(now));

%% Check we're on linux only
assert(isunix,'RUNEX only supports linux');

%% parse input parameters

if nargin < 1
    error('Inputs not specified. Must at least use this syntax: runex(xmlFile)');
end

p = inputParser;
p.addOptional('fullScreen',true,@islogical);
p.addOptional('useDatabase',true,@islogical);
p.addOptional('repeats',0,@(x) mod(x,1)==0 && (x>=0));
p.addOptional('saveMat',true,@islogical);
p.addOptional('demoMode',false,@islogical);
p.addOptional('sessionNumber',NaN,@(x) mod(x,1)==0 && (x>=0));
p.addOptional('subjectID','',@ischar);
p.addOptional('experimenter','',@ischar);
p.parse(varargin{:});
fullScreen = p.Results.fullScreen;
useDatabase = p.Results.useDatabase;
repeats = p.Results.repeats;
saveMat = p.Results.saveMat;
demoMode = p.Results.demoMode;

if demoMode
    params.getEyes = 0;
    params.sendingCodes = 0;
    params.rewarding = 0;
    params.getSpikes = 0;
    params.writeFile = 0;
    useDatabase = false;
    fullScreen = false;deleted:    xml/ANI_blocked_pursuitsacc.xml

    saveMat = false;
    warning('Ex is running in Demo Mode. Many features are disabled.');
end

if ~isnan(p.Results.sessionNumber)
    if ~useDatabase
        params.sessionNumber = p.Results.sessionNumber;
    else
        error('You cannot specify the session number as an argument if you have the database enabled');
    end
end

if ~isempty(p.Results.subjectID)
    params.SubjectID= p.Results.subjectID;
end

if ~isempty(p.Results.experimenter)
    params.experimenter = p.Results.experimenter;
end

if ~fullScreen
    warning('PTB can have degraded graphics performance when not running full screen. Please use full screen for data collection.');
end

%% Put our code in high-priority/realtime mode
origPriority = Priority(1); % 1 or > is realtime mode; 0 is normal
newPriority = Priority(1); % check that the priority is now 1
if newPriority ~= 1 
        ansr = questdlg('Unable to change Priority. Probably PsychLinuxConfiguration was not run. Continue?');
    switch lower(ansr(1))
        case 'y'
            warning('Running without setting Priority');
        otherwise
            return; %punt
    end
end

%% Set verbosity. 3 is default, 1 means only output errors
origVerbosity = Screen('Preference', 'Verbosity', 1);

%% Make sure Psychtoolbox is using OpenGL
AssertOpenGL;

%% clear timers and serial port objects
delete(timerfindall);
delete(instrfind);

%% call EXGLOBALS
rootDir = ''; %#ok<NASGU>
exGlobals; % Load global variables, codes, etc

%% Figure out our machine name
[~,params.machine] = system('hostname'); %save name of control machine with data
%assert(status==0,'System call to get hostname failed');
params.machine = lower(deblank(cell2mat(regexp(params.machine,'^[^\.]+','match'))));
while isempty(params.machine)
    [~,params.machine] = system('hostname'); %save name of control machine with data
    params.machine = lower(deblank(cell2mat(regexp(params.machine,'^[^\.]+','match'))));
end
assert(~isempty(params.machine),'Machine name must not be empty'); 
assert(sum(isspace(params.machine))==0,'Machine name must not have spaces');

%% UDP initialization for showex
matlabUDP2('all_close'); %first close any open UDP sessions.
sockets(1) = matlabUDP2('open',params.control2displayIP,params.display2controlIP,params.control2displaySocket);

fprintf('Waiting for showex (CTRL+C to quit) ...');
msgAndWait('ack',[],60); %wait up to 1 min for showex to start -acs14mar2016
fprintf(' connected.\n');

%% Find directories and set paths
thisFile = mfilename('fullpath');
[runexDirectory,~,~] = fileparts(thisFile); clear thisFile;
% everything up to and including the last file separator:
runexDirectory = regexp(runexDirectory,sprintf('.*(?!\\%c).*\\%c',filesep,filesep),'match'); 
requiredDirectories = {'ex','ex_control','xml','xippmex','ex_control/database','ex_control/communications'}; % MATT 01.06.23 - added database because it was needed - how did this work before?
%requiredDirectories = {'ex','ex_control','xml','xippmex','ex_control/database','ex_control/communications','ex_control/utils'}; % MATT 01.06.23 - added database because it was needed - how did this work before?
for dx = 1:numel(requiredDirectories)
    addpath([runexDirectory{:},requiredDirectories{dx}]);
end

%% get/open database file
if useDatabase
    homedirCont = dir('~');
    homedir = homedirCont(1).folder;
    localDataDir = params.localDataDir;
    homeTag = find(localDataDir == '~');
    localDataDir = [localDataDir(1:homeTag-1) homedir localDataDir(homeTag+1:end)];
    sqlDbPath = fullfile(localDataDir, 'database', 'experimentInfo.db');
    sqlDb = sqlite(sqlDbPath);
else
    sqlDb = [];
end
%% Find Ex_local dir, make sure it's there, make sure it has the subdirectories you expect, and add it to the path
% if exist(params.localExDir,'dir')
%     requiredLocalDirectories = {'ex','xml','user','control','display'};
%     for ld = 1:numel(requiredLocalDirectories)
%         ldpath = [params.localExDir,filesep,requiredLocalDirectories{ld}];
%         if exist(ldpath,'dir')
%             addpath(ldpath);
%         else
%             mkdir(ldpath);
%             addpath(ldpath);
%             % make the subfolder and add to path
%         end
%     end
% else %  if there's no Ex_local at all, make all subfolders and add to path
%     mkdir(params.localExDir);
%     addpath(genpath(params.localExDir));
% end
% 

checkBackup = true;
makeDir = true;
if exist(params.localExDir,'dir')
    requiredLocalDirectories = {'ex','xml','user','control','display'};
    ld = zeros(1,length(requiredLocalDirectories));
    for idx = 1:numel(requiredLocalDirectories)
        ldpath(idx) = {[params.localExDir,filesep,requiredLocalDirectories{idx}]};
        if exist(ldpath{idx},'dir')
            ld(idx) = 1;
        end
    end
    if sum(ld) == length(requiredLocalDirectories)
        addpath(genpath(params.localExDir));
        checkBackup = false;
        makeDir = false;
        try
            testN = 1;
            save(fullfile(params.localExDir,'control','test.mat'),'testN');
        catch
            checkBackup = true;
            makeDir = true;
            warning('Ex_local saving failed');
        end
    else
        warning('Ex_local does not have full required directories');
    end
else
    warning('Ex_local folder does not exist');
end

if checkBackup
    p =  'Do you want to run with Ex_local_backup? Enter Y if you want.';
    inputResult = input(p,'s');
    if inputResult == 'Y'
        if exist([params.localExDir,'_backup'],'dir')
            requiredLocalDirectories = {'ex','xml','user','control','display'};
            ld = zeros(1,length(requiredLocalDirectories));
            for idx = 1:numel(requiredLocalDirectories)
                ldpath(idx) = {[params.localExDir,'_backup',filesep,requiredLocalDirectories{idx}]};
                if exist(ldpath{idx},'dir')
                    ld(idx) = 1;
                end
            end
            if sum(ld) == length(requiredLocalDirectories)
                addpath(ldpath{:});
                makeDir = false;
                try
                    testM = 1;
                    save(fullfile([params.localExDir,'_backup'],'control','test.mat'),'testM');
                    params.localExDir = [params.localExDir,'_backup'];
                catch
                    makeDir = true;
                    warning('Ex_local_backup saving failed'); 
                end
            else
                warning('Ex_local_backup does not have full required directories');
            end
        else
            warning('Ex_local_backup does not exist');
        end    
    end
end

if makeDir
    if ~unix('test -L Ex_local')
       disp('Ex_local is a link, which can not be run');
        return;
    end
    if ~exist(params.localExDir,'dir')
        p = 'Do you want to create Ex_local folder and subfolders? They are required to run!(Enter Y if you want.)';
        inputResult = input(p,'s');
        if inputResult == 'Y'
            mkdir(params.localExDir);
            mkdir(params.localExDir,'ex');
            mkdir(params.localExDir,'xml');
            mkdir(params.localExDir,'user');
            mkdir(params.localExDir,'control');
            mkdir(params.localExDir,'display');
        else
            disp('Ex_local folder and subfolders are required to run.');
            return;
        end
    else
        disp('Ex_local folder may be empty/corrupted, please delete it to continue.')
        return;
    end
end


%% prompt for subject ID if needed
if isfield(params,'SubjectID')
    params.SubjectID = regexprep(lower(params.SubjectID),'\s',''); %enforce lowercase / no whitespace 
    disp(['Current Subject ID = ',params.SubjectID]);
else
    params.SubjectID = input('Enter the subject ID:','s');
    params.SubjectID = regexprep(lower(params.SubjectID),'\s',''); %enforce lowercase / no whitespace 
end

if useDatabase
    params.SubjectID = confirmOrAddSubjectToDatabase(params.SubjectID);
end

%% prompt for experimenter
if isfield(params,'experimenter')
    params.experimenter = regexprep(lower(params.experimenter),'\s',''); %enforce lowercase / no whitespace
    disp(['Current experimenter = ',params.experimenter]);
else
    params.experimenter = input('Enter the main experimenter:','s');
    params.experimenter = regexprep(lower(params.experimenter),'\s',''); %enforce lowercase / no whitespace
end

if useDatabase
    params.experimenter = confirmExperimenterNameWithDatabase(params.experimenter);
end
    
%% prompt for session number
if useDatabase
    %disp(['Current session number = ',params.sessionNumber]); % can't do this as it's not known from database yet
    disp('Current session number will be found in the database');
else
    if isfield(params,'sessionNumber')
        disp(['Current session number = ',num2str(params.sessionNumber)]);
    else
        sessionNumberStr = input('Enter the session number:', 's');
        params.sessionNumber = sessionNumberStr;
    end
end

%% quick double-check
assert(isempty(strfind(params.machine,'_')),'Found an underscore');

%% read the XML file
try
    [expt, xmlParams, xmlRand, xmlGlobals] = readExperiment(xmlFile,params.SubjectID,params.machine);
    xmlParams.xmlFile = xmlFile;
    
    % read in ex_ Function to text to be saved w/ the .mat outfile
    exFileString = [xmlParams.exFileName,'.m'];
    exfid=fopen(exFileString,'r');
    if exfid == -1
        error('Cannot open file %s',exFileString);
    end
    exFileText = fscanf(exfid,'%c',inf);
    fclose(exfid);
    
    
    
catch ME
    fprintf(ME.message);
    return;
    %rethrow(ME);
end
disp(xmlFile);
disp(['Finished reading subject-specific XML file for ',params.SubjectID]);
disp(['Finished reading rig-specific XML file for ',params.machine]);

params = exCatstruct(params,xmlGlobals); %concatenate - subject globals overwrite rig globals which in turn overwrite default globals
xmlParams = exCatstruct(xmlParams,expt{1});

switch class(xmlParams.bgColor)
    case 'char'
        xmlParams.bgColor = str2num(xmlParams.bgColor); %#ok<ST2NM>
    otherwise
        %do nothing
end


%% opening up chatter with the data computer
% this needs to happen after the XML params have been loaded for the IP
% addresses to be changeable among rigs
socketsDatComp.sender = matlabUDP2('open',params.control2dataIP,params.data2controlIP,params.control2dataSocketSend);
socketsDatComp.receiver = matlabUDP2('open',params.control2dataIP,params.data2controlIP,params.control2dataSocketReceive);
recordingTrueFalse = false;

%% Initialize BCI Functionality
if isfield(xmlParams, 'useBci')
    params.bciEnabled = xmlParams.useBci;
end
if params.bciEnabled
    try
        bciSockets.sender = matlabUDP2('open',params.control2bciIP,params.bci2controlIP,params.control2bciSocket);
        bciSockets.receiver = bciSockets.sender;
    catch ERR
        disp(ERR.message);
        disp('*ERROR* - No BCI connection, proceeding without BCI computer');
    end
    
    disp('Establishing communication with BCI computer');
    %matlabUDP2('send', sockets(2), 'ready');
    %bciMsg = matlabUDP2('receive', sockets(2));
    matlabUDP2('send', bciSockets.sender, 'ready');
    bciMsg = matlabUDP2('receive', bciSockets.receiver);
    tm = 0;
    while ~strcmp(bciMsg, 'prepared')
        tm = tm+1;
        pause(0.1)
        %matlabUDP2('send', sockets(2), 'ready');
        %bciMsg = matlabUDP2('receive', sockets(2));
        fprintf('BCI computer communication attempt %d\n', tm)
        matlabUDP2('send', bciSockets.sender, 'ready');
        bciMsg = matlabUDP2('receive', bciSockets.receiver);

    end
    bciMsg = '';
    % wait for the second ack that happens after the buffer has been
    % cleared
    while ~strcmp(bciMsg, 'flushed')
        pause(0.1)
        %bciMsg = matlabUDP2('receive', sockets(2));
        bciMsg = matlabUDP2('receive', bciSockets.receiver);
    end
    bciMsg = '';
    disp('Communicating with BCI');
    
    if params.bciCursorEnabled
        bciCursorTraj = [];
    end
    
    % send bci paramater file that will be used--not 100% clear whether I
    % want this here or in the stim file... but I'm coming around to
    % wanting it here
    %bciSocket.sender = sockets(2);
    %bciSocket.receiver = sockets(2);
    %sendMessageWaitAck(bciSocket, 'readyBciParamFile');
    %sendMessageWaitAck(bciSocket, xmlParams.bciDecoderParamFile);
    %sendMessageWaitAck(bciSocket, params.SubjectID);
    sendMessageWaitAck(bciSockets, 'readyBciParamFile');
    sendMessageWaitAck(bciSockets, xmlParams.bciDecoderParamFile);
    sendMessageWaitAck(bciSockets, params.SubjectID);

end

%% Initialize Sound Functionality
if params.soundEnabled
    PsychPortAudio('close');
    InitializePsychSound(1);
    audioHandle = PsychPortAudio('Open', [], 1, 2, params.sampleFreq, 2, [], 10 / 1000);
    PsychPortAudio('FillBuffer', audioHandle, zeros(2, params.outBufferSize));
end

%% tell showex the display screenDistance and pixPerCM
msg('screen %f %f',[params.screenDistance, params.pixPerCM]);

%% tell showex where the diode should be
msg('diode_setup %d %d %d %d',params.diodeLoc);

%% set defaults / more initialization

calibration = [];

% initialize variables for storing trial codes and behavior data:
allCodes = cell(0); % for storing the all the trial codes and results
behav = struct(); % behav is a struct for user data to be written by the ex-files
behav.frameDrop = [];
trialCodes = cell(length(expt),1);
for i = 1:length(expt)
    trialCodes{i} = cell(0);
end

%set 'params' defaults:
if ~isfield(params,'randomizeCalibration'), params.randomizeCalibration = false; end %whether or not to present the calibration positions in a random order. -ACS 03Sep2013

%trial control variables:
eyeHistory = nan(params.eyeHistoryBufferSize,3); %3 cols are x, y, time
eyeHistoryCurrentPos = 1;
currentBlock = 1;
pauseFlag = false;
if repeats > 0 % if repeats > 0 the user passed it in at the command line, otherwise use what the XML file says
    xmlParams.rpts = repeats;
end

%eParams defaults: -ACS 23Oct2012
if ~isfield(xmlParams,'nStimPerFix'),xmlParams.nStimPerFix=1;end
if ~isfield(xmlParams,'blockRandomize'),xmlParams.blockRandomize=true;end
if ~isfield(xmlParams,'conditionFrequency'),xmlParams.conditionFrequency='uniform';end
if ~isfield(xmlParams,'numBlocksPerRandomization'),xmlParams.numBlocksPerRandomization=1;end
if ~isfield(xmlParams,'exFileControl'),xmlParams.exFileControl='no';end
if ~isfield(xmlParams,'badTrialHandling'),xmlParams.badTrialHandling='reshuffle';end %options are 'noRetry','immediateRetry','reshuffle','endOfBlock'

%retry defaults: -ACS 19Dec2012
%By default, the condition is retried for every outcome except 'correct',
%'withhold' (assuming that means a correct withhold), and 'saccade' (e.g.,
%for a microstim paradigm). Each field of 'retry' should be the name of a
%field in the 'codes' global variable that is used as a result code by the
%ex files. -ACS
retry = struct('CORRECT',       0,...
    'IGNORED',       1,...
    'BROKE_FIX',     1,...
    'BROKE_TARG',    1,...
    'NO_CHOICE',     1,...
    'BROKE_PURSUIT', 1,...
    'SACCADE',       0,...
    'WRONG_TARG',    1,...
    'BROKE_TASK',    0,...
    'MISSED',        1,...
    'FALSEALARM',    1,...
    'WITHHOLD',      0,...
    'FALSE_START',   0,...               
    'CORRECT_REJECT',0,...                              
    'LATE_CHOICE',   0,...                              
    'SHOWEX_ABORT',  1,...
    'SHOWEX_TIMINGERROR',  1,...    
    'BCI_ABORT',     1,...
    'BCI_CORRECT',   0,...
    'BCI_MISSED',    1,...
    'BACKGROUND_PROCESS_TRIAL', 1);

allFields = fieldnames(xmlParams);
retryFields = cellfun(@cell2mat,regexp(allFields,'(?<=retry_)\w*','match'),'uniformoutput',0);
isRetryField = ~cellfun(@isempty,retryFields);
retryFields = retryFields(isRetryField);
for fx = 1:numel(retryFields)
    retry.(retryFields{fx}) = xmlParams.(['retry_' retryFields{fx}]);
end
availableOutcomes = fieldnames(retry);
stats = zeros(numel(availableOutcomes),1);

%Define standard prompt strings:
defaultRunexPrompt = '(s)timulus, set juice (n)umber, (c)alibrate, toggle (m)ouse mode, e(x)it';

setJuicePrompt = 'juice (x), juice (d)uration, juice (i)nterval, (q)uit';
calibrationInProgressPrompt = 'Calibrating...(g)ood position, (b)ack up, (q)uit, (j)uice, (r)efresh dot'; 
calibrationDonePrompt = '(f)inished calibration, (b)ack up, (q)uit, (j)uice';
runningPrompt = 'Running stimulus...(q)uit';

%% local directory information:
%Control-side data directory:
if isfield(params,'localDataDir')
    localDataDir = params.localDataDir;
    params = rmfield(params,'localDataDir');
else
    localDataDir = '~/exData';
end
if exist(localDataDir,'dir')==0 % try to create localDataDir if it doesn't exist
    if mkdir(localDataDir)>0
        warning('RUNEX:createdDataDir','Created directory %s for local data.',localDataDir);
        cleanUp();
        return;
    else
        warning('RUNEX:noDataDirCreated','Failed to create %s as the local data directory.',localDataDir);
        cleanUp();
        return;
    end
end
addpath(localDataDir); %add to search directory so outfiles can be found if needed... -ACS

%Networked or local status directory:
% if isfield(params,'localStatusDir'),
%     localStatusDir = params.localStatusDir;
%     params = rmfield(params,'localStatusDir');
% else
%     if ispc
%         localStatusDir = 'C:\exData\status';
%     else
%         localStatusDir = '~/exData/status';
%     end
%     warning('RUNEX:noStatusDir','Local status directory not specified. Using %s as the default.',localStatusDir);
% end;
% if exist(localStatusDir,'dir')==0 % try to create localStatusDir if it doesn't exist
%     if mkdir(localStatusDir)>0
%         warning('RUNEX:createdStatusDir','Created directory %s for local status.',localStatusDir);
%         cleanUp();
%         return;
%     else
%         warning('RUNEX:noStatusDirCreated','Failed to create %s as the local status directory. Invalid permissions may be the cause.',localStatusDir);
%         cleanUp();
%         return;
%     end
% end
% %initialize status info:
% statusInfo.path = localStatusDir;
% statusInfo.filename = fullfile(statusInfo.path,[params.machine,'.txt']);

%% Display-side local directory:
if isfield(params,'localShowexDir')
    localShowexDir = params.localShowexDir;
    params = rmfield(params,'localShowexDir');
else
    localShowexDir = '~/showexLocal';
    warning('RUNEX:noShowexDir','Local showex directory not specified. Using %s as the default.',localShowexDir);
end
%add the local showex directory if needed:
msgAndWait(sprintf('eval_str sv.localDir = ''%s'';',regexptranslate('escape',localShowexDir))); %store directory name in a variable in showex
msgAndWait('eval_str if ~logical(exist(sv.localDir,''dir'')), mkdir(sv.localDir); end;'); %check if the directory exists on the display side and create it if needed
msgAndWait('eval_str addpath(sv.localDir);'); %add the directory to the path on the display side

%% define default outfile name and turn on/off saving based on input param
[~,xmlname,~] = fileparts(xmlFile);
defaultoutfile=[params.SubjectID,'_',params.sessionNumber,'_',datestr(now, 'yyyy.mmm.DD.HH.MM.SS'),'_',xmlname,'.mat'];
if saveMat
    outfile=defaultoutfile;
    params.writeFile=true;
else
    outfile='noFileSaved';
    params.writeFile=false;
end

%% Declare window layout and open window for control computer display

%Screen Number Zero for Control Display
wins.screenNumber=0;

%find values for black and white:
white=WhiteIndex(wins.screenNumber);
black=BlackIndex(wins.screenNumber);
gray=(white+black)/2;
if round(gray)==white
    gray=black;
end

% get some basic info from the display
msg('framerate');
params.displayFrameTime = str2double(waitFor());
msg('resolution');
tstr = waitFor();
ts = textscan(tstr,'');
params.displayWidth = ts{1};
params.displayHeight = ts{2};
params.displayPixelSize = ts{3};
params.displayHz = ts{4};

%check the display and warn if it is not running at 100 Hz -acs28mar2017
if params.displayHz~=120
    ansr = questdlg(sprintf('Display is not running at 120Hz! Do you want to continue with the display at %dHz? (if not, press no or cancel and fix the display)',params.displayHz));
    switch lower(ansr(1))
        case 'y'
            %do nothing
        otherwise
            return; %punt
    end
end

% Open a double buffered fullscreen window
if fullScreen % this is the default
    [wins.w, wins.controlResolution] = Screen('OpenWindow',wins.screenNumber,gray);
else % this is not recommended due to worse timing/performance
    [wins.w, wins.controlResolution] = Screen('OpenWindow',wins.screenNumber, gray, [0 0 1035 621]);
end

% some default values for the control display only (no effect on subject display)
if fullScreen
    wins.textSize = 14;
    wins.lineSpacing = 1.6;
else
    wins.textSize = 12;
    wins.lineSpacing = 1.2;
end
wins.trialData.lines = 21; % max number of lines to show
wins.trialData.lineColor = zeros(wins.trialData.lines,3);
wins.trialData.subjectLine = 1;
wins.trialData.displayLine = 2;
wins.trialData.juiceLine = 3;
wins.trialData.trialLine = 4;
wins.trialData.promptLine = 5;
wins.trialData.statusLine = 6;
wins.trialData.outcomesLine = 7;
wins.trialData.userLine = 12;
wins.trialData.exPrintLines=wins.trialData.lines-wins.trialData.userLine+1;
wins.trialData.lineColor(wins.trialData.promptLine,:)=[102, 51, 153];
wins.trialData.lineColor(wins.trialData.statusLine,:)=[170, 51, 106];
wins.trialData.lineColor(wins.trialData.outcomesLine:wins.trialData.userLine-1,:)=repmat([50,50,50],wins.trialData.userLine - wins.trialData.outcomesLine,1);
wins.controlResolution = wins.controlResolution(3:4);
wins.displayResolution = [ts{1} ts{2}]; % from showex computer
wins.voltScale = 5000; % voltage display is +/- this value
wins.eyeDotRad = 5; % radius of eye position dot in pixels
wins.eyeTraceColor = [255 0 0]; % color of the eye position trace
wins.eyePosColor = [255 255 255]; % color of the eye position dot
wins.controlCalibDotRad = 5; % for the experimenter to see in runex
wins.controlCalibDotColor = [255 255 255];
if isfield(params,'calibDotSize') % so user can override voltScaledefault
    wins.displayCalibDotRad = params.calibDotSize;
else
    wins.displayCalibDotRad = 5; % for the subject to see via showex
end
wins.displayCalibDotColor = [255 255 255]; 

% Screen layout for the control display
cRes = wins.controlResolution;
dispRat = wins.displayResolution(2) / wins.displayResolution(1);
eyePortion = 0.5; % Top half of display is for eye windows, bottom for status
eyeMargin = 0.05; % Extra margin between info and eye displays
infoHorizontalPortion = 0.75; % Bottom-left of screen is for info
wins.voltageSize = ceil([0 0 cRes(2)*eyePortion cRes(2)*eyePortion]); 
wins.eyeSize = ceil([cRes(1)-1-((cRes(2)*eyePortion)/dispRat) 0 cRes(1)-1 cRes(2)*eyePortion]);
wins.infoSize = ceil([cRes(2)*eyeMargin cRes(2)*(eyePortion+eyeMargin) infoHorizontalPortion*cRes(1)-1 cRes(2)-1]);
wins.labNotesSize = ceil([infoHorizontalPortion*cRes(1)-1 + (1-infoHorizontalPortion)*eyeMargin cRes(2)*(eyePortion+eyeMargin) cRes(1)-1 cRes(2)-1]);

% Create the control display windows
wins.voltageDim = [0 0 wins.voltageSize(3:4)-wins.voltageSize(1:2)];
wins.eyeDim = [0 0 wins.eyeSize(3:4)-wins.eyeSize(1:2)];
wins.infoDim = [0 0 wins.infoSize(3:4)-wins.infoSize(1:2)];
wins.labNotesDim = [0 0 wins.labNotesSize(3:4)-wins.labNotesSize(1:2)];
[wins.voltage, vRect] = Screen('OpenOffscreenWindow',wins.w,gray,wins.voltageDim);
wins.voltageBG = Screen('OpenOffscreenWindow',wins.w,gray,wins.voltageDim);
wins.eye = Screen('OpenOffscreenWindow',wins.w,gray,wins.eyeDim);
[wins.eyeBG,  eRect] = Screen('OpenOffscreenWindow',wins.w,gray,wins.eyeDim);
wins.info = Screen('OpenOffscreenWindow',wins.w,gray,wins.infoDim);
wins.labNotes = Screen('OpenOffscreenWindow',wins.w,gray,wins.infoDim);

% scale factors to convert from eye tracker volts or full-screen
% pixel coordinates into the two control display screens
wins.pixelsPerVolt = [vRect(3) -vRect(4)]./(2*wins.voltScale); %NB: invert y coordinate because pixels increase from top to bottom but volts increase from bottom to top -acs01mar2016
wins.pixelsPerPixel = [eRect(3) eRect(4)]./wins.displayResolution;

wins.midV = [vRect(3)/2 vRect(4)/2];
wins.midE = [eRect(3)/2 eRect(4)/2];

%draws the radial circles and cross hairs for eye position
setWindowBackground(wins.voltageBG);
setWindowBackground(wins.eyeBG);

Screen('CopyWindow',wins.voltageBG,wins.voltage,wins.voltageDim,wins.voltageDim);
Screen('CopyWindow',wins.eyeBG,wins.eye,wins.eyeDim,wins.eyeDim);

%% initialize trialData and load appropriate default calibration:
trialData = cell(wins.trialData.lines,1);
exPrint = cell(wins.trialData.exPrintLines,1);
localCalibrationFilename = sprintf('%s_calibration.mat',params.machine);
localCalibrationFilename = fullfile(params.localExDir,'control',localCalibrationFilename);
if params.getEyes
    if params.writeFile
        [~,outfilename,outfileext] = fileparts(outfile);
        trialData{wins.trialData.subjectLine} = ['Subject: ' upper(params.SubjectID) ' - ' xmlFile ', Filename: ' outfilename outfileext];
    else 
        trialData{wins.trialData.subjectLine} = ['Subject: ' upper(params.SubjectID) ' - ' xmlFile ' ; NOT RECORDING DATA'];
        wins.trialData.lineColor(wins.trialData.subjectLine,:) = [150,0,0];
    end
    if exist(localCalibrationFilename,'file')
        load(localCalibrationFilename);
    else
        load mouseModeCalibration % use mouse mode calibration as default
    end
    samp;
else
    if params.writeFile
        [~,outfilename,outfileext] = fileparts(outfile);
        trialData{wins.trialData.subjectLine} = ['Subject: ' upper(params.SubjectID) ' - ' xmlFile ' (MOUSE MODE), Filename: ' outfilename outfileext];
    else
        trialData{wins.trialData.subjectLine} = ['Subject: ' upper(params.SubjectID) ' - ' xmlFile ' (MOUSE MODE); NOT RECORDING DATA'];
        wins.trialData.lineColor(wins.trialData.subjectLine,:) = [150,0,0];
    end
    load mouseModeCalibration
end

% make available the record prompt if we're writing output
if params.writeFile
    defaultRunexPrompt = '(s)timulus, set juice (n)umber, (c)alibrate, toggle (m)ouse mode, (r)ecord neural data, e(x)it';
end

trialData{wins.trialData.promptLine} = defaultRunexPrompt;
% show the display computer settings on the control computer screen
trialData{wins.trialData.displayLine} = sprintf('Display Settings: %d X %d @ %d Hz - %0.2f ms per frame',params.displayWidth,params.displayHeight,params.displayHz,params.displayFrameTime*1000);
trialData{wins.trialData.juiceLine} = sprintf('JUICEX = %d drops, JUICEDURATION = %d ms, JUICEINTERVAL= %d ms',params.juiceX,params.juiceTTLDuration,params.juiceInterval);

% This makes sure that the calibration values are stored with the
% data (via the sendStruct call)
params.calibPixX = calibration{1}(:,1)';
params.calibPixY = calibration{1}(:,2)';
params.calibVoltX = calibration{2}(:,1)';
params.calibVoltY = calibration{2}(:,2)';

%% define plotter timer function

plotter = timer;
plotter.ExecutionMode = 'fixedSpacing';
plotter.UserData = zeros(2,2);
plotter.Period = 0.03; % update the user display with the eye position every 30 ms
plotter.TimerFcn = {@plotDisplay};
plotter.UserData = mfilename;
plotter.ErrorFcn = {@timerDebugError};
start(plotter);

%% initialize display:
drawCalibration; %draw dots for all calibration points
Screen('CopyWindow',wins.voltageBG,wins.voltage,wins.voltageDim,wins.voltageDim);
drawTrialData();

% ask the display to change to the specified background color
msgAndWait('bg_color %d %d %d',xmlParams.bgColor);

%% Start a keyboard queue for user input
KbQueueCreate;
KbQueueStart;

%% save experiment run to database
% this needs to happen last, as it potentially requires drawing to the
% screen if there's a session number ambiguity
if useDatabase
    [params.sessionNumber, sessionNotes] = writeExperimentSessionToDatabase(sqlDb, params);
    disp(['Found session number ',num2str(params.sessionNumber),' in database']);
    notes = sessionNotes;
    if params.writeFile
        writeExperimentInfoToDatabase(params.sessionNumber, xmlParams, outfilename)
        notes = sprintf('%s\n%s\n', notes, outfilename);
        sqlDb.exec(sprintf('UPDATE experiment_session SET notes = "%s" WHERE session_number = %d AND animal = "%s"', notes, params.sessionNumber, params.SubjectID));
    end
end

%% Keyboard events handling loop:
while true
    % MATT - should setup KbQueue so it only detects keys that we
    % use, it's supposed to be faster. Doesn't matter here but
    % would be more important in the functions that run during a trial
    [ keyIsDown, keyCode] = KbQueueCheck;
    if keyIsDown && (~isempty(typingNotes) && ~typingNotes)
        c = KbName(keyCode);
        KbQueueFlush;
        if numel(c)>1; continue; end %keyboard mash and other weirdness
        switch c
            case num2cell('0123456789')
                params.juiceX = str2double(c);
            case 'n'
                setJuice;   
            case 'a'
                %disabled for now: -ACS 06Nov2013
                %             automaticCalibration;
                %             save(localCalibrationFilename,'calibration');
                %             trialData{wins.trialData.promptLine} = defaultRunexPrompt;
                %             drawTrialData;
                %             FlushEvents;
            case 'c'
                calibrate; % see calibration subfunction below
            case 'j'
                giveJuice();
            case 'l'
                Screen('CopyWindow',wins.voltageBG,wins.voltage,wins.voltageDim,wins.voltageDim);
                Screen('CopyWindow',wins.eyeBG,wins.eye,wins.eyeDim,wins.eyeDim);
            case 'm'
                calibFile = toggleMouseMonkey;
                load(calibFile);
                drawCalibration; % draw all calibration points
                Screen('CopyWindow',wins.voltageBG,wins.voltage,wins.voltageDim,wins.voltageDim);
            case 's'
                % the BCI *requires* the NEV to be recorded (generally) so
                % we're ensuring that here...
                if params.bciEnabled && ~recordingTrueFalse
                    [recordingTrueFalse, defaultRunexPrompt] = exRecordExperiment(socketsDatComp, recordingTrueFalse, xmlParams, outfilename, defaultRunexPrompt); % see recording subfunction that communicates with data computer
                end
                exRunExperiment; % see experimental control subfunction
            case 'r'
                if params.writeFile
                    try
                        [recordingTrueFalse, defaultRunexPrompt] = exRecordExperiment(socketsDatComp, recordingTrueFalse, xmlParams, outfilename, defaultRunexPrompt); % see recording subfunction that communicates with data computer
                    catch err
                        if strcmp(err.identifier, 'communication:waitForData:communicationFailWithDataComputer')
                            trialData{wins.trialData.statusLine} = err.message;
                            trialData{wins.trialData.promptLine} = defaultRunexPrompt;
                            drawTrialData();
                        else
                            rethrow(err)
                        end
                    end
                end
            case 'x'
                if params.writeFile
                    trialDataWriteOut = cellfun(@(x) char(x), trialData, 'uni', 0);
                    if ~isempty(sqlDb)
                        writeExperimentInfoToDatabase([], xmlParams, outfilename, 'experiment_results', strjoin(trialDataWriteOut([1:wins.trialData.userLine-1]), '\n'));
                        %writeExperimentInfoToDatabase([], xmlParams, outfilename, 'experiment_results', strjoin(trialDataWriteOut([2:3, 5:end]), '\n'));
                    end
                    % shut off recording
                    if recordingTrueFalse
                        try
                            [recordingTrueFalse, defaultRunexPrompt] = exRecordExperiment(socketsDatComp, recordingTrueFalse, xmlParams, outfilename, defaultRunexPrompt); % see recording subfunction that communicates with data computer
                        catch err
                            if strcmp(err.identifier, 'communication:waitForData:communicationFailWithDataComputer')
                                trialData{wins.trialData.statusLine} = err.message;
                                trialData{wins.trialData.promptLine} = defaultRunexPrompt;
                                drawTrialData();
                            else
                                error(err.identifier, err.message)
                            end
                        end
                    end
                end
                
                break;
% This code could report timing errors for us, but need to work on it                
%                 try
%                     TimingTest(allCodes);
%                     break;
%                 catch ME
%                     break;
%                     rethrow(ME);
%                 end
        end
    end
end

%% Clean up on exit:

% clear persistent variables
clear( xmlParams.exFileName )

% Reset Priority and Verbosity, close sound
cleanUp();

% Helpful info to show the performance on the control computer is good
pp = get(plotter,'AveragePeriod');
fprintf('\nAverage plotDisplay plotter period was %0.4f s (%0.4f s requested)\n',pp,plotter.Period);
stop(plotter);
clear plotter;

Screen('CloseAll');

if params.bciEnabled
    matlabUDP2('send', bciSockets.sender, 'bciEnd')
end

matlabUDP2('all_close');

% for n= 1:length(sockets)
%     matlabUDP2('close',sockets(n)); %NB: Does this matlapUDP call close/affect the xippmex socket??
% end

if isfield(behav,'xippmexInitialized')&&behav.xippmexInitialized 
    %check if the current behav struct expects xippmex to be initialized... -ACS 14Jul2015
    status = xippmex; %Initialize if needed... -ACS 14Jul2015
    if status~=1
        warning('RUNEX:xippmexReinitializeFailure','Unable to re-initialize xippmex on close...'); 
        behav.xippmexInitialized = false; %correct the flag to reflect reinitialization error.
    end
end

KbQueueRelease;

fclose all;

%if exist(statusInfo.filename,'file'),
%    delete(statusInfo.filename);
%end;

%% SUBROUTINES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% The actual running of the experiment (a.k.a., the "Big Kahuna"):
    function exRunExperiment
        persistent ordering trialCounter %keep the value of ordering persistent, needed when this moved to subfunction. -ACS 13Sep2013
        try
            % set the background color here
            msgAndWait('bg_color %d %d %d',xmlParams.bgColor);            
            
            % set the trialTic here and initialize thisTrialCodes so that this
            % first sendStruct call has valid times and stores the codes
            % properly. the flag keeps us from resetting the tic below for just
            % this one trial
            trialTic = tic;
            thisTrialCodes = [];
            resetTicFlag = 0;
            sendStruct(exCatstruct(xmlParams,params,'sorted'));
            matlabUDP2('send', sockets(1),'stim');
            
            trialMessage = 0;
            
            if currentBlock > xmlParams.rpts
                currentBlock = 1;
            end
            
            for j = currentBlock:xmlParams.rpts
                
                if ~pauseFlag
                    ordering = createOrdering(expt,...
                        'blockRandomize',xmlParams.blockRandomize,...
                        'conditionFrequency',xmlParams.conditionFrequency,...
                        'numBlocksPerRandomization',xmlParams.numBlocksPerRandomization,...
                        'exFileControl',xmlParams.exFileControl); %-ACS 23Oct2012
                    trialCounter = 1;
                end
                if any(ordering<1), ordering = []; break; end %break loop for any ordering less than one (e.g., from EX file control) -ACS 23Oct2012 %changed to ordering<1 rather than <0 -ACS 03Sep2013
                
                abortCounter = 0;
                while ~isempty(ordering)
                    if any(ordering<1), ordering = []; break; end
                    cnd = ordering(1:min(xmlParams.nStimPerFix,numel(ordering)));
                                       
                    % only set the trialTic for trials that aren't immediately
                    % following the 's' command
                    if resetTicFlag
                        trialTic = tic;
                        thisTrialCodes = [];
                    else
                        resetTicFlag = 1;
                    end

                    if exist('trialResultStrings','var')
                        trialData{wins.trialData.trialLine} = [sprintf('Session %i, ',params.sessionNumber),sprintf('Block %i/%i, ',j,xmlParams.rpts),sprintf('Trial %i/%i, Condition(s) ',trialCounter,length(ordering)+trialCounter-1) sprintf('%i ',cnd),sprintf('   *Previous Trial Outcome =  %s *',char(trialResultStrings(end)))];
                    else
                        trialData{wins.trialData.trialLine} = [sprintf('Session %i, ',params.sessionNumber),sprintf('Block %i/%i, ',j,xmlParams.rpts),sprintf('Trial %i/%i, Condition(s) ',trialCounter,length(ordering)+trialCounter-1) sprintf('%i ',cnd)];
                    end
                    trialData{wins.trialData.promptLine} = runningPrompt;
                    drawTrialData();
                    
                    % setup the allCodes struct for this trial
                    allCodes{end+1} = struct(); %#ok<AGROW>
                    % This value should be as close as possible to the time
                    % that code 1 is sent, thus allowing us to recreate global
                    % time.
                    allCodes{end}.startTime = datestr(now,'HH.MM.SS.FFF');
                    sendCode(codes.START_TRIAL);
                    
                    % e needs to be a cell array or struct array  *****
                    e = expt(cnd);
                    
                    %                     if isfield(e{1},'bgColor'), %change the bg_color for this trial (set of stimuli)...
                    %                         msg('bg_color %d %d %d',e{1}.);
                    %                     end;
                    fn = fieldnames(xmlRand);
                    for e_indx = 1:length(e)
                        for f = 1:length(fn)
                            fieldName = fn{f};
                            val = xmlRand.(fieldName);
                            val = val(randi(length(val)));
                            e{e_indx}.(fieldName) = val;
                        end
                    end
                    e = cell2mat(e);
                    
                    % send the trial parameters here, before adding
                    % eParams to e (because eParams were sent already)
                    % loop over nstim
                    for I =1:numel(cnd)
                        sendCode(cnd(I)+32768); % send condition # in 32769-65535 range
                        sendStruct(e(I));
                    end
                    
                    e = num2cell(e);
                    for I = 1:numel(e)
                        e{I} = exCatstruct(xmlParams,e{I});
                        e{I}.('currentBlock')=j;
                        e{I}.('currentCnd')=cnd(I);
                        e{I}.trialCounter = trialCounter;
                        e{I}.ordering = ordering;
                    end
                    e = cell2mat(e);
                    
                    % if desired, send an alignment pulse out the digital
                    % port here
                    if params.alignPulseEnabled
                        unixSendPulse(params.alignPulseChan,params.alignPulseDuration);
                    end                    
                    
                    try
                        if isfield(e,'juiceX')
                            params.juiceX = e(1).juiceX;
                        end
                        trialResult = feval(e(1).exFileName,e); % CALLING THE EX FILE
                        
                        msgAndWait('checkForAborts'); %just to check for aborts.
                    catch ME %This block handles the cases when showex aborts...
                        %%% just throw it right away for now MS August 2021
                        %msgAndWait('prerethrow')
                        rethrow(ME); %kicks up to runexError function
                        %msgAndWait('postrethrow')
                        switch ME.identifier
                            case 'waitFor:aborted'
                                sendCode(codes.SHOWEX_ABORT);
                                trialMessage = 0;
                                trialResult = codes.SHOWEX_ABORT;
                                abortCounter = abortCounter+1;
                                if abortCounter>10
                                    %kick up to higher-level try/catch to exit gracefully
                                    error('RUNEX:tooManyAborts','Too many consecutive aborts'); 
                                end
                                msgAndWait('resume');
                            case 'exFunction:bci_aborted'
                                sendCode(codes.BCI_ABORT);
                                trialMessage = 0;
                                trialResult = codes.BCI_ABORT;
                                sendCode(codes.END_TRIAL); % send an official end trial code so that BCI analysis is able to sync the trial numbers
                                error('RUNEX:bciAbort','BCI computer is not responding');
                            otherwise %some error other than an abort
                                rethrow(ME); %kicks up to runexError function
                        end
                    end
                    
                    %Scoring:
                    
                    trialResult(trialResult==1) = codes.CORRECT; %for backwards compatibility -ACS 23Oct2012
                    trialResult(trialResult==2) = codes.BROKE_FIX; %for backwards compatibility
                    trialResult(trialResult==3) = codes.IGNORED; %for backwards compatibility
                    trialResultStrings = exDecode(trialResult(:));
                    
                    % Copy the exPrint data (meant to be written from
                    % within an ex function) into trialData so it's printed
                    % first some argument checking
                    % should we also make sure there are no numeric values?
                    if size(exPrint,2)~=1
                        warning('exPrint must be Nx1 - runex is overwriting it to avoid an error');
                        exPrint = cell(wins.trialData.exPrintLines,1);
                    elseif size(exPrint,1)>wins.trialData.exPrintLines
                        warning('The size of the exPrint cell array was increased - runex is trimming it to avoid an error');
                        exPrint = exPrint(1:wins.trialData.exPrintLines,1);
                    elseif size(exPrint,1)<wins.trialData.exPrintLines
                        warning('The size of the exPrint cell array was reduced - runex is overwriting it to avoid an error');
                        exPrint = cell(wins.trialData.exPrintLines,1);
                    end
                    % trialData user lines get exPrint copied in so it will print
                    trialData(wins.trialData.userLine:wins.trialData.lines) = exPrint;
                    
                    for ox = 1:numel(availableOutcomes) %new scoring -ACS 23Oct2012
                        if retry.(availableOutcomes{ox})
                            stats(ox) = stats(ox)+any(ismember(trialResultStrings,availableOutcomes{ox})); %only count these once per fix
                        else
                            stats(ox) = stats(ox)+sum(ismember(trialResultStrings,availableOutcomes{ox})); %sum these per fix
                        end
                        nOutcomesPerLine = 5; %for display purposes...
                        currentLine = wins.trialData.outcomesLine+floor((ox-1)/nOutcomesPerLine);
                        if mod(ox,nOutcomesPerLine)==1
                            trialData{currentLine}=sprintf('%i %s',stats(ox),availableOutcomes{ox});
                        else
                            trialData{currentLine} = [trialData{currentLine} sprintf(', %i %s',stats(ox),availableOutcomes{ox})];
                        end
                    end
                    
                    msg('all_off');
                    msgAndWait('rem_all');
                    
                    if trialMessage>-1
                        checked = false(size(cnd));
                        for ox = 1:numel(trialResultStrings)
                            checked(ox) = ~retry.(trialResultStrings{ox});
                        end
                        if any(checked)
                            trialCounter = trialCounter+sum(checked);
                            for cx = 1:numel(cnd)      %Not sure this is functioning in the intended way yet... -ACS
                                trialCodes{cnd(cx)}{end+1} = thisTrialCodes;
                            end
                        end
                        switch xmlParams.badTrialHandling %added 23Oct2012 -ACS
                            case 'noRetry' %don't retry bad trials
                                ordering(1:numel(cnd)) = []; %just erase the current cnd from ordering and don't look back...
                            case 'immediateRetry'
                                ordering(find(checked)) = []; %tick off the good trials and feed back the ordering as is. This option really only makes sense if nStimPerFix==1.
                            case 'reshuffle'
                                ordering(find(checked)) = []; %tick off the good trials
                                ordering = ordering(randperm(numel(ordering))); %reshuffle the remaining conditions
                            case 'endOfBlock'
                                needsRetried = ordering(find(~checked)); %trials that haven't been checked off
                                ordering = [ordering(numel(cnd)+1:end) needsRetried]; %take the conditions that haven't been attempted yet, and add the conditions needing another try to the end
                            otherwise
                                error('RUNEX:unknownBadTrial','Unrecognized option for badTrialHandling, quit to diagnose.'); %kicks up to runexError
                        end
                    end

                    msgAndWait('ack'); % sync up before ending the trial
                    sendCode(codes.END_TRIAL);
                    
                    % Global history of trial codes
                    %
                    % NOTE: These codes are all referenced relative to the time
                    % of the trial start (code '1') because of the first line
                    % below. The "global time" for the start of each trial is
                    % stored in allCodes.startTime
                    thisTrialCodes(:,2) = thisTrialCodes(:,2) - thisTrialCodes(find(thisTrialCodes(:,1)==1,1,'first'),2);
                    allCodes{end}.cnd = cnd;
                    allCodes{end}.trialResult = trialResult;
                    allCodes{end}.codes = thisTrialCodes;
                    
                    % Write allCodes to a file to keep track of data on Ex side
                    % Can use the behav struct to keep track of behavior if you
                    % like. Contents of behav are user-defined in ex-functions
                    if params.writeFile
                        save(fullfile(localDataDir,outfile),'allCodes','behav','exFileText','xmlParams','-v6'); % '-v6' for speed -MAS 27Feb2016
                    end
                    
                    if trialMessage == -1
                        break;
                    end
                end
                
                if trialMessage == -1
                    currentBlock = j;
                    pauseFlag = true;
                    break;
                else
                    pauseFlag = false;
                end
                currentBlock = currentBlock + 1;
            end
            matlabUDP2('send',sockets(1), 'q');
            trialData{wins.trialData.promptLine} = defaultRunexPrompt;
            drawTrialData();
        catch err %Graceful error handling within runex
            trialData{wins.trialData.promptLine} = defaultRunexPrompt;
            trialData{wins.trialData.statusLine} = sprintf('Error: %s. Quit to diagnose.', err.message);
            trialMessage = -1;
            msg('all_off');
            drawTrialData();
            disp(['************ ERROR: ' err.message ' **********']);
            for stk = 1:length(err.stack)
                fprintf('In ==> %s %s %i\n',err.stack(stk).file,err.stack(stk).name,err.stack(stk).line);
            end
            % shut off BCI
            if params.bciEnabled
                matlabUDP2('send', bciSockets.sender, 'bciEnd')
            end

            % shut off recording
            if params.writeFile
                if recordingTrueFalse
                    try
                        [recordingTrueFalse, defaultRunexPrompt] = exRecordExperiment(socketsDatComp, recordingTrueFalse, xmlParams, outfilename, defaultRunexPrompt); % see recording subfunction that communicates with data computer
                    catch err
                        if strcmp(err.identifier, 'communication:waitForData:communicationFailWithDataComputer')
                            trialData{wins.trialData.statusLine} = err.message;
                            trialData{wins.trialData.promptLine} = defaultRunexPrompt;
                            drawTrialData();
                        else
                            error(err.identifier, err.message)
                        end
                    end
                end

            end
            beep;
        end
    end

%% setJuice
    function setJuice
        trialData{wins.trialData.promptLine} = setJuicePrompt;
        drawTrialData();
        while true
            [ keyIsDown, keyCode] = KbQueueCheck;
            if keyIsDown && (~isempty(typingNotes) && ~typingNotes)
                c = KbName(keyCode);
                KbQueueFlush;
                switch c
                    case 'x'
                        trialData{wins.trialData.promptLine} = 'Press the number of juice drops, then the SPACE bar.';
                        drawTrialData();
                        theparam = getParams;
                        if ~isnan(theparam)
                            params.juiceX = theparam;
                        end
                        trialData{wins.trialData.promptLine} = setJuicePrompt;
                        trialData{wins.trialData.juiceLine} = sprintf('JUICEX = %d drops, JUICEDURATION = %d ms, JUICEINTERVAL= %d ms',params.juiceX,params.juiceTTLDuration,params.juiceInterval);
                        drawTrialData();
                    case 'd'
                        trialData{wins.trialData.promptLine} = 'Press the duration of juice drops (in milliseconds), then the SPACE bar.';
                        drawTrialData();
                        theparam = getParams;
                        if ~isnan(theparam)
                            params.juiceTTLDuration = theparam;
                        end
                        trialData{wins.trialData.juiceLine} = sprintf('JUICEX = %d drops, JUICEDURATION = %d ms, JUICEINTERVAL= %d ms',params.juiceX,params.juiceTTLDuration,params.juiceInterval);
                        trialData{wins.trialData.promptLine} = setJuicePrompt;
                        drawTrialData();
                    case 'i'
                        trialData{wins.trialData.promptLine} = 'Press the interval between juice drops (in milliseconds), then the SPACE bar.';
                        drawTrialData();
                        theparam = getParams;
                        if ~isnan(theparam)
                            params.juiceInterval = theparam;
                        end
                        trialData{wins.trialData.juiceLine} = sprintf('JUICEX = %d drops, JUICEDURATION = %d ms, JUICEINTERVAL= %d ms',params.juiceX,params.juiceTTLDuration,params.juiceInterval);
                        trialData{wins.trialData.promptLine} = setJuicePrompt;
                        drawTrialData();
                    case 'q'
                        break;
                end
            end
        end
        trialData{wins.trialData.promptLine} = defaultRunexPrompt;
        drawTrialData();
    end
% how to detect enter
    function theparam = getParams
        c = '';
        while true
            [ keyIsDown, keyCode] = KbQueueCheck;
            keyCode = find(keyCode, 1);
            if keyIsDown && (~isempty(typingNotes) && ~typingNotes)                
                if keyCode == 66 % space bar
                    break;
                end
                n = KbName(keyCode);
                c = [c,n(1)];
                KbReleaseWait;
            end
        end
        theparam = str2double(c);
        disp(c);
    end
        
%% Calibration:
    function calibrate
        msg(sprintf('eval_str sv.localDir = ''%s'';',regexptranslate('escape',localShowexDir))); %store directory name in a variable in showex
        msgAndWait('ack');
        
        trialData{wins.trialData.promptLine} = calibrationInProgressPrompt;
        drawTrialData();
        
        setWindowBackground(wins.voltageBG);
        Screen('CopyWindow',wins.voltageBG,wins.voltage,wins.voltageDim,wins.voltageDim);
        
        x = params.calibX;
        y = params.calibY;
        
        [posX, posY] = meshgrid(x,y);
        posX = posX';
        posY = posY';
        posX = posX(:);
        posY = posY(:);
        
        %A couple tools so that the calibration points can be displayed in
        %a random order:
        posPointer = 1:numel(posX);
        if params.randomizeCalibration
            posShuffle = randperm(numel(posPointer));
        else
            posShuffle = 1:numel(posPointer);
        end
        % points always get stored in the calibration cell array in the canonical order        
        [~,posSort] = sort(posShuffle,'ascend'); 
        
        pt = 1;
        lastPt = 0;
        while true 
            if (pt ~= lastPt) && ~(pt > length(posX)) %point changed, update image
                if isfield(params,'fixpic')&&any(params.fixpic)
                    thisPic = params.fixpic(randi(numel(params.fixpic)));
                    matlabUDP2('send', sockets(1),sprintf('set 1 movie fixpics/fixpic%i 0 1 1 %i %i',[thisPic posX(posShuffle(pt)),posY(posShuffle(pt))])); %changed to shuffle -
                else
                    matlabUDP2('send', sockets(1),sprintf('set 1 oval 0 %i %i %i %i %i %i',[posX(posShuffle(pt)),posY(posShuffle(pt)),wins.displayCalibDotRad,wins.displayCalibDotColor])); %changed to shuffle -
                end
                matlabUDP2('send',sockets(1), 'all_on');
                trialData{wins.trialData.promptLine} = calibrationInProgressPrompt;
                drawTrialData();
                lastPt = pt;
            elseif (pt ~= lastPt) && (pt > length(posX)) %last pt
                matlabUDP2('send',sockets(1), 'all_off');
                trialData{wins.trialData.promptLine} = calibrationDonePrompt;
                drawTrialData();
                lastPt = pt;
            end
            samp; % make sure the eyeHistory buffer gets filled with recent samples
            [ keyIsDown, keyCode] = KbQueueCheck;
            if keyIsDown && (~isempty(typingNotes) && ~typingNotes)
                c = KbName(keyCode);
                KbQueueFlush;
                if numel(c)>1, continue; end
                if pt > length(posX) %all positions have been marked as good.                    
                    if c == 'f'
                        %Reorder the calibration to the 'canonical' order in case any
                        %subsequent routines are assuming that for some reason:
                        calibration{1} = calibration{1}(posSort,:);
                        calibration{2} = calibration{2}(posSort,:);
                        % This makes sure that the calibration values are stored with the
                        % data (via the sendStruct call)
                        params.calibPixX = calibration{1}(:,1)';
                        params.calibPixY = calibration{1}(:,2)';
                        params.calibVoltX = calibration{2}(:,1)';
                        params.calibVoltY = calibration{2}(:,2)';
                        % do the linear regression of Pixels vs. Voltage
                        calibration{3} = regress(calibration{1}(:,1), [calibration{2} ones(size(calibration{2},1),1)]);
                        calibration{4} = regress(calibration{1}(:,2), [calibration{2} ones(size(calibration{2},1),1)]);
                        calibration{5} = regress(calibration{2}(:,1), [calibration{1} ones(size(calibration{1},1),1)]);
                        calibration{6} = regress(calibration{2}(:,2), [calibration{1} ones(size(calibration{1},1),1)]);
                        save(localCalibrationFilename,'calibration');
                        break;
                    end
                else %not all the positions have been marked as good yet
                    switch c
                        case 'g'
                            d = samp;
                            % will be reordered when calibration is complete
                            calibration{1}(pt,:) = [posX(pt) posY(pt)];
                            calibration{2}(pt,:) = d(end,:);
                            drawCalibration(pt);
                            Screen('CopyWindow',wins.voltageBG,wins.voltage,wins.voltageDim,wins.voltageDim);
                            pt = pt + 1;
                            giveJuice();
                        case 'r' % flash the dot off for 0.25 seconds
                            matlabUDP2('send', sockets(1),'obj_off 1');
                            pause(.25);
                            matlabUDP2('send', sockets(1),'obj_on 1');
                    end
                end
                switch c
                    case 'b'
                        setWindowBackground(wins.voltageBG);
                        pt = max(1,pt - 1);
                        drawCalibration(pt-1);
                        Screen('CopyWindow',wins.voltageBG,wins.voltage,wins.voltageDim,wins.voltageDim);
                    case 'c'
                        Screen('CopyWindow',wins.voltageBG,wins.voltage,wins.voltageDim,wins.voltageDim);
                        Screen('CopyWindow',wins.eyeBG,wins.eye,wins.eyeDim,wins.eyeDim);
                    case 'j'
                        giveJuice;
                    case'q'
                        if params.getEyes
                            if exist(localCalibrationFilename,'file')
                                a = load(localCalibrationFilename);
                            else
                                a = load('calibration');
                            end
                        else
                            a = load('mouseModeCalibration');
                        end
                        calibration = a.calibration;
                        setWindowBackground(wins.voltageBG);
                        drawCalibration(size(calibration{1},1));
                        Screen('CopyWindow',wins.voltageBG,wins.voltage,wins.voltageDim,wins.voltageDim);
                        break;
                end %end switch c
            end
        end %end while true
        trialData{wins.trialData.promptLine} = defaultRunexPrompt;
        drawTrialData();
        matlabUDP2('send',sockets(1), 'all_off');
    end
    
    %% Toggle between mouse and monkey mode:
    function loadVar = toggleMouseMonkey
        if params.getEyes
            samp(-4);
            mmString = ' (MOUSE MODE)';
            loadVar =  'mouseModeCalibration';
        else
            samp;
            mmString = '';
            if exist(localCalibrationFilename,'file')
                loadVar = localCalibrationFilename;
            else
                loadVar = 'calibration';
            end
        end
        
        params.getEyes = ~params.getEyes;
        if params.writeFile
            [~,outfilename,outfileext] = fileparts(outfile);
            trialData{1} = sprintf('Subject: %s - %s%s, Filename: %s%s',upper(params.SubjectID),xmlFile,mmString,outfilename,outfileext);
        else
            trialData{1} = sprintf('Subject: %s - %s%s; NOT RECORDING DATA', upper(params.SubjectID), xmlFile, mmString);
        end
        drawTrialData();
        setWindowBackground(wins.voltageBG);
    end


%%
    function cleanUp()
        Priority(origPriority);
        Screen('Preference', 'Verbosity', origVerbosity);
        if isfield(params,'soundEnabled')&&params.soundEnabled
            PsychPortAudio('Close')
        end
    end

end

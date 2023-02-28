function result = ex_MultiFlashGoNoGo6b(e)
% ex file: ex_MultiFlashGoNoGo2
% 6/10/19 PS: Changed intFlashInt to be different on each flash (not just
% each trial), changed object setup to take in more than 1 color
%
% ex_MultiFlashGoNoGo6b
% added helper target option
% 6/25/21 changed e.sacWinR to params.sacWinRad and e.fixWinR to
% params.fixWinRad
% 6/28/21 added recenter flag after fixate and initial fix window 2x
% fixWinRad
% 7/2/21 added wait until exit fixation window before starting next trial

global params codes behav allCodes;

e = e(1); %in case more than one 'trial' is passed at a time...
msgAndWait('ack1');
% hard-coded number of noise stimuli
nNoise = 5;

%initialize behavior-related stuff:
if ~isfield(behav,'goodTrials')
    behav.goodTrials = 0; %only CORRECT or MISSED
    behav.blockCounter = 1;
    behav.storeBlock = [];
    behav.currentBlock = e.blockOrder(1);
    
    %reformat and get params for this current block type
    contexts = cellfun(@str2num,regexp(e.contexts,'/','split'),'UniformOutput',0);
    contexts = contexts{behav.currentBlock};
    samples = cellfun(@str2num,regexp(e.samples,'/','split'),'UniformOutput',0);
    samples = samples{behav.currentBlock};
    targets = cellfun(@str2num,regexp(e.targets,'/','split'),'UniformOutput',0);
    targets = targets{behav.currentBlock};
    
    %create matrix for pseudo-randomized conditions
    trialMat = combvec(contexts,samples,targets);
    reps = e.trialsPerBlock(behav.currentBlock)/size(trialMat,2);%how many reps will be in this block
    behav.trialMatrix = repmat(trialMat,1,reps);
    behav.randOrder = randsample(size(behav.trialMatrix,2),size(behav.trialMatrix,2))';
    if size(behav.randOrder,2) ~= e.trialsPerBlock(behav.currentBlock)
        error('unequal number of reps per condition, check trialsPerBlock')
    end
end
blockList= repmat(e.blockOrder',1,50);

%change block, get all new params and conditions
if behav.goodTrials==e.trialsPerBlock(behav.currentBlock)
    behav.goodTrials = 0;
    behav.blockCounter = behav.blockCounter+1;
    behav.currentBlock = blockList(behav.blockCounter);
    
    contexts = cellfun(@str2num,regexp(e.contexts,'/','split'),'UniformOutput',0);
    contexts = contexts{behav.currentBlock};
    samples = cellfun(@str2num,regexp(e.samples,'/','split'),'UniformOutput',0);
    samples = samples{behav.currentBlock};
    targets = cellfun(@str2num,regexp(e.targets,'/','split'),'UniformOutput',0);
    targets = targets{behav.currentBlock};
    
    trialMat = combvec(contexts,samples,targets);
    reps = e.trialsPerBlock(behav.currentBlock)/size(trialMat,2);%how many reps will be in this block
    behav.trialMatrix = repmat(trialMat,1,reps);
    behav.randOrder = randsample(size(behav.trialMatrix,2),size(behav.trialMatrix,2))';
    if size(behav.randOrder,2) ~= e.trialsPerBlock(behav.currentBlock)
        error('unequal number of reps per condition, check trialsPerBlock')
    end
end

%get specific values for this trial
t=behav.randOrder(1);%the params index for this trial
behav.randOrder(1) = []; %move this condition to the end
behav.randOrder = [behav.randOrder t]; %will remove it later if trial completed
context = behav.trialMatrix(1,t);
sample = behav.trialMatrix(2,t);
target = behav.trialMatrix(3,t);
morphs = cellfun(@str2num,regexp(e.CmorphAngle,'/','split'),'UniformOutput',0);
morphAngle = morphs{context}(target);
sendStruct(struct('trialContext',context))
sendStruct(struct('trialSample',sample))
sendStruct(struct('trialTarget',target))
sendStruct(struct('morphAngle',morphAngle))
sendStruct(struct('currentBlock',behav.currentBlock))
behav.storeBlock = [behav.storeBlock behav.currentBlock];

% % take radius and angle and figure out x/y for saccade direction
% theta = deg2rad(e.angle);
% newX = round(e.stimX*cos(theta))+e.fixX;
% newY = round(e.stimY*sin(theta))+e.fixY;

%saccade direction relative to fixation
newX = e.stimX+e.fixX;
newY = e.stimY+e.fixY;

% obj 1 is fix spot, obj 7 is sample, obj 8 is target
msgAndWait('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY params.fixRad e.fixColor(1) e.fixColor(2) e.fixColor(3)]);

%for displaying image
sampleString = [e.imgLoc,filesep,sprintf('img%i',sample),'.mat'];
msgAndWait(sprintf('set 7 movie_morph %s 0 1 1 %i %i %i 0 0 %i',sampleString,[newX newY],e.aperture,e.imgDisplaySize));
msgAndWait(sprintf('set 8 movie_morph %s 0 1 1 %i %i %i %i %i %i',sampleString,[newX newY],e.aperture,context,morphAngle,e.imgDisplaySize));

% obj 5 is gray center, obj 6 is helper target
if e.htOn ==1
%     hsvC = rgb2hsv(e.htColor);
%     syms f(x)
%     f(x)=(hsvC(3)-128/hsvC(2))*x+128;
%     hsvC(2)=hsvC(2)*e.htPercColor;
%     hsvC(3)=f(hsvC(2));
%     hsvC(2) = hsvC(2)-hsvC(2)*(1-e.htPercColor/100);
%     hsvC(3) = hsvC(3)-hsvC(3)*(1-e.htPercColor/100);
%     htC = hsv2rgb(hsvC);
    htC = e.htColor;
    msg('set 5 oval 0 %i %i %i %i %i %i',[newX newY e.htRad 125 125 125]);
    msg('set 6 oval 0 %i %i %i %i %i %i',[newX newY e.htRad htC(1) htC(2) htC(3)]);
end

%%%%4/8/21 if want to add noise again, will need to check obj number so no
%%%%overlap with helper target
% %if want to add noise to image
% if e.addNoise==1
%     seed = e.seed;
%     for n=2:nNoise+1 %create nNoise different noise filters store as obj 2-6     
%         ttt=[0 round(e.aperture/e.noiseN*2) e.noiseN 255 255 255 e.alpha 0 0 0 e.alpha seed 0 newX newY e.aperture];
%         msg(sprintf('set %i squarecheck %i %i %i %f %f %f %f %f %f %f %f %i %i %i %i %i %i',n,ttt));
%         seed = seed+1;
%     end
% end

msgAndWait(['diode 7 8']); % diode flashes for both sample and target

msgAndWait('ack2');

%turn the cue (fixation point) on
pause(e.ITI/1000);
msgAndWait('obj_on 1');

unixSendPulse(19,10); % added to send a pulse aligned with fix_on 01/18/22 - DI

sendCode(codes.FIX_ON);

%test whether looked in fixation window
if ~waitForFixation(e.timeToFix,e.fixX,e.fixY,params.fixWinRad*1.5)
    % failed to achieve fixation
    sendCode(codes.IGNORED);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e.noFixTimeout);
    result = codes.IGNORED;
    return;
end
sendCode(codes.FIXATE);

%if ~waitForMS(e.stimOnsetDelay,currentPos(1),currentPos(2),params.fixWinRad)
if ~waitForMS(e.stimOnsetDelay,e.fixX,e.fixY,params.fixWinRad*1.5)
    % hold fixation before stimulus comes on
    sendCode(codes.BROKE_FIX);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e.noFixTimeout);
    result = codes.BROKE_FIX;
    return;
end

%added 6/29/21 MAS/PLS
% get current eye position 
neyesamp = 10;
currentPos = nan(neyesamp,2);
for I=1:neyesamp
    currentPos(I,:) = samp;
end
currentPos = mean(currentPos);
currentPos = projectCalibration(currentPos(end,:));
%currentPos = currentPos+[-2,2];

%%%%%flash stim %%%%%%%%
%get number of flashes from hazard function
f=@(x) e.firstFlashProb*(1-e.firstFlashProb)^(x-1);
for i=1:e.maxFlash
    flash_probs(i) = f(i);
end
flashes = sum(rand >= cumsum([0, flash_probs]));

%added 1/16/20 PLS to allow to manually set flash distribution%%%%
if isfield(e,'manualFlash')
    flashes=e.manualFlash;
end
%%%%%%%%%%

sendCode(2000+flashes); %send code for how many flashes were supposed to be

%get random ISI
d=RandStream.create('mrg32k3a','seed',e.seed);
flash_list = randi(d,e.IFImax-e.IFImin,flashes,1)+e.IFImin;

%random list of noises
noiseList=[];
for n = 1:(ceil(flashes/nNoise)+1)
    noiseList = [noiseList randperm(nNoise,nNoise)];
end

for r = 1:flashes
    %set timeout
    timeout = e.breakFixTimeout-(r*e.stimDuration);
    timeout(timeout<e.stimDuration) = e.stimDuration;
    %turn on stim
    if e.addNoise==1
        msgAndWait(sprintf('obj_on 7 %d',noiseList(r)+1));
        sendCode(codes.STIM_ON + noiseList(r));%send code for which noise was shown
    elseif e.htOn==1
        msgAndWait('obj_on 5 7');
    else
        msgAndWait('obj_on 7');
    end
    
    sendCode(codes.STIM_ON);
    
    if ~waitForMS(e.stimDuration,currentPos(1),currentPos(2),params.fixWinRad)
        % check for maintained fixation
        if waitForFixation(e.saccadeTime,newX,newY,e.stimWinR)
            sendCode(codes.FALSEALARM);
            msgAndWait('all_off');
            sendCode(codes.STIM_OFF);
            sendCode(codes.FIX_OFF);
            waitForMS(timeout);
            result = codes.FALSEALARM;
            return;
        else
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.STIM_OFF);
            sendCode(codes.FIX_OFF);
            waitForMS(timeout);
            result = codes.BROKE_FIX;
            return;
        end
    end
    
    %turn off stim
    if e.addNoise==1
        msgAndWait(sprintf('obj_off 7 %d',noiseList(r)+1));
    elseif e.htOn ==1
        msgAndWait('obj_off 5 7');
    else
        msgAndWait('obj_off 7');
    end    
    sendCode(codes.STIM_OFF);
    
    if ~waitForMS(flash_list(r),currentPos(1),currentPos(2),params.fixWinRad)
        % check for maintained fixation
        sendCode(codes.BROKE_FIX);
        msgAndWait('all_off');
        sendCode(codes.STIM_OFF);
        sendCode(codes.FIX_OFF);
        waitForMS(timeout);
        result = codes.BROKE_FIX;
        return;
    end

end

%display target
if e.addNoise==1
    msgAndWait(sprintf('obj_on 8 %d',noiseList(r)+1));
    sendCode(codes.STIM_ON + noiseList(r));%send code for which noise was shown
elseif e.htOn==1
    msgAndWait('obj_on 6 8');
else
    msgAndWait('obj_on 8');
end
sendCode(codes.TARG_ON);

if ~waitForMS(e.minRT,e.fixX,e.fixY,params.sacWinRad,'recenterFlag',params.recenterFixWin)
    % left early
    sendCode(codes.FALSEALARM); 
    msgAndWait('all_off');
    sendCode(codes.TARG_OFF);
    sendCode(codes.FIX_OFF);
    sendCode(codes.SACCADE);
    waitForMS(timeout);
    result = codes.FALSEALARM;
    return;
end

%waitForMS(e.saccadeInitiate-e.minRT,e.fixX,e.fixY,e.newfixWinRad,'recenterFlag',params.recenterFixWin)
if waitForMS(e.saccadeInitiate-e.minRT,e.fixX,e.fixY,params.sacWinRad,'recenterFlag',params.recenterFixWin)
    % didn't leave fixation window
    sendCode(codes.MISSED); 
    msgAndWait('all_off');
    sendCode(codes.TARG_OFF);
    sendCode(codes.FIX_OFF);    
    waitForMS(e.noFixTimeout);
    result = codes.WITHHOLD;
    behav.goodTrials=behav.goodTrials+1;
    behav.randOrder(end) = [];
    %don't end trial until looks away from fixation
    while waitForMS(50,e.fixX,e.fixY,params.fixWinRad*2)%added 7/3/21 PLS
    end
    return;
end
sendCode(codes.SACCADE);

if ~waitForFixation(e.saccadeTime,newX,newY,e.stimWinR)
    % didn't reach target
    sendCode(codes.WRONG_TARG);
    msgAndWait('all_off');
    sendCode(codes.TARG_OFF);
    sendCode(codes.FIX_OFF);
    waitForMS(timeout);
    result = codes.WRONG_TARG;
    return;
end
sendCode(codes.ACQUIRE_TARG);

if ~waitForMS(e.stayOnTarget,newX,newY,e.stimWinR)
    % didn't stay on target long enough
    sendCode(codes.BROKE_TARG);
    msgAndWait('all_off');
    sendCode(codes.TARG_OFF);
    sendCode(codes.FIX_OFF);
    waitForMS(timeout);
    result = codes.BROKE_TARG;
    return;
end
sendCode(codes.FIXATE);
sendCode(codes.CORRECT);
behav.goodTrials=behav.goodTrials+1;
behav.randOrder(end) = [];

msgAndWait('all_off');
sendCode(codes.TARG_OFF);
sendCode(codes.REWARD);

%giveJuice(e.rewardDist(flashes));
giveJuice(params.juiceX,params.juiceInterval,floor(params.juiceTTLDuration*e.rewardDist(flashes))); %changed to different duration PLS 2/5/20
result=codes.CORRECT;
msgAndWait('ack3');
end

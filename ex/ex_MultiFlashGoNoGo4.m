function result = ex_MultiFlashGoNoGo4(e)
% ex file: ex_MultiFlashGoNoGo2
% 6/10/19 PS: Changed intFlashInt to be different on each flash (not just
% each trial), changed object setup to take in more than 1 color
%
%
global params codes behav allCodes;

e = e(1); %in case more than one 'trial' is passed at a time...

% hard-coded number of noise stimuli
nNoise = 5;

%initialize behavior-related stuff:
if ~isfield(behav,'goodTrials')
    behav.goodTrials = 0;
    behav.currentContext = e.context;
    behav.storeContext = [];
    behav.blockCounter = 1;
end

% % take radius and angle and figure out x/y for saccade direction
% theta = deg2rad(e.angle);
% newX = round(e.stimX*cos(theta))+e.fixX;
% newY = round(e.stimY*sin(theta))+e.fixY;

%saccade direction relative to fixation
newX = e.stimX+e.fixX;
newY = e.stimY+e.fixY;

% obj 1 is fix spot, obj 7 is sample, obj 8 is target
msg('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad e.fixColor(1) e.fixColor(2) e.fixColor(3)]);

if isfield(e,'dot1Color')
    % dot color change
    if e.stimNum == 1
        targs = reshape(e.dot1Targs,[3,length(e.dot1Targs)/3]);
        targ = targs(:,e.numTarg);
        msg('set 7 oval 0 %i %i %i %i %i %i',[newX newY e.fixRad*4 e.dot1Color(1) e.dot1Color(2) e.dot1Color(3)]);
        msg('set 8 oval 0 %i %i %i %i %i %i',[newX newY e.fixRad*4 targ(1) targ(2) targ(3)]);
    elseif e.stimNum == 2
        targs = reshape(e.dot2Targs,[3,length(e.dot2Targs)/3]);
        targ = targs(:,e.numTarg);
        msg('set 7 oval 0 %i %i %i %i %i %i',[newX newY e.fixRad*4 e.dot2Color(1) e.dot2Color(2) e.dot2Color(3)]);
        msg('set 8 oval 0 %i %i %i %i %i %i',[newX newY e.fixRad*4 targ(1) targ(2) targ(3)]);
    end
else
    tempContext = behav.currentContext;
    % block the context switches
    if e.blockSwitch>0
        %if reached end of block, reset trial counter
        if behav.goodTrials >= e.trialsPerContext 
            behav.goodTrials = 0;
            behav.blockCounter = behav.blockCounter+1;
        end
        
        %if reached end of block and second block in series, change context
        if behav.blockCounter>2
            behav.blockCounter = 1;
            % switch context
            if behav.currentContext == 1
                tempContext = 2;
                behav.currentContext = 2;
                % sendCode(2002);
            elseif behav.currentContext == 2
                tempContext = 1;
                behav.currentContext = 1;                
                % sendCode(2001);                
            end
        end
        sendStruct(struct('blockContext',tempContext));
    end
    
    % this is for showing images
    if tempContext==1
        morphAngle = e.C1morphAngle(e.targ);
        if behav.blockCounter==1 && morphAngle<0 % if first block and invalid
            numValids = sum(e.C1morphAngle>0);
            morphAngle = e.C1morphAngle(randi(numValids));
        end
    elseif tempContext==2
        morphAngle = e.C2morphAngle(e.targ);
        if behav.blockCounter==1 && morphAngle<0 % if first block and invalid
            numValids = sum(e.C2morphAngle>0);
            morphAngle = e.C2morphAngle(randi(numValids));
        end
    end
    sendStruct(struct('trueMorphAngle',morphAngle));
    
    % for invalid trials
    if morphAngle<0        
        sendStruct(struct('isValid',0));
        morphAngle = abs(morphAngle);
        if tempContext==1
            tempContext = 2;
        elseif tempContext==2
            tempContext = 1;
        end
    else
        sendStruct(struct('isValid',1));
    end
    
    sampleString = [e.sample,filesep,sprintf('img%i',e.sampleSuffix),'.mat'];        
    msg(sprintf('set 7 movie_morph %s 0 1 1 %i %i %i 0 0 %i',sampleString,[newX newY],e.aperture,e.imgDisplaySize));
    msg(sprintf('set 8 movie_morph %s 0 1 1 %i %i %i %i %i %i',sampleString,[newX newY],e.aperture,tempContext,morphAngle,e.imgDisplaySize));
end

behav.storeContext = [behav.storeContext tempContext]; %store context on each trial

%if want to add noise to image
if e.addNoise==1
    seed = e.seed;
    for n=2:nNoise+1 %create nNoise different noise filters store as obj 2-6     
        ttt=[0 round(e.aperture/e.noiseN*2) e.noiseN 255 255 255 e.alpha 0 0 0 e.alpha seed 0 newX newY e.aperture];
        msg(sprintf('set %i squarecheck %i %i %i %f %f %f %f %f %f %f %f %i %i %i %i %i %i',n,ttt));
        seed = seed+1;
    end
end

msg(['diode 7 8']); % diode flashes for both sample and target

%turn the cue (fixation point) on
pause(e.ITI/1000);
msgAndWait('obj_on 1');
sendCode(codes.FIX_ON);

%test whether looked in fixation window
if ~waitForFixation(e.timeToFix,e.fixX,e.fixY,e.fixWinR)
    % failed to achieve fixation
    sendCode(codes.IGNORED);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e.noFixTimeout);
    result = codes.IGNORED;
    return;
end
sendCode(codes.FIXATE);

if ~waitForMS(e.stimOnsetDelay,e.fixX,e.fixY,e.fixWinR)
    % hold fixation before stimulus comes on
    sendCode(codes.BROKE_FIX);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e.breakFixTimeout/2);
    result = codes.BROKE_FIX;
    return;
end

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
    else
        msgAndWait('obj_on 7');
    end
    
    sendCode(codes.STIM_ON);
    
    if ~waitForMS(e.stimDuration,e.fixX,e.fixY,e.fixWinR)
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
    else
        msgAndWait('obj_off 7');
    end    
    sendCode(codes.STIM_OFF);
    
    if ~waitForMS(flash_list(r),e.fixX,e.fixY,e.fixWinR)
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
else
    msgAndWait('obj_on 8');
end
sendCode(codes.TARG_ON);

if ~waitForMS(e.minRT,e.fixX,e.fixY,e.sacWinR,'recenterFlag',params.recenterFixWin)
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

%waitForMS(e.saccadeInitiate-e.minRT,e.fixX,e.fixY,e.newfixWinR,'recenterFlag',params.recenterFixWin)
if waitForMS(e.saccadeInitiate-e.minRT,e.fixX,e.fixY,e.sacWinR,'recenterFlag',params.recenterFixWin)
    % didn't leave fixation window
    sendCode(codes.MISSED); 
    msgAndWait('all_off');
    sendCode(codes.TARG_OFF);
    sendCode(codes.FIX_OFF);
    behav.goodTrials=behav.goodTrials+1;
    waitForMS(timeout/2);
    result = codes.WITHHOLD;
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

msgAndWait('all_off');
sendCode(codes.TARG_OFF);
sendCode(codes.REWARD);

giveJuice(e.rewardDist(flashes));
result=codes.CORRECT;

end

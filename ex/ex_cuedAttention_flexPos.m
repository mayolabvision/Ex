function result = ex_cuedAttention_flexPos(e)
% ex file:
%
% Development notes: test staircasing -ACS 18Aug2015
%
% Modified: KC April 2017. added capability of having different miniblock
% sizes
% Modified: KC April 2018. target location equally possible at either of
% two locations. no catch trials in this version. 
% Modified: KC April 2018. deleted lines of code pertaining to microstim in
% this version
%
global params codes behav allCode

e = e(1); %in case more than one 'trial' is passed at a time...
printDebugMessages = false;



%set default cue type stuff for backwards compatability
if ~isfield(e,'cueTypeBlockSize'),
    e.cueTypeBlockSize = 100000; %some absurdly high number of trials effectively means don't flip.
end;
if ~isfield(e,'cueType'),
    e.cueType = 1; %cueType 1 is spatial, cueType 2 is featural
    targetFeature = 1; %1 = orientation, 2 = spatial frequency. Use orientation always if cueType isn't specified
elseif e.cueType == 1,
    if e.cueTypeBlockSize > 1000, %if the cueTypeBlockSize is absurdly high, it means that we probably want this to run 'classically', with only orientation targets
        targetFeature = 1;
    else
        %for a spatial cue, pick a target feature randomly (!)
        targetFeature = randi(2);
    end;
end;

targetFeatureAmplitudeFieldNames = {'oriTargAmp','sfTargAmp'};
invalidFeatureAmplitudeFieldNames = {'invalidOriTargAmp','invalidSfTargAmp'};



%initialize behavior-related stuff:
if ~isfield(behav,'cue'),
    behav.score = [];
    behav.targPickHistory = [];
    behav.trialNum = 0; 
    
    behav.RT = [];
    behav.showHelp = [];
    behav.flipFlag = 0;
    behav.cue = e.cue; %for the very first trial, use the cue value from the XML
    behav.cueType = e.cueType;
    behav.flipTypeFlag = 0; %whether the type of cue (i.e., spatial/featural) has been flipped
end;

if printDebugMessages,
    display(behav); %#ok<*UNRCH>
    fprintf('trial in miniblock: %d\n',(mod(behav.trialNum(end),e.miniblockSize)));
end;




    switch mod(behav.trialNum(end),e.miniblockSize),
        case 0, %indicates start of new miniblock
            if behav.trialNum(end)>0&&~behav.flipFlag, %don't flip before the first miniblock
                behav.cue = 3-behav.cue; %set the current cue to the "other" one
                
                behav.flipFlag = 1; %mark that flip has been done (in case the subject breaks fixation, etc. and we have to try the first trial again)
            end;
        otherwise, %first trial after flip
            behav.flipFlag = 0; %signal that flip will be needed next miniblock
    end;








switch mod(behav.trialNum(end),e.cueTypeBlockSize), %the most sensible thing is to make cueTypeBlockSize an integer multiple of miniblockSize
    case 0, %indicates it's time to flip the cue type
        if behav.trialNum(end)>0&&~behav.flipTypeFlag, %don't flip before the first miniblock
            behav.cueType = 3-behav.cueType; %set the current cue to the "other" one
            behav.flipTypeFlag = 1; %mark that flip has been done (in case the subject breaks fixation, etc. and we have to try the first trial again)
        end;
    case 1, %first trial after flip
        behav.flipTypeFlag = 0; %signal that flip will be needed next cueType block
end;



    if mod(behav.trialNum(end),e.miniblockSize)<e.nCueTrials,
        isCueTrial = true;
        e.isValid = true; %cued targets are always valid
    else
        isCueTrial = false;
    end;




e.cue = behav.cue; %pull the "real" cue from the behav structure
e.cueType = behav.cueType; %pull the "real" cue type from the behav structure
if e.cueType==2, %feature based cue, use cue validity:
    if e.isValid,
        targetFeature = e.cue;
    else
        targetFeature = 3-e.cue;
    end;
end;
if printDebugMessages,
    fprintf('Cue: %d\n',e.cue);
    fprintf('Validity: %d\n',e.isValid);
end;

winColors = [0,255,0;255,0,0];
frameMsec = params.displayFrameTime*1000;
stimulusDuration = e.stimulusDuration;
targetObject = abs(((1-e.isValid)*3)-e.cue);
backdoor = stimulusDuration.*frameMsec; ...max(e.interStimulusInterval)+(stimulusDuration.*frameMsec);
    
orientations = [e.orientation1,e.orientation2];
orientations = orientations([e.oriPick 3-e.oriPick]); %randomize orientations

if e.isValid,
    e.(targetFeatureAmplitudeFieldNames{targetFeature}) = sort(e.(targetFeatureAmplitudeFieldNames{targetFeature}),'ascend'); %ensure sorted
    targAmpPick = randi(numel(e.(targetFeatureAmplitudeFieldNames{targetFeature}))); %changed from using the targAmpPick parameter, since we're not staircasing for this one -ACS 30sep2015
    targAmp = e.(targetFeatureAmplitudeFieldNames{targetFeature})(targAmpPick);
else
    e.(invalidFeatureAmplitudeFieldNames{targetFeature}) = sort(e.(invalidFeatureAmplitudeFieldNames{targetFeature}),'ascend'); %ensure sorted
    targAmpPick = randi(numel(e.(invalidFeatureAmplitudeFieldNames{targetFeature})));
    targAmp = e.(invalidFeatureAmplitudeFieldNames{targetFeature})(targAmpPick);
end;

sendStruct(struct('targAmp',targAmp,'thisTrialCue',e.cue,'thisTrialCueType',e.cueType,'isCueTrial',isCueTrial,'targetFeature',targetFeature)); %I think this should work, -ACS24Apr2012 %added the  cue for this particular trial (cue from xml just sets first miniblock) -ACS07oct2015 -added isCueTrial acs12oct2015

if isfield(e,'helpFixProb'), showHelp = rand<e.helpFixProb; else showHelp = true; end;

switch e.cueType
    case 1 %spatial cue
        posPick = (1-targetObject)*2+1;
    case 2 %featural cue - will need to change color or something here for this. -ACS 11Jun2015
        posPick = e.posPick; %random position for feature-based
    otherwise
        error('driftchoice:unknownCueType','unknown cue type');
end;
targetObject = (1-posPick)*0.5+1; %for feature based: update target object relative to RF position based on the position that was actually picked
if printDebugMessages, fprintf('Position pick: %d\n',posPick); end;
if e.cueType == 2 && mod(behav.trialNum(end),e.miniblockSize)<e.nCueTrials,
    %for feature-based cues, but the target in a "neutral" location:
    targX = 0;
    targY = 1.5.*e.radius;
else %use the position picked for the target
    if posPick<0, %indicates that target should be out of the RF -acs24aug2016
        targX = e.outx;
        targY = e.outy;
    else
        targX = e.inx; %target is in the RF
        targY = e.iny;
    end;
end;

if posPick<0, %indicates that target should be out of the RF... -acs24aug2016
    distX = e.inx; %... so the distracter is in the RF
    distY = e.iny;
else %the target is in the RF...
    distX = e.outx; %...so the distracter is out of the RF
    distY = e.outy;
end;

msgAndWait('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad 255 255 0]); %constant central fixation (yellow)

if isfield(e,'nSampleStims'),
    nSampleStims = e.nSampleStims;
else
    nSampleStims = 1; %how many standards before the first opportunity to be a target... usually 1, but you might want it to be 2 if there are lots of false alarms. -ACS 03nov2015
end;

isTarget = [zeros(1,nSampleStims) rand(1,e.maxStims-nSampleStims)<e.targProb];
isTarget((find(isTarget>0,1,'first')+1):end) = []; 


msgAndWait('ack');
msgAndWait('obj_on 1'); %turn on fixation
sendCode(codes.FIX_ON);

if ~waitForFixation(e.timeToFix,e.fixX,e.fixY,params.fixWinRad)
    % failed to achieve fixation
    sendCode(codes.IGNORED);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(1000); % no full time-out in this case
    result = codes.IGNORED;
    return;
end
sendCode(codes.FIXATE);

if rand<e.fixJuice,
    giveJuice(1);
end;

if ~waitForMS(e.preCueFix,e.fixX,e.fixY,params.fixWinRad)
    % hold fixation before stimulus comes on
    sendCode(codes.BROKE_FIX);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e.noFixTimeout);
    result = codes.BROKE_FIX;
    return; 
    
end

if e.showHoles
    if showHelp,
        msgAndWait('set 2 oval 0 %i %i %i %i %i %i',[targX targY e.fixRad e.helpFixColor]); %target fixation (blue)
    else
        msgAndWait('set 2 oval 0 %i %i %i %i %i %i',[targX targY e.fixRad 127 127 127]); %target fixation (blue)
    end;
    msgAndWait('set 3 oval 0 %i %i %i %i %i %i',[targX targY e.fixRad 127 127 127]); %'hole' in target grating
    msgAndWait('set 4 oval 0 %i %i %i %i %i %i',[distX distY e.fixRad 127 127 127]); %'hole' in distracter grating
end;
msg('diode 6'); %

%objects 5 & 10 are at the target location, object 6 is the foil.
for sx = 1:numel(isTarget),
    if sx==2, trialStart = tic; end; %mark the time of the first potential target. -acs18nov2015
    
    
    thisInterval = randi(numel(e.interStimulusInterval));
    if thisInterval>0,
        if ~waitForMS(e.interStimulusInterval(thisInterval),e.fixX,e.fixY,params.fixWinRad)
            % failed to keep fixation
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.noFixTimeout);
            result = codes.BROKE_FIX;
            return;
        end;
    end;
    
    %Apparently this has to be done anew each stim: -ACS 30sep2015
    msgAndWait('set 5 gabor %i %f %f %f %f %i %i %i %f %f',...
        [stimulusDuration  orientations(1) e.phase e.spatial e.temporal targX targY e.radius e.contrast e.radius/4]);
    if targetFeature==1,
        msgAndWait('set 10 gabor %i %f %f %f %f %i %i %i %f %f',...
            [stimulusDuration  orientations(1)+targAmp e.phase e.spatial e.temporal targX targY e.radius e.contrast e.radius/4]);
    else
        msgAndWait('set 10 gabor %i %f %f %f %f %i %i %i %f %f',...
            [stimulusDuration  orientations(1) e.phase e.spatial.*(10.^targAmp) e.temporal targX targY e.radius e.contrast e.radius/4]);
    end;
    
   
        if mod(behav.trialNum(end),e.miniblockSize)<e.nCueTrials,
            msgAndWait('set 6 blank %i', stimulusDuration); %make the foil blank for cue trials -acs 04oct2015
            standardCode = sprintf('STIM%d_ON',e.cue);
        else
            msgAndWait('set 6 gabor %i %f %f %f %f %i %i %i %f %f',...
                [stimulusDuration  orientations(2) e.phase e.spatial e.temporal distX distY e.radius e.contrast e.radius/4]);
            standardCode = 'STIM_ON';
        end;
   
    
 
    if printDebugMessages, fprintf('This code: %s\n',standardCode); end;
    
    numberOfStimsRemaining = 6-sx; ...e.maxStims-sx; %maximum sequence length remaining (in number of stimuli) %set to a flat 6 stims now that maxStims is set really high -ACS 01dec2015
        timeoutDuration = numberOfStimsRemaining.*(max(e.interStimulusInterval)+(stimulusDuration.*frameMsec)); %timeout duration is the maximum sequence length remaining (in milliseconds)
   
    
   
   
    if ~isTarget(sx),
        
        msg('obj_on 5 6');
        if e.showHoles
            msg('obj_on 4 3');
        end;
        sendCode(codes.(standardCode));
        
       
        %preallocate this trial's entry in the behav structure:
        behav.score(end+1) = nan;
        behav.showHelp(end+1) = showHelp;
        behav.RT(end+1) = nan;
        if ~waitForMS(stimulusDuration.*frameMsec,e.fixX,e.fixY,params.fixWinRad)             % failed to keep fixation
            % added this SACCADE code 12.22.17 because it's important to
            % know when the saccade was initiated on false alarm trials
            sendCode(codes.SACCADE);
            %
            choiceWin = waitForFixation(8.*frameMsec,[targX distX],[targY distY],params.targWinRad*[1 1]); %note that target window is always '1' %Not sure about this magic number '8'  here -ACS
            switch choiceWin
                case 1
                    if e.isValid, choicePos = e.cue; else choicePos = 3-e.cue; end; %these lines convert the choice from "target relative" to "spatial location" (i.e., left v. right)
                    result = codes.FALSEALARM;
                    %                     behav.trialNum = behav.trialNum+1;
                case 2
                    if e.isValid, choicePos = 3-e.cue; else choicePos = e.cue; end;
                    result = codes.FALSEALARM;
                    %                     behav.trialNum = behav.trialNum+1;
                otherwise
                    choicePos = 0;
                    result = codes.BROKE_FIX; %don't increment trial counter for broken fixation
            end;
            
            
           
            sendCode(result);
            sendCode(codes.(sprintf('CHOICE%d',choicePos)));
            msgAndWait('all_off');
            sendCode(codes.STIM_OFF);
            sendCode(codes.FIX_OFF);
            
    
            timeoutDuration1 = 6000;           
           waitForMS(timeoutDuration1);
            
            return;
        end;
        
         
        
        if e.showHoles
            msg('obj_off 4 3');
            msg('obj_off 3');
        end;
        
      
            
        sendCode(codes.WITHHOLD);
        sendCode(codes.STIM_OFF);
            
        result = codes.WITHHOLD; %don't increment trial counter for withholds within the sequence
        
        
%         if isCatch && sx==2;
%             msgAndWait('all_off');
%             sendCode(codes.WITHHOLD);
%             sendCode(codes.STIM_OFF);
%             sendCode(codes.FIX_OFF);
%             
%             behav.score(end+1) = nan;
%             behav.showHelp(end+1) = showHelp;
%             
%             behav.RT(end+1) = nan;
%             giveJuice(3); % 2 for catch trial
%             sendCode(codes.REWARD);
%             result = codes.WITHHOLD;
%             return;
%         end
            
            
        
    else %this is a target...
        
        %change this to set up the target properly...
        msg('obj_on 10 6');
        if e.showHoles
            msg('obj_on 4 2');%fixation at target stim
        end;
        sendCode(codes.(sprintf('TARG%d_ON',targetObject)));
        targOnTime = tic;
        
        

        % MAS NOTE 12.22.17
        % should this be waitForMS? - We could recode
        % this as a waitForMS, and then once he leaves fixation we
        % run the waitForFixation code on the two potential target locations
        choiceWin = waitForFixation(stimulusDuration.*frameMsec,[targX distX],[targY distY],params.targWinRad*[1 1],winColors(1:2,:)); %note that target window is always '1'
        sacTime = toc(targOnTime); %ok to be here for now to test -acs10dec2015
        
        if choiceWin==0&&backdoor>(stimulusDuration*frameMsec), %extra time to react after stimulus offset %not happening at the moment -acs10dec2015
            sendCode(codes.STIM_OFF);
            choiceWin = waitForFixation(backdoor-(stimulusDuration.*frameMsec),[targX distX],[targY distY],params.targWinRad*[1 1],winColors(1:2,:)); %note that target window is always '1'
        end;
        
        %         fprintf('\nChoice:%i, Target:%i\n',choiceWin,targetObject); %debugging feedback
        switch choiceWin
            case 0
                if waitForFixation(1,e.fixX,e.fixY,params.fixWinRad)
                    sendCode(codes.NO_CHOICE);
                    behav.score(end+1) = 0;
                    result = codes.NO_CHOICE;
                else
                    sendCode(codes.BROKE_FIX); % edited by MAS on 1/12/16 to change it from FIX_OFF
                    behav.score(end+1) = nan;
                    result = codes.BROKE_FIX; %don't increment trial counter for broken fixation
                end;
                msgAndWait('all_off');
                sendCode(codes.FIX_OFF);
                behav.showHelp(end+1) = showHelp;
                behav.RT(end+1) = nan;
                return;
            case 1 %the target window
                sendCode(codes.SACCADE); %mark the time before the 'stayOnTarget' period. -acs30oct2015
                behav.showHelp(end+1) = showHelp;
                if ~waitForMS(e.stayOnTarget,targX,targY,params.targWinRad) %require to stay on for a while, in case the eye 'accidentally' travels through target window
                    % failed to keep fixation
                    sendCode(codes.BROKE_TARG);
                    msgAndWait('all_off');
                    sendCode(codes.FIX_OFF);
                    behav.score(end+1) = nan;
                    behav.RT(end+1) = nan;
                    waitForMS(e.noFixTimeout);
                    result = codes.BROKE_TARG; %don't increment trial counter for this
                    return;
                end;
                if sacTime<=backdoor/1000
                    sendCode(codes.CORRECT);
                    result = codes.CORRECT;
                    
                        behav.trialNum = behav.trialNum+1;
                    
                else
                    sendCode(codes.MISSED);
                    result = codes.MISSED;
                end;
                behav.score(end+1) = 1;
                behav.RT(end+1) = sacTime;
            otherwise
                sendCode(codes.SACCADE);
                % incorrect choice
                %for a wrong choice, immediately score it, so that the subject
                %can't then switch to the other stimulus.
                if sacTime<=backdoor/1000
                    sendCode(codes.WRONG_TARG);
                    result = codes.WRONG_TARG; %change the result code to indicate a wrong choice
                else
                    sendCode(codes.MISSED);
                    result = codes.MISSED;
                end;
                msgAndWait('all_off');
                sendCode(codes.STIM_OFF);
                sendCode(codes.FIX_OFF);
                behav.score(end+1) = 0;
                behav.showHelp(end+1) = showHelp;
                behav.RT(end+1) = nan;
                waitForMS(timeoutDuration);
                %                 behav.trialNum = behav.trialNum+1;
                return;
        end;
    end; %end if isTarget
end;

msgAndWait('all_off');
sendCode(codes.FIX_OFF);
trialEnd = toc(trialStart);
if isTarget(end),
    if result==codes.CORRECT
        maxReward = min(1+2.^round(trialEnd/e.rewardHalflife),e.rewardCap);
       % giveJuice(2);
        if e.isValid==1
            giveJuice(maxReward); % changed to a number of clicks equal to the sequence length, to compensate for delay discounting some... -acs11nov2015 -added reward cap 30nov2015
        else
            giveJuice(((maxReward-1).*(1-e.rewardBias))+1); %just give one measly click for an invalid -acs
        end
        sendCode(codes.REWARD);
    else
        behav.score(end) = 0;
    end;

end;

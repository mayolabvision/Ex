function result = ex_cuedAttention_multipleStims(e)
% ex file:
%
% Development notes: test staircasing -ACS 18Aug2015
%
% Modified:
%
global params codes behav allCodes;

e = e(1); %in case more than one 'trial' is passed at a time...
printDebugMessages = false;

%initialize behavior-related stuff:
if ~isfield(behav,'cue'),
    behav.score = [];
    behav.targPickHistory = [];
    behav.trialNum = 0;
    behav.RT = [];
    behav.showHelp = [];
    behav.flipFlag = 0;
    behav.cue = e.cue; %for the very first trial, use the cue value from the XML
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
    case 1, %first trial after flip
        behav.flipFlag = 0; %signal that flip will be needed next miniblock
end;
if mod(behav.trialNum(end),e.miniblockSize)<e.nCueTrials,
    isCueTrial = true;
    e.isValid = true; %cued targets are always valid
else
    isCueTrial = false;
end;
e.cue = behav.cue; %pull the "real" cue from the behav structure
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
    e.startTargAmp = sort(e.startTargAmp,'ascend'); %ensure sorted
    targAmpPick = randi(numel(e.startTargAmp)); %changed from using the targAmpPick parameter, since we're not staircasing for this one -ACS 30sep2015
    targAmp = e.startTargAmp(targAmpPick);
else
    e.invalidTargAmp = sort(e.invalidTargAmp,'ascend'); %ensure sorted
    targAmpPick = randi(numel(e.invalidTargAmp));
    targAmp = e.invalidTargAmp(targAmpPick);
end;

sendStruct(struct('targAmp',targAmp,'thisTrialCue',e.cue,'isCueTrial',isCueTrial)); %I think this should work, -ACS24Apr2012 %added the  cue for this particular trial (cue from xml just sets first miniblock) -ACS07oct2015 -added isCueTrial acs12oct2015

if isfield(e,'helpFixProb'), showHelp = rand<e.helpFixProb; else showHelp = true; end;

switch e.cueMap
    case 1 %spatial cue
        posPick = (1-targetObject)*2+1;
    case 2 %featural cue - will need to change color or something here for this. -ACS 11Jun2015
        posPick = e.posPick;
    otherwise
        error('driftchoice:unknownCueMap','unknown cue mapping');
end;
if printDebugMessages, fprintf('Position pick: %d\n',posPick); end;
targX = e.centerx*posPick;
targY = e.centery;
distX = -e.centerx*posPick;
distY = e.centery;

msgAndWait('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad 255 255 0]); %constant central fixation (yellow)

nSampleStims = 1; %how many standards before the first opportunity to be a target... usually 1, but you might want it to be 2 if there are lots of false alarms. -ACS 03nov2015
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

% if rand<e.fixJuice,
%     giveJuice(1);
% end;

if ~waitForMS(e.preCueFix,e.fixX,e.fixY,params.fixWinRad)
    % hold fixation before stimulus comes on
    sendCode(codes.BROKE_FIX);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e.noFixTimeout);
    result = codes.BROKE_FIX;
    return;
end

if ~isfield(behav,'holeScale'),
    behav.holeScale = 0.5;
end;
holeScale = behav.holeScale;
if e.showHoles&&round(e.fixRad.*holeScale)>0
    if showHelp,
        %msgAndWait('set 2 oval 0 %i %i %i %i %i %i',[targX targY round(e.fixRad.*holeScale) e.helpFixColor]); %target fixation (blue)
    msgAndWait('set 2 oval 0 %i %i %i %i %i %i',[targX targY e.fixRad e.helpFixColor]); %target fixation (blue)
    
    else
        msgAndWait('set 2 oval 0 %i %i %i %i %i %i',[targX targY round(e.fixRad.*holeScale) 127 127 127]); %target fixation (blue)
    end;
    msgAndWait('set 3 oval 0 %i %i %i %i %i %i',[targX targY round(e.fixRad.*holeScale) 127 127 127]); %'hole' in target grating
    msgAndWait('set 4 oval 0 %i %i %i %i %i %i',[distX distY round(e.fixRad.*holeScale) 127 127 127]); %'hole' in distracter grating


end;
msg('diode 6'); %

%objects 5 & 10 are at the target location, object 6 is the foil.
for sx = 1:numel(isTarget),
    if sx==2, trialStart = tic; end; %mark the time of the first potential target. -acs18nov2015
    
    %Inter-stimulus interval: %moved from after stim setup lines
    %-acs08mar2016
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
    msgAndWait('set 10 gabor %i %f %f %f %f %i %i %i %f %f',...
        [stimulusDuration  orientations(1)+targAmp e.phase e.spatial e.temporal targX targY e.radius 1 e.radius/4]); %temporarily hard-coded contrast as 1 -acs31oct2016
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
        
        msgAndWait('queue_begin');
        msg('obj_on 5');
        msg('obj_on 6');
        if e.showHoles
            msg('obj_on 4');
            msg('obj_on 3');
        end;
        msgAndWait('queue_end');
        sendCode(codes.(standardCode));
        
        %preallocate this trial's entry in the behav structure:
        behav.score(end+1) = nan;
        behav.showHelp(end+1) = showHelp;
        behav.RT(end+1) = nan;
        if ~waitForMS(stimulusDuration.*frameMsec,e.fixX,e.fixY,params.fixWinRad)
            % failed to keep fixation
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
            waitForMS(timeoutDuration);
            return;
        end;
        
        %         msg('obj_off 5'); %don't think we need these here... -acs30oct2015
        %         msg('obj_off 6');
        if e.showHoles
            msgAndWait('queue_begin'); %moved inside the conditional -acs07mar2016
            msg('obj_off 4');
            msg('obj_off 3');
            msgAndWait('queue_end'); %moved inside the conditional -acs07mar2016
        end;
        sendCode(codes.STIM_OFF);
        
        sendCode(codes.WITHHOLD);
        result = codes.WITHHOLD; %don't increment trial counter for withholds within the sequence
        
    else %this is a target...
        
        %change this to set up the target properly...
        msgAndWait('queue_begin');
        msg('obj_on 10');
        msg('obj_on 6');
        if e.showHoles
            msg('obj_on 4');
            msg('obj_on 2'); %fixation at target stim
        end;
        %         msg('obj_off 1');
        msgAndWait('queue_end');
        sendCode(codes.(sprintf('TARG%d_ON',targetObject)));
        targOnTime = tic;
        
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
                    sendCode(codes.FIX_OFF);
                    behav.score(end+1) = nan;
                    result = codes.BROKE_FIX; %don't increment trial counter for broken fixation
                end;
                msgAndWait('all_off');
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
                    behav.trialNum = behav.trialNum+1; %increment trial counter %only incrementing for hits! -ACS07oct2015
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
        if e.isValid==1
            giveJuice(maxReward); % changed to a number of clicks equal to the sequence length, to compensate for delay discounting some... -acs11nov2015 -added reward cap 30nov2015
        else
            giveJuice(((maxReward-1).*(1-e.rewardBias))+1); %just give one measly click for an invalid -acs
        end
        sendCode(codes.REWARD);
        behav.holeScale = behav.holeScale-0.01; %shrink the size of the helper dot a bit...
    else
        behav.score(end) = 0;
    end;
else %last stim in a catch trial
    giveJuice(3); %# of clicks for a withhold on a catch trial -changed to runlength+1, -acs11nov2015 %changed to a flat 3 clicks. -acs18nov2015
    sendCode(codes.REWARD);
end;

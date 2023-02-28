function result = ex_fixAndStim_multiChannel_movie(e)
% ex file: ex_fixAndStim_multiChannel
%
% Fixation task with microstimulation on every other trial
%
% XML REQUIREMENTS
% runline: a list of strings which correspond to other parameter names.
%   This list of names is used to construct the custom set command to the
%   display
% NAMES: all the parameters listed in runline
% type: the type of stimulus (e.g. fef_dots,oval,etc)
% timeToFix: the number of ms to wait for initial fixation
% saccadeInitiate: maximum time allowed to leave fixation window
% saccadeTime: maximum time allowed to reach target
% preStimFix: time after fixation pt onset before stim onset
% stayOnTarget: time after reaching target that subject must stay in window
% saccadeLength: distance of target from fixation
% noFixTimeout: time after breaking fixation before next trial can begin
% fixX, fixY, fixRad: fixation spot location in X and Y as well as RGB
%   color
% saccadeDir: angle of target to fixation, usually set with a random
%
% Last modified:
% 2015/06/11 by ACS - strip zeros off of e.xippmexStimChans, which can be
% used as placeholders to make multi-channel paradigms easier to handle. In
% theory, this should be backwards compatible, and this file can eventually
% replace ex_fixAndStim. I'm using a different file name during
% development.
% -ACS
% 2012/10/22 by Matt Smith - added e=e(1);
% 2012/11/15 by Matt Smith - modified from old fixAndStim to now turn off
% fix pt before stim, reward at stim, and also used XML parameter to have
% random time to stim. This is the new default fixAndStim
%

global params codes behav allCodes;

e = e(1); %in case more than one 'trial' is passed at a time...
result = 1; %initialize result

% check if the field exists, if not set it to zero
%     if ~isfield(behav,'microStimNextTrial')
%         behav.microStimNextTrial = 0;
%     end

% If you're stimulating via Ripple, setup the stimulation settings now
if e.stimSource==2 %def=2
    %         disp('hi')
    %         disp(params.SubjectID);
    %         disp(e.stimSource);
    if ~isfield(behav,'xippmexInitialized')||~behav.xippmexInitialized,
        status = xippmex;
        if status~=1
            error('Unable to initialize xippmex');
        else
            behav.xippmexInitialized = true;
        end
    end;
    stimChans=xippmex('elec','stim'); %can I move this up before initialization? -acs26apr2016
    if ~isscalar(e.xippmexStimAmp), e.xippmexStimAmp(e.xippmexStimChan<1) = []; end;%strip off amplitudes for channel values less than one (these are just placeholders). -ACS 16Jun2015
    e.xippmexStimChan(e.xippmexStimChan<1) = []; %strip off channel values less than one (these are just placeholders). -ACS 11Jun2015
    if any(setdiff(e.xippmexStimChan,stimChans))
        error('Unable to stimulate on requested channel %d',setdiff(e.xippmexStimChan,stimChans));
    end
    % turn on stimulation for requested channel(s)
    if ~isempty(e.xippmexStimChan) && any(e.xippmexStimAmp),
        xippmex('stim','enable',0); %disable stim first so step size can be set. -acs26apr2016
        % setup the microstim command
        stim_cmd = xippmexStimCmd(e.xippmexStimChan,e.xippmexPulseWidth,e.xippmexStimFreq,e.xippmexStimDur,e.xippmexStimAmp);
        xippmex('stim','enable',1); %enable stim
        xippmex('signal',e.xippmexStimChan,'stim',e.xippmexStimChan); %turn on stim
    end;
end

% obj 1 is fix spot, obj 2 is stimulus, diode attached to obj 2
msg('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad e.fixColor(1) e.fixColor(2) e.fixColor(3)]);
runLine = e.runline;
runString = '';
while ~isempty(runLine)
    [tok, runLine] = strtok(runLine); %#ok<*STTOK>
    
    while ~isempty(tok)
        [thisTok, tok] = strtok(tok,',');
        
        runString = [runString num2str(eval(['e.' thisTok]))]; %#ok<*AGROW>
    end
    
    runString = [runString ' '];
end
runString = [e.type ' ' runString(1:end-1)];
%         disp(['set ' num2str(objID) ' ' runString]);
msg(['set 2 ' runString]);
msg('diode 2');

msgAndWait('ack');

msgAndWait('obj_on 1');
sendCode(codes.FIX_ON);

if ~waitForFixation(e.timeToFix,e.fixX,e.fixY,params.fixWinRad)
    % failed to achieve fixation
    sendCode(codes.IGNORED);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    result = codes.IGNORED;
    return;
end
sendCode(codes.FIXATE); 

% start = tic;

msgAndWait('obj_on 2');
sendCode(codes.STIM_ON); %added 12jul2016 -acs
%tic

if ~waitForMS(e.preStimFix,e.fixX,e.fixY,params.fixWinRad)
    % hold fixation before stimulus comes on
    sendCode(codes.BROKE_FIX);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e.noFixTimeout);
    result = codes.BROKE_FIX;
    return;
end

if ~e.fixStaysOn
    msgAndWait('obj_off 1'); % turn off fixation point before microstim
    sendCode(codes.FIX_OFF);
end
if ~waitForMS(e.waitForStim,e.fixX,e.fixY,params.fixWinRad)
    % hold fixation briefly before microstim starts
    sendCode(codes.BROKE_FIX);
    msgAndWait('all_off');
    waitForMS(e.noFixTimeout);
    result = codes.BROKE_FIX;
    return;
end

% On even trials, microstim
ustimflag = 0;
deepPink = [255 20 147];
fixColor = [255 255 0];
unixSetLevel(19,1); %raise the TTL bit to enable Trellis fast-settling. -acs02may2016
if (e.microStimDur > 0) %def=1
    if ~isempty(e.xippmexStimChan), ...(behav.microStimNextTrial == 1)
            ustimflag = 1;
        fixColor = deepPink;
        %             behav.microStimNextTrial = 0;
        sendCode(codes.ALIGN);
        sendCode(codes.USTIM_ON);
        if e.stimSource==1
            microStim(e.microStimDur);
        elseif e.stimSource==2
            if exist('stim_cmd','var')
                xippmex('stimseq',stim_cmd);
            else
                disp('XIPPMEX: Did not call xippmex function, no stim_cmd exists');
            end
        else
            error('Did not microstim, stimSource must be 1 or 2');
        end
        %             sendCode(codes.USTIM_OFF);
        if (e.toneWithStim)
            % generate a tone if desired
            fs=44100;
            t=0:1/fs:.12;
            y=sin(440*2*pi*t);
            y=y.*hann(length(y))';
            sound(y,fs);
        end
    else
        %            behav.microStimNextTrial = 0;
        sendCode(codes.ALIGN);
        sendCode(codes.NO_STIM);
    end
else
    sendCode(codes.NO_STIM);
end

% buffer = 5; %amount of additional time to wait for uStim to finish -acs02may2016
% if ~waitForMS(e.xippmexStimDur+buffer), %wait for the uStim to finish (plus some buffer time)
%     %If we want to monitor eye position during uStim we should put
%     %something here. -acs02may2016
% end;
% unixSetLevel(19,0); %lower the TTL bit to disable Trellis fast-settling -acs02may2016


if ~waitForDisplay(e.fixX,e.fixY,params.fixWinRad,2) %wait for object 2 to finish
    % hold fixation after microstim finishes
    if e.fixStaysOn,
        sendCode(codes.BROKE_FIX);
        msgAndWait('all_off');
        
        sendCode(codes.FIX_OFF);
        waitForMS(e.noFixTimeout);
        result = codes.BROKE_FIX;
        %if e.stimSource==2 % MAS maybe fixes xippmex hanging on restart of runex
        %    xippmex('close');
        %end
        return;
    end;
end
%toc

% choose a target location randomly around a circle
theta = deg2rad(e.saccadeDir);
newX = round(e.saccadeLength * cos(theta));
newY = round(e.saccadeLength * sin(theta));
msg('set 1 oval 0 %i %i %i %i %i %i',[newX newY e.fixRad e(1).fixColor(1) e(1).fixColor(2) e(1).fixColor(3)]);
sendCode(codes.FIX_MOVE);

if (e(1).saccadeInitiate > 0) % in case you don't want to have a saccade
    
    if waitForMS(e(1).saccadeInitiate,e(1).fixX,e(1).fixY,params.fixWinRad)
        % didn't leave fixation window
        sendCode(codes.NO_CHOICE);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        if numel(result)==1
            result = codes.NO_CHOICE;
        else
            result = [result codes.NO_CHOICE];
        end;
        return;
    end
    
    sendCode(codes.SACCADE);
    
    if ~waitForFixation(e(1).saccadeTime,newX,newY,params.targWinRad)
        % didn't reach target
        sendCode(codes.NO_CHOICE);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        if numel(result)==1
            result = codes.NO_CHOICE;
        else
            result = [result codes.NO_CHOICE];
        end;
        return;
    end
%     elapsed = toc(start);
    
    if ~waitForMS(e(1).stayOnTarget,newX,newY,params.targWinRad)
        % didn't stay on target long enough
        sendCode(codes.BROKE_TARG);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        if numel(result)==1
            result = codes.BROKE_TARG;
        else
            result = [result codes.BROKE_TARG];
        end;
        return;
    end
    
else
    if numel(result)==1
        result = codes.CORRECT;
    else
        result = [result codes.CORRECT];
    end;
end

% reward 
sendCode(codes.SACCADE);
sendCode(codes.CORRECT);
sendCode(codes.FIX_OFF);
sendCode(codes.REWARD);
giveJuice();

% only set this flag back to 1 if you complete a correct unstimulated
% trial
%     if (ustimflag == 0 & behav.microStimNextTrial == 0)
%         behav.microStimNextTrial = 1;
%     end

% a little extra time to make sure trials aren't too close together
waitForMS(e.postTrialWait);
%     if e.stimSource==2 % MAS maybe fixes xippmex hanging on restart of runex
%         xippmex('close');
%     end



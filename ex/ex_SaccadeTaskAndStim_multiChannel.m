function result = ex_SaccadeTaskAndStim_multiChannel(e)
% ex file: ex_SaccadeTask
%
% Uses codes in the 2000s range to indicate stimulus types
% 2001 - visually guided saccade
% 2002 - memory guided saccade
% 2003 - delayed visually guided saccade
%
% General file for memory and visually guided saccade tasks 
%
% XML REQUIREMENTS
% angle: angle of the target dot from the fixation point 0-360
% distance: the distance of the target in pixels from the fixation point
% size: the size of the target in pixels
% targetColor: a 3 element [R G B] vector for the target color
% timeToFix: time in ms for initial fixation
% noFixTimeout: timeout punishment for aborted trial (ms)
% targetOnsetDelay: time after fixation before target appears
% fixDuration: length of initial fixation required
% targetDuration: duration that target is on screen
% stayOnTarget: length of target fixation required
% saccadeInitiate: maximum time allowed to leave fixation window
% saccadeTime: maximum time allowed to reach target
%
% Modified:
%
% 2012/10/22 by Matt Smith - update to helperTargetColor and to make it
% work when multiple 'trials' are passed in 'e'.
%
% 2012/11/09 by Matt Smith - update to allow "extraBorder" as an optional
% parameter in the XML file
%
% 2014/12/10 by Matt Smith - trying to consolidate some stuff.
% InterTrialPause put in at the end
%
% 2015/08/14 by Matt Smith - added ACQUIRE_TARG code before stayOnTarget
% window
%
% 2015/08/14 by Matt Smith - added recentering when detecting saccade
%
    global params codes behav;

    e = e(1); %in case more than one 'trial' is passed at a time...
    
    objID = 2;
    
    result = 0;
    
    
    % SETUP USTIM COMMANDS
    % If you're stimulating via Ripple, setup the stimulation settings now
    if e.stimSource==2
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
        end
        stimChans=xippmex('elec','stim'); %can I move this up before initialization? -acs26apr2016
        if ~isscalar(e.xippmexStimAmp), e.xippmexStimAmp(e.xippmexStimChan<1) = []; end;%strip off amplitudes for channel values less than one (these are just placeholders). -ACS 16Jun2015
        e.xippmexStimChan(e.xippmexStimChan<1) = []; %strip off channel values less than one (these are just placeholders). -ACS 11Jun2015
        if any(setdiff(e.xippmexStimChan,stimChans))
            error('Unable to stimulate on requested channel %d',setdiff(e.xippmexStimChan,stimChans));
        end
        % turn on stimulation for requested channel(s)
        if ~isempty(e.xippmexStimChan) && any(e.xippmexStimAmp)
            xippmex('stim','enable',0); %disable stim first so step size can be set. -acs26apr2016
            % setup the microstim command
            stim_cmd = xippmexStimCmd(e.xippmexStimChan,e.xippmexPulseWidth,e.xippmexStimFreq,e.xippmexStimDur,e.xippmexStimAmp);
            xippmex('stim','enable',1); %enable stim
            xippmex('signal',e.xippmexStimChan,'stim',e.xippmexStimChan); %turn on stim
        end
    end
    
    % TASK
    % take radius and angle and figure out x/y for saccade direction
    theta = deg2rad(e.angle);
    newX = round(e.distance*cos(theta));
    newY = round(e.distance*sin(theta));
    
    % now figure out if you need to shift the fixation point around so the
    % saccade will fit on the screen (e.g., for an 'amp' series). The
    % "extraborder" keeps the dot from ever getting within that many pixels
    % of the edge of the screen
    if isfield(e,'extraBorder') 
        extraborder = e.extraBorder; % use XML file if it's there
    else
        extraborder = 10; % default to 10 pixels
    end
    
    if (abs(newX) + e.size > (params.displayWidth/2 - extraborder))
        %disp('X exceeds limit, moving fix pt');
        shiftX = abs(newX) + e.size - params.displayWidth/2 + extraborder;
        if newX > 0
            e.fixX = e.fixX - shiftX;
            newX = newX - shiftX;
        else
            e.fixX = e.fixX + shiftX;
            newX = newX + shiftX;
        end
    end
    if (abs(newY) + e.size > (params.displayHeight/2 - extraborder))
        %disp('Y exceeds limit, moving fix pt');
        shiftY = abs(newY) + e.size - params.displayHeight/2 + extraborder;
        if newY > 0
            e.fixY = e.fixY - shiftY;
            newY = newY - shiftY;
        else
            e.fixY = e.fixY + shiftY;
            newY = newY + shiftY;
        end
    end
    
    % obj 1 is fix pt, obj 2 is target, diode attached to obj 2
    msg('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad e.fixColor(1) e.fixColor(2) e.fixColor(3)]);
    msg('set 2 oval 0 %i %i %i %i %i %i',[newX newY e.size e.targetColor(1) e.targetColor(2) e.targetColor(3)]);
    if isfield(e,'helperTargetColor')
        msg('set 3 oval 0 %i %i %i %i %i %i',[newX newY e.size e.helperTargetColor(1) e.helperTargetColor(2) e.helperTargetColor(3)]);
    end
    msg(['diode ' num2str(objID)]);    
    
%     msgAndWait('ack'); %commented out 03Apr2013, seemed to be causing problems....

    msgAndWait('obj_on 1');
    
    unixSendPulse(19,10); % This used to be above the 'ack' two lines up, now I moved it so it aligns well to FIX_ON for alignment between this pulse and the FIX_ON code
                      % I moved this on 03/25/2019 - MAS
    sendCode(codes.FIX_ON);
    
    if ~waitForFixation(e.timeToFix,e.fixX,e.fixY,params.fixWinRad);
        % failed to achieve fixation
        sendCode(codes.IGNORED);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        waitForMS(e.noFixTimeout);
        result = codes.IGNORED;
        return;
    end
    sendCode(codes.FIXATE);
    if isfield(e,'fixJuice')
        if rand < e.fixJuice, giveJuice(1); end;
    end
    
    if ~waitForMS(e.targetOnsetDelay,e.fixX,e.fixY,params.fixWinRad)
        % hold fixation before stimulus comes on
        sendCode(codes.BROKE_FIX);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        waitForMS(e.noFixTimeout);
        result = codes.BROKE_FIX;
        return;
    end
    
    % Decision point - is this VisGuided, Delay-VisGuided, or Mem-Guided
    if (e.targetOnsetDelay == e.fixDuration)
        % Visually Guided Saccade
        sendCode(2001); % send code specific to this stimulus type
        % turn fix pt off and target on simultaneously
        msg('queue_begin');
        msg('obj_on 2');
        msg('obj_off 1'); 
        msgAndWait('queue_end');
        sendCode(codes.FIX_OFF);
        sendCode(codes.TARG_ON);
    elseif ((e.targetOnsetDelay + e.targetDuration) < e.fixDuration)
        % Memory Guided Saccade
        sendCode(2002); % send code specific to this stimulus type
        msgAndWait('obj_on 2');
        sendCode(codes.TARG_ON);

        if ~waitForMS(e.targetDuration,e.fixX,e.fixY,params.fixWinRad)
            % didn't hold fixation during target display
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.TARG_OFF);
            sendCode(codes.FIX_OFF);
            waitForMS(e.noFixTimeout);
            result = codes.BROKE_FIX;
            return;
        end
        
        msgAndWait('obj_off 2');
        sendCode(codes.TARG_OFF);
        
        % WAIT FOR USTIM
        if ~waitForMS(e.preStimFix,e.fixX,e.fixY,params.fixWinRad)
            % hold fixation before uStim comes on
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
            
        % USTIM
        ustimflag = 0;
        deepPink = [255 20 147];
        fixColor = [255 255 0];
        unixSetLevel(19,1); %raise the TTL bit to enable Trellis fast-settling. -acs02may2016
        if (e.microStimDur > 0)
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
        
        waitRemainder = e.fixDuration - (e.targetOnsetDelay + e.targetDuration + e.preStimFix + e.waitForStim);
        if ~waitForMS(waitRemainder,e.fixX,e.fixY,params.fixWinRad)
            % didn't hold fixation during period after target offset
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.noFixTimeout);
            result = codes.BROKE_FIX;
            return;
        end

        msgAndWait('obj_off 1'); 
        sendCode(codes.FIX_OFF);
    elseif (((e.targetOnsetDelay + e.targetDuration) > e.fixDuration) && (e.targetOnsetDelay < e.fixDuration))
        % Delayed Visually Guided Saccade
        sendCode(2003); % send code specific to this stimulus type
        msgAndWait('obj_on 2');
        sendCode(codes.TARG_ON);

        waitRemainder = e.fixDuration - e.targetOnsetDelay;
        if ~waitForMS(waitRemainder,e.fixX,e.fixY,params.fixWinRad)
            % didn't hold fixation during target display
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.TARG_OFF);
            sendCode(codes.FIX_OFF);
            waitForMS(e.noFixTimeout);
            result = codes.BROKE_FIX;
            return;
        end
        
        msgAndWait('obj_off 1'); 
        sendCode(codes.FIX_OFF);
    else
        warning('*** EX_SACCADETASK: Condition not valid');
        %%% should there be some other behavior here?
        return;
    end
    
    % detect saccade here - we're just going to count the time leaving the
    % fixation window as the saccade but it would be better to actually
    % analyze the eye movements.
    %
    % 2015/08/14 MAS - changed code below to adjust eye window around
    % current eye position to make it easier to detect saccades (especially
    % small ones)
    %
    %    if waitForMS(e.saccadeInitiate,e.fixX,e.fixY,params.fixWinRad)
    if params.recenterFixWin
        newFixWinRad = params.sacWinRad;
    else
        newFixWinRad = params.fixWinRad;
    end

    if waitForMS(e.saccadeInitiate,e.fixX,e.fixY,newFixWinRad,'recenterFlag',params.recenterFixWin)
        % didn't leave fixation window
        sendCode(codes.NO_CHOICE);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        result = codes.NO_CHOICE;
        return;
    end

    sendCode(codes.SACCADE);

    if isfield(e,'helperTargetColor')
        %% turn on a target for guidance if 'helperTargetColor' param is present
        msg('obj_on 3');
        sendCode(codes.TARG_ON);
    end
    
    if ~waitForFixation(e.saccadeTime,newX,newY,params.targWinRad)
        % didn't reach target
        sendCode(codes.NO_CHOICE);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        result = codes.NO_CHOICE;
        return;
    end
    
    % MAS 2015/08/14 added this code so we know when he reaches the window
    sendCode(codes.ACQUIRE_TARG);
    
    
    if ~waitForMS(e.stayOnTarget,newX,newY,params.targWinRad)
        % didn't stay on target long enough
        sendCode(codes.BROKE_TARG);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        result = codes.BROKE_TARG;
        return;
    end

    sendCode(codes.FIXATE);
    sendCode(codes.CORRECT);
    sendCode(codes.TARG_OFF);
    sendCode(codes.REWARD);
    giveJuice();
    result = 1;

    if isfield(e,'InterTrialPause')
        waitForMS(e.InterTrialPause); %this was for Wile E to lengthen time between trials SBK
    end
    

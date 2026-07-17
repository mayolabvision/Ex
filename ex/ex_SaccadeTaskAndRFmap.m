function result = ex_SaccadeTaskAndRFmap(e)
% ex file: ex_SaccadeTaskAndRFmap
%
% Combination of ex_activeFixation (RF mapping) and ex_SaccadeTask_varDelays
% (memory/visually guided saccade). The trial runs exactly like a normal
% memory-guided saccade task (fixate, peripheral target flashes, delay,
% fixation point extinguishes as the go-cue, saccade to the remembered
% target location, hold), but starting the moment initial fixation is
% acquired, a second "distractor" dot begins flashing at a sequence of
% locations around the screen (one dot visible at a time, cycling through
% a shuffled position grid with no repeats until the grid is exhausted).
% This distractor flashing runs continuously and independently of the
% saccade-task timeline/logic, all the way through target onset, delay,
% the go-cue, the saccade, and the post-saccade hold, stopping only when
% the trial ends (either on a break/abort via 'all_off', or naturally once
% the ex file returns after reward).
%
% Uses codes in the 2000s range to indicate saccade stimulus types
% (unchanged from ex_SaccadeTask_varDelays):
% 2001 - visually guided saccade
% 2002 - memory guided saccade
% 2003 - delayed visually guided saccade
%
% Objects:
% 1 - fixation point
% 2 - saccade target (diode attached)
% 3 - helper target (optional)
% 4 - antisaccade "acquired window" helper target (optional)
% 5 - RF-map distractor dot
%
% XML REQUIREMENTS (saccade task, same as ex_SaccadeTask_varDelays)
% angle, distance, size, targetColor, stimType, fixX, fixY, fixRad,
% fixColor, timeToFix, noFixTimeout, targetOnsetDelay, targetDuration,
% delay, stayOnTarget, saccadeInitiate, saccadeTime, targWinRadScale,
% incorrectTimeout, isi. Optional: extraBorder, fixJuice, helperTargetColor,
% helperTargetRatio, antiSaccade, fixColorAnti, targWinRadScaleAnti,
% InterTrialPause.
%
% XML REQUIREMENTS (RF-map distractor dot)
% dotXPositions: column vector of candidate X offsets (px) from screen
%   center, e.g. [-448;-320;-192;-64;64;192;320;448]
% dotYPositions: column vector of candidate Y offsets (px) from screen
%   center, e.g. [-320;-192;-64;64;192;320]
% dotRad: radius of the distractor dot (px)
% dotColor: [R;G;B] color of the distractor dot
% dotAlpha: transparency of the distractor dot, 0-255 (255 = opaque)
% dotDur: duration each distractor flash stays on screen (ms)
% dotISI: gap between distractor flashes (ms)
%
% Note: the distractor grid is defined in absolute screen coordinates
% (like the original RF mapping task), independent of fixX/fixY.
%
% Last modified:
% 2026/07/17 by KK Noneman - created by combining ex_activeFixation and
% ex_SaccadeTask_varDelays

    global params codes behav;

    e = e(1); %in case more than one 'trial' is passed at a time...

    objID = 2;
    rfObjID = 5;

    result = 0;

    % Forces saccade type right away, allowing for more flexible timings
    if e.stimType == 2001 % visually-guided saccade
        e.fixDuration = e.targetOnsetDelay;
    elseif e.stimType == 2002 % memory-guided saccade
        e.fixDuration = e.targetOnsetDelay + (e.targetDuration + e.delay);
    else % delayed visually-guided saccade
        e.fixDuration = e.targetOnsetDelay + e.delay;
    end

    % take radius and angle and figure out x/y for saccade direction
    theta = deg2rad(e.angle);
    newX = round(e.distance*cos(theta));
    newY = round(e.distance*sin(theta));

    % Set helpTarg value to 0 and change to 1 if it gets turned on
    helpTarg = 0;

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
    if isfield(e, 'antiSaccade') & e.antiSaccade == 1
        msg('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad e.fixColorAnti(1) e.fixColorAnti(2) e.fixColorAnti(3)]);
    else
        msg('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad e.fixColor(1) e.fixColor(2) e.fixColor(3)]);
    end
    % Target
    msg('set 2 oval 0 %i %i %i %i %i %i',[newX newY e.size e.targetColor(1) e.targetColor(2) e.targetColor(3)]);
    % Helper Target
    if isfield(e, {'helperTargetColor', 'antiSaccade'}) & e.antiSaccade == 1
        msg('set 3 oval 0 %i %i %i %i %i %i',[-newX -newY e.size e.helperTargetColor(1) e.helperTargetColor(2) e.helperTargetColor(3)]);
        msg('set 4 oval 0 %i %i %i %i %i %i',[-newX -newY e.size e.helperTargetColor(1) e.helperTargetColor(2) e.helperTargetColor(3)]);
    elseif isfield(e, 'helperTargetColor')
        msg('set 3 oval 0 %i %i %i %i %i %i',[newX newY e.size e.helperTargetColor(1) e.helperTargetColor(2) e.helperTargetColor(3)]);
    end
    msg(['diode ' num2str(objID)]);

    msgAndWait('obj_on 1');
    sendCode(codes.FIX_ON);

    if ~waitForFixation(e.timeToFix,e.fixX,e.fixY,params.fixWinRad)
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
        if rand < e.fixJuice, giveJuice(1); end
    end

    % initial fixation is acquired - start the RF-map distractor dot
    % cycling now, and keep it running for the rest of the trial
    dotState = rfDotInit(e,rfObjID);

    [ok,dotState] = waitForMSFlash(e.targetOnsetDelay,e.fixX,e.fixY,params.fixWinRad,dotState);
    if ~ok
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

        [ok,dotState] = waitForMSFlash(e.targetDuration,e.fixX,e.fixY,params.fixWinRad,dotState);
        if ~ok
            % didn't hold fixation during target display
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.TARG_OFF);
            sendCode(codes.FIX_OFF);
            waitForMS(2500);
            result = codes.BROKE_FIX;
            return;
        end

        msgAndWait('obj_off 2');
        sendCode(codes.TARG_OFF);

        [ok,dotState] = waitForMSFlash(e.delay,e.fixX,e.fixY,params.fixWinRad,dotState);
        if ~ok
            % didn't hold fixation during period after target offset
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(2500);
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
        [ok,dotState] = waitForMSFlash(waitRemainder,e.fixX,e.fixY,params.fixWinRad,dotState);
        if ~ok
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
        warning('*** EX_SACCADETASKANDRFMAP: Condition not valid');
        return;
    end

    % detect saccade here - we're just going to count the time leaving the
    % fixation window as the saccade but it would be better to actually
    % analyze the eye movements.
    if params.recenterFixWin
        newFixWinRad = params.sacWinRad;
    else
        newFixWinRad = params.fixWinRad;
    end

    [ok,dotState] = waitForMSFlash(e.saccadeInitiate,e.fixX,e.fixY,newFixWinRad,dotState,'recenterFlag',params.recenterFixWin);
    if ok
        % didn't leave fixation window
        sendCode(codes.NO_CHOICE);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        waitForMS(e.incorrectTimeout)
        result = codes.NO_CHOICE;
        return;
    end

    sendCode(codes.SACCADE);

    if isfield(e,'helperTargetColor')
        %% turn on a target for guidance if 'helperTargetColor' param is present
        if isfield(e, 'helperTargetRatio')
            % turn on a helper in a defined ration of trials
            if rand < e.helperTargetRatio
                msg('obj_on 3')
                sendCode(codes.TARG_ON);
                helpTarg = 1;
            end
        else
            msg('obj_on 3');
            sendCode(codes.TARG_ON);
        end
    end

    if isfield(e, 'antiSaccade') & e.antiSaccade == 1

        targetWindowRadius = round(e.targWinRadScaleAnti*e.distance);

        [choice,dotState] = waitForFixationFlash(e.saccadeTime,-newX,-newY,targetWindowRadius,dotState);
        if ~choice
            % didn't reach target
            sendCode(codes.NO_CHOICE);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.incorrectTimeout)
            result = codes.NO_CHOICE;
            return;
        end

        sendCode(codes.ACQUIRE_TARG);

        if helpTarg == 0
            msg('obj_on 4');
            sendCode(codes.TARG_ON);
        end

        [ok,dotState] = waitForMSFlash(e.stayOnTarget,-newX,-newY,targetWindowRadius,dotState);
        if ~ok
            % didn't stay on target long enough
            sendCode(codes.BROKE_TARG);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.incorrectTimeout)
            result = codes.BROKE_TARG;
            return;
        end

    else

        targetWindowRadius = round(e.targWinRadScale*e.distance);

        [choice,dotState] = waitForFixationFlash(e.saccadeTime,newX,newY,targetWindowRadius,dotState);
        if ~choice
            % didn't reach target
            sendCode(codes.NO_CHOICE);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.incorrectTimeout)
            result = codes.NO_CHOICE;
            return;
        end

        sendCode(codes.ACQUIRE_TARG);

        [ok,dotState] = waitForMSFlash(e.stayOnTarget,newX,newY,targetWindowRadius,dotState);
        if ~ok
            % didn't stay on target long enough
            sendCode(codes.BROKE_TARG);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.incorrectTimeout)
            result = codes.BROKE_TARG;
            return;
        end

    end

    sendCode(codes.FIXATE);
    sendCode(codes.CORRECT);
    sendCode(codes.TARG_OFF);
    sendCode(codes.REWARD);
    giveJuice();
    result = 1;

    if isfield(e,'InterTrialPause')
        waitForMS(e.InterTrialPause);
    end

end

% ---------------------------------------------------------------------
% RF-map distractor dot helpers
% ---------------------------------------------------------------------

function dotState = rfDotInit(e,objID)
% builds the shuffled position grid and initial (off) state for the
% RF-map distractor dot. The first call to rfDotService will trigger the
% first flash immediately, regardless of dotISI.

    [gx,gy] = ndgrid(e.dotXPositions(:),e.dotYPositions(:));
    dotState.grid = [gx(:) gy(:)];
    dotState.queue = [];
    dotState.lastIdx = [];
    dotState.objID = objID;
    dotState.dotRad = e.dotRad;
    dotState.dotColor = e.dotColor;
    dotState.dotAlpha = e.dotAlpha;
    dotState.dotDur = e.dotDur;
    dotState.dotISI = e.dotISI;
    dotState.phase = 'off';
    dotState.phaseTic = tic;
    dotState.needsInit = true;
end

function dotState = rfDotService(dotState)
% called once per polling iteration of the flash-aware wait functions;
% toggles the distractor dot on/off on its own schedule, independent of
% whatever fixation/saccade logic is currently running.

    global codes;

    if dotState.needsInit
        dotState = rfDotBeginFlash(dotState);
        dotState.needsInit = false;
        return;
    end

    elapsedMS = toc(dotState.phaseTic)*1000;

    switch dotState.phase
        case 'on'
            if elapsedMS >= dotState.dotDur
                msg('obj_off %d',dotState.objID);
                sendCode(codes.STIM_OFF);
                dotState.phase = 'off';
                dotState.phaseTic = tic;
            end
        case 'off'
            if elapsedMS >= dotState.dotISI
                dotState = rfDotBeginFlash(dotState);
            end
    end
end

function dotState = rfDotBeginFlash(dotState)
% pops the next position off the shuffled queue (reshuffling once
% exhausted, avoiding an immediate repeat of the last position shown) and
% turns the distractor dot on there.

    global codes;

    if isempty(dotState.queue)
        newOrder = randperm(size(dotState.grid,1));
        if ~isempty(dotState.lastIdx) && numel(newOrder)>1 && newOrder(1)==dotState.lastIdx
            newOrder([1 2]) = newOrder([2 1]);
        end
        dotState.queue = newOrder;
    end

    idx = dotState.queue(1);
    dotState.queue(1) = [];
    dotState.lastIdx = idx;

    pos = dotState.grid(idx,:);
    msg('set %d oval 0 %i %i %i %i %i %i %.2f', ...
        [dotState.objID pos(1) pos(2) dotState.dotRad dotState.dotColor(1) dotState.dotColor(2) dotState.dotColor(3) dotState.dotAlpha]);
    msg('obj_on %d',dotState.objID);
    sendCode(codes.STIM_ON);

    dotState.phase = 'on';
    dotState.phaseTic = tic;
end

% ---------------------------------------------------------------------
% flash-aware wait functions (mirror waitForMS.m / waitForFixation.m, but
% additionally service the RF-map distractor dot on every poll)
% ---------------------------------------------------------------------

function [trialSuccess,dotState] = waitForMSFlash(waitTime,fixX,fixY,r,dotState,varargin)
% like waitForMS, but also keeps the RF-map distractor dot flashing while
% it waits/checks fixation.

    global params;

    winColors = [255 255 0];
    recenterFlag = false;
    if ~isempty(varargin)
        vx = 1;
        while vx <= numel(varargin)
            switch class(varargin{vx})
                case 'char'
                    recenterFlag = varargin{vx+1};
                    vx = vx+2;
                otherwise
                    if ~isempty(varargin{vx})
                        winColors = varargin{vx};
                    end
                    vx = vx+1;
            end
        end
    end

    if recenterFlag
        d = samp;
        eyePos = projectCalibration(d(end,:));
        fixX = eyePos(1);
        fixY = eyePos(2);
    end

    drawFixationWindows(fixX,fixY,r,winColors);

    trialSuccess = 1;
    thisStart = tic;

    while (toc(thisStart)*1000) <= waitTime
        loopTop = GetSecs;
        dotState = rfDotService(dotState);
        d = samp;
        eyePos = projectCalibration(d(end,:));
        relPos = bsxfun(@minus,eyePos(:),[fixX;fixY]);
        switch size(r,1)
            case 1
                inWin = sum(relPos.^2,1)<r.^2;
            case 2
                inWin = all(abs(relPos)<abs(r),1);
            otherwise
                error('EX:waitForMSFlash:badRadius','Radius must have exactly 1 or 2 rows');
        end

        if keyboardEvents()||~inWin
            trialSuccess = 0;
            break;
        end
        if (GetSecs-loopTop)>params.waitForTolerance, warning('waitFor:tooSlow','waitForMSFlash exceeded latency tolerance - %s',datestr(now)); end
    end
    drawFixationWindows()
end

function [choice,dotState] = waitForFixationFlash(waitTime,fixX,fixY,r,dotState,varargin)
% like waitForFixation, but also keeps the RF-map distractor dot flashing
% while it waits for the eye to enter the target window.

    global params;

    yellow = [255 255 0];
    if ~isempty(varargin)
        winColors = varargin{1};
        if isempty(winColors)
            winColors = yellow;
        end
    else
        winColors = yellow;
    end

    drawFixationWindows(fixX,fixY,r,winColors);

    thisStart = tic;

    choice = 0;
    while (toc(thisStart)*1000)<=waitTime && choice<1
        loopTop = GetSecs;
        dotState = rfDotService(dotState);
        d = samp;
        eyePos = projectCalibration(d(end,:));
        relPos = bsxfun(@minus,eyePos(:),[fixX;fixY]);
        switch size(r,1)
            case 1
                inWin = sum(relPos.^2,1)<r.^2;
            case 2
                inWin = all(abs(relPos)<abs(r),1);
            otherwise
                error('EX:waitForFixationFlash:badRadius','Radius must have exactly 1 or 2 rows');
        end
        choice = find([true,inWin],1,'last')-1;

        if keyboardEvents()
            choice = 0;
            break;
        end
        if (GetSecs-loopTop)>params.waitForTolerance, warning('waitFor:tooSlow','waitForFixationFlash exceeded latency tolerance - %s',datestr(now)); end
    end
    drawFixationWindows()
end

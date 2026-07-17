function result = ex_PursuitTaskAndRFmap(e)
% ex file: ex_PursuitTaskAndRFmap
%
% Combination of ex_activeFixation (RF mapping) and ex_PursuitTask (smooth
% pursuit). The trial runs exactly like a normal pursuit task (fixate, a
% target appears and translates across the screen, subject must track it
% with their eyes, then hold at the endpoint), but starting the moment
% initial fixation is acquired, a second "distractor" dot begins flashing
% at a sequence of locations around the screen (one dot visible at a
% time, cycling through a shuffled position grid with no repeats until
% the grid is exhausted). This distractor flashing runs continuously and
% independently of the pursuit-task timeline/logic, all the way through
% the pre-pursuit fixation hold, the pursuit itself, and the post-pursuit
% hold at the endpoint, stopping only when the trial ends (either on a
% break/abort via 'all_off', or naturally once the ex file returns after
% reward).
%
% Objects:
% 1 - fixation point
% 2 - pursuit target (moving, diode attached)
% 3 - pursuit endpoint target
% 4 - RF-map distractor dot
%
% XML REQUIREMENTS (pursuit task, same as ex_PursuitTask)
% crossingTime, size, fixX, fixY, fixRad, fixColor, targetColor,
% timeToFix, pursuitDuration, pursuitRadius, noFixTimeout, stayOnTarget,
% endPursuitWinScale, fixDuration, pursuitSpeed, angle, jump. Optional:
% fixJuice, InterTrialPause.
%
% XML REQUIREMENTS (RF-map distractor dot)
% dotXPositions: column vector of candidate X offsets (px) from screen
%   center, e.g. [-448;-320;-192;-64;64;192;320;448]
% dotYPositions: column vector of candidate Y offsets (px) from screen
%   center, e.g. [-320;-192;-64;64;192;320]
% dotRad: radius of the distractor dot (px)
% dotColor: [R;G;B] color of the distractor dot
% dotAlpha: transparency of the distractor dot, 0-255 (255 = opaque)
% dotDur: duration each distractor flash stays on screen, IN MILLISECONDS
%   (not frames - see note below)
% dotISI: gap between distractor flashes (ms)
%
% Note: the distractor grid is defined in absolute screen coordinates
% (like the original RF mapping task), independent of fixX/fixY.
%
% Note on dotDur vs. the old rfMapping_dots.xml 'frameCount' param: those
% are NOT the same thing and are not interchangeable by just copying the
% number over. frameCount was frames of display refresh, counted and
% auto-turned-off by the display computer itself (showex.m), completely
% independent of the control computer. dotDur is milliseconds of
% wall-clock time, tracked here on the control computer with tic/toc and
% turned on/off explicitly via 'obj_on'/'obj_off' messages, interleaved
% every polling iteration with the pursuit-task's own eye-position checks.
% This control-side approach is what makes it possible to keep flashing
% the distractor independently while a totally different, already-running
% timeline (fixation hold, pursuit tracking, endpoint hold) is being
% tracked at the same time - a frameCount-based dot can't be interleaved
% that way since its on/off timing lives entirely on the display side.
% Converting an old frameCount value to dotDur: dotDur_ms = frameCount /
% refreshHz * 1000 (e.g. 20 frames at 60 Hz = 333 ms).
%
% Last modified:
% 2026/07/17 by KK Noneman - created by combining ex_activeFixation and
% ex_PursuitTask

    global params codes behav;

    e = e(1); %in case more than one 'trial' is passed at a time...

    objID = 2;
    rfObjID = 4;

    result = 0;

    % Find Jumpsize
    e.jumpSize = (e.crossingTime/1000)*e.pursuitSpeed*e.jump;

    % Find endpoint
    x_endpoint = round(e.fixX + e.jumpSize*deg2pix(1)*cos(deg2rad(e.angle)) + e.pursuitSpeed*deg2pix(1)*cos(deg2rad(e.angle))*((e.pursuitDuration+100)/1000));
    y_endpoint = round(e.fixY + e.jumpSize*deg2pix(1)*sin(deg2rad(e.angle)) + e.pursuitSpeed*deg2pix(1)*sin(deg2rad(e.angle))*((e.pursuitDuration+100)/1000));

    % obj 1 is fix pt, obj 2 is target, diode attached to obj 2
    msg('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad e.fixColor(1) e.fixColor(2) e.fixColor(3)]);
    msg('set 2 movingoval 0 %i %i %i %i %i %f %i %i %i',[e.fixX e.fixY e.size e.pursuitSpeed e.angle e.jumpSize e.targetColor(1) e.targetColor(2) e.targetColor(3)]);
    msg('set 3 oval 0 %i %i %i %i %i %i',[x_endpoint y_endpoint e.size e.targetColor(1) e.targetColor(2) e.targetColor(3)]);
    msg(['diode ' num2str(objID)]);

    msgAndWait('obj_on 1');

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

    % initial fixation is acquired - start the RF-map distractor dot
    % cycling now, and keep it running for the rest of the trial
    dotState = rfDotInit(e,rfObjID);

    [ok,dotState] = waitForMSFlash(e.fixDuration,e.fixX,e.fixY,params.fixWinRad,dotState);
    if ~ok
        % hold fixation before stimulus comes on
        sendCode(codes.BROKE_FIX);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        waitForMS(e.noFixTimeout);
        result = codes.BROKE_FIX;
        return;
    end

    % turn fix pt off and target on simultaneously
    msgAndWait('obj_switch -1 2');
    pursuitStartTime = GetSecs;
    sendCode(codes.FIX_OFF);
    sendCode(31791); % Custom code PURSUIT_TARG_ON - for pursuit target onset

    [ok,dotState] = waitForPursuitFlash(e.pursuitDuration,pursuitStartTime,e.fixX,e.fixY,e.pursuitRadius,e.pursuitSpeed,e.angle,e.jumpSize,dotState);
    if ~ok
        % keep eye position on target
        sendCode(codes.BROKE_PURSUIT);
        msgAndWait('all_off');
        sendCode(12697); % Custom code PURSUIT_TARG_OFF - for pursuit target offset
        waitForMS(e.noFixTimeout);
        result = codes.BROKE_PURSUIT;
        return;
    end

    % turn target off and turn on fixation target
    msgAndWait('obj_off 2')
    sendCode(12697); % Custom code PURSUIT_TARG_OFF - for pursuit target offset
    msgAndWait('obj_on 3')
    sendCode(codes.TARG3_ON);

    [ok,dotState] = waitForMSFlash(e.stayOnTarget,x_endpoint,y_endpoint,params.fixWinRad*e.endPursuitWinScale,dotState);
    if ~ok
        % hold fixation before stimulus comes on
        sendCode(codes.BROKE_TARG);
        msgAndWait('all_off');
        sendCode(codes.TARG3_OFF);
        waitForMS(e.noFixTimeout);
        result = codes.BROKE_TARG;
        return;
    end

    msgAndWait('all_off');
    sendCode(codes.TARG3_OFF);
    sendCode(codes.CORRECT);
    sendCode(codes.REWARD)
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

function dotState = rfDotService(dotState,remainingMS)
% called once per polling iteration of the flash-aware wait functions;
% toggles the distractor dot on/off on its own schedule, independent of
% whatever fixation/pursuit logic is currently running.
%
% remainingMS is how much time is left in the CURRENT wait call (e.g. the
% stayOnTarget hold). A new flash is only started if there's enough of
% that time left for it to finish (dotDur) - otherwise it's held off
% until the next wait call, so a flash never gets truncated by the trial
% ending (or by 'all_off') partway through.

    global codes;

    if dotState.needsInit
        if remainingMS >= dotState.dotDur
            dotState = rfDotBeginFlash(dotState);
            dotState.needsInit = false;
        end
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
            if elapsedMS >= dotState.dotISI && remainingMS >= dotState.dotDur
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
% flash-aware wait functions (mirror waitForMS.m / waitForPursuit.m, but
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
        remainingMS = waitTime - toc(thisStart)*1000;
        dotState = rfDotService(dotState,remainingMS);
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

function [trialSuccess,dotState] = waitForPursuitFlash(waitTime,pursuitStartTime,startX,startY,pursuitRadius,pursuitSpeed,angle,jumpSize,dotState,varargin)
% like waitForPursuit, but also keeps the RF-map distractor dot flashing
% while it tracks the eye against the moving pursuit target.

    global params;

    winColors = [255 255 0];
    pursuitRadius = pursuitRadius*deg2pix(1); %# of pixels per 1 degree
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
        startX = eyePos(1);
        startY = eyePos(2);
    end

    time_weight = 0:1/3:1;

    horz_input = startX + jumpSize*deg2pix(1)*cos(deg2rad(angle)) + pursuitSpeed*deg2pix(1)*cos(deg2rad(angle))*(waitTime/1000)*(time_weight);
    vert_input = startY + jumpSize*deg2pix(1)*sin(deg2rad(angle)) + pursuitSpeed*deg2pix(1)*sin(deg2rad(angle))*(waitTime/1000)*(time_weight);

    drawFixationWindows(horz_input,vert_input,ones(1,numel(time_weight))*pursuitRadius,ones(numel(time_weight),1)*winColors)

    trialSuccess = 1;
    thisStart = tic;

    while (toc(thisStart)*1000) <= waitTime
        xPos = startX + jumpSize*deg2pix(1)*cos(deg2rad(angle)) + pursuitSpeed*deg2pix(1)*cos(deg2rad(angle))*(GetSecs-pursuitStartTime);
        yPos = startY + jumpSize*deg2pix(1)*sin(deg2rad(angle)) + pursuitSpeed*deg2pix(1)*sin(deg2rad(angle))*(GetSecs-pursuitStartTime);

        loopTop = GetSecs;
        remainingMS = waitTime - toc(thisStart)*1000;
        dotState = rfDotService(dotState,remainingMS);
        d = samp;
        eyePos = projectCalibration(d(end,:));
        relPos = bsxfun(@minus,eyePos(:),[xPos;yPos]);
        switch size(pursuitRadius,1)
            case 1
                inWin = sum(relPos.^2,1)<pursuitRadius.^2;
            case 2
                inWin = all(abs(relPos)<abs(pursuitRadius),1);
            otherwise
                error('EX:waitForPursuitFlash:badRadius','Radius must have exactly 1 or 2 rows');
        end

        if keyboardEvents()||~inWin
            trialSuccess = 0;
            break;
        end
        if (GetSecs-loopTop)>params.waitForTolerance, warning('waitFor:tooSlow','waitForPursuitFlash exceeded latency tolerance - %s',datestr(now)); end
    end
    drawFixationWindows()
end

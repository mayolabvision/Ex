function result = ex_SaccadeTaskAndRFmap_Catch(e)
% ex file: ex_SaccadeTaskAndRFmap_Catch
%
% Catch-trial variant of ex_SaccadeTaskAndRFmap. Full trial timeline:
%   fixation acquired
%   -> preStimFix hold (RF distractor NOT yet flashing)
%   -> RF distractor starts flashing
%   -> targetOnsetDelay hold (distractor flashing)
%   -> peripheral target flashes on/off per stimType timing (distractor
%      flashing) - target is never actually saccaded to
%   -> delay hold (distractor flashing)
%   -> catchLatencyBuffer hold on the ORIGINAL fixation point (distractor
%      flashing) - fixed, standing in for the saccade initiation+
%      execution time a real trial would spend here (there is no go-cue
%      and no saccade in this task, but the trial should still take
%      about as long as a real one)
%   -> stayOnTarget hold on the ORIGINAL fixation point (distractor
%      flashing) - drawn identically to the real task's target-hold
%      requirement, just spent continuing to fixate the original spot
%      instead of holding on a peripheral target
%   -> RF distractor explicitly stops flashing
%   -> postTargetBuffer hold on the ORIGINAL fixation point (distractor
%      OFF)
%   -> reward, end of trial
% The fixation point itself NEVER turns off during any of this - there is
% no go-cue and no saccade anywhere in this task, and none of the
% saccade-detection/target-acquisition machinery
% (saccadeInitiate/saccadeTime/targWinRadScale/antiSaccade/helperTarget*)
% ever runs.
%
% XML PARAMETERS ARE IDENTICAL TO dirmemAndRFmap.xml (including
% preStimFix and postTargetBuffer), with one addition: catchLatencyBuffer
% (ms) - see above. Recommended: 250.
%
% Every other xml field (saccadeInitiate, saccadeTime, targWinRadScale,
% antiSaccade, fixColorAnti, targWinRadScaleAnti, helperTargetColor,
% helperTargetRatio) is still required/read the same way as
% ex_SaccadeTaskAndRFmap - purely so the initial object setup matches and
% the two xmls stay directly comparable/interchangeable - but plays no
% role in this file's catch-trial hold logic, since there is no saccade
% and no target window to search for here.
%
% Objects:
% 1 - fixation point (NEVER turns off during the trial body - only at
%     the very end, right before reward)
% 2 - saccade target (still flashes on/off per stimType, exactly like
%     the real task, but is never actually saccaded to)
% 3 - helper target (defined for xml/object-setup compatibility, never
%     turned on - there is no saccade phase to trigger it)
% 4 - antisaccade "acquired window" helper target (defined for
%     compatibility, never turned on)
% 5 - RF-map distractor dot
%
% Failures during ANY fixation-hold period in this file (including the
% new catchLatencyBuffer/stayOnTarget catch-hold) send BROKE_FIX, since
% the requirement throughout the entire trial is fixation on the
% ORIGINAL spot - there is never a target-window acquisition here, so
% BROKE_TARG/NO_CHOICE never apply.
%
% Last modified:
% 2026/07/17 by KK Noneman - created as a catch-trial variant of
% ex_SaccadeTaskAndRFmap

    global params codes behav;

    e = e(1); %in case more than one 'trial' is passed at a time...

    objID = 2;
    rfObjID = 5;

    result = 0;

    % Forces saccade type right away, allowing for more flexible timings
    % (kept identical to ex_SaccadeTaskAndRFmap purely so the
    % target-presentation timeline matches the real task - fixDuration is
    % only used below to decide which of the 3 branches to take)
    if e.stimType == 2001 % visually-guided saccade
        e.fixDuration = e.targetOnsetDelay;
    elseif e.stimType == 2002 % memory-guided saccade
        e.fixDuration = e.targetOnsetDelay + (e.targetDuration + e.delay);
    else % delayed visually-guided saccade
        e.fixDuration = e.targetOnsetDelay + e.delay;
    end

    % take radius and angle and figure out x/y for the (never-saccaded-to)
    % target position
    theta = deg2rad(e.angle);
    newX = round(e.distance*cos(theta));
    newY = round(e.distance*sin(theta));

    % now figure out if you need to shift the fixation point around so the
    % target will fit on the screen (e.g., for an 'amp' series). The
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

    % obj 1 is fix pt, obj 2 is target, diode attached to obj 2. Kept
    % identical to ex_SaccadeTaskAndRFmap (including the antiSaccade
    % fixation color and helper-target objects) purely for xml/object-setup
    % compatibility between the two tasks - antiSaccade/helperTarget* have
    % no effect on the catch-trial hold logic itself.
    if isfield(e, 'antiSaccade') & e.antiSaccade == 1
        msg('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad e.fixColorAnti(1) e.fixColorAnti(2) e.fixColorAnti(3)]);
    else
        msg('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad e.fixColor(1) e.fixColor(2) e.fixColor(3)]);
    end
    % Target
    msg('set 2 oval 0 %i %i %i %i %i %i',[newX newY e.size e.targetColor(1) e.targetColor(2) e.targetColor(3)]);
    % Helper Target (never turned on in this file - there is no saccade
    % phase to trigger it - but still defined for xml compatibility)
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

    % KKN 2026/07/17 - preStimFix: hold fixation for a bit BEFORE the
    % RF-map distractor starts flashing. Plain waitForMS (not flash-aware)
    % since the dot hasn't been initialized yet - nothing is flashing
    % during this hold.
    if ~waitForMS(e.preStimFix,e.fixX,e.fixY,params.fixWinRad)
        sendCode(codes.BROKE_FIX);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        waitForMS(e.noFixTimeout);
        result = codes.BROKE_FIX;
        return;
    end

    % initial fixation is acquired (and preStimFix has elapsed) - start
    % the RF-map distractor dot cycling now, and keep it running through
    % the catch-hold (it explicitly stops before postTargetBuffer, near
    % the end of the trial)
    dotState = rfDotInit(e,rfObjID);

    [ok,dotState] = waitForMSFlash(e.targetOnsetDelay,e.fixX,e.fixY,params.fixWinRad,dotState);
    if ~ok
        % hold fixation before stimulus comes on
        sendCode(codes.BROKE_FIX);
        dotState = rfDotForceOff(dotState);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        waitForMS(e.noFixTimeout);
        result = codes.BROKE_FIX;
        return;
    end

    % Decision point - is this VisGuided, Delay-VisGuided, or Mem-Guided.
    % Target presentation timing matches ex_SaccadeTaskAndRFmap exactly.
    % The one difference: at the point where the real task would send the
    % go-cue (turn fixation off), this file does NOT - the fixation point
    % stays on and the subject is expected to keep fixating it.
    if (e.targetOnsetDelay == e.fixDuration)
        % Visually Guided Saccade (catch) - in the real task the target
        % onset and the go-cue happen simultaneously; here the target
        % still appears, but fixation is left on.
        sendCode(2001); % send code specific to this stimulus type
        msgAndWait('obj_on 2');
        sendCode(codes.TARG_ON);
    elseif ((e.targetOnsetDelay + e.targetDuration) < e.fixDuration)
        % Memory Guided Saccade (catch)
        sendCode(2002); % send code specific to this stimulus type
        msgAndWait('obj_on 2');
        sendCode(codes.TARG_ON);

        [ok,dotState] = waitForMSFlash(e.targetDuration,e.fixX,e.fixY,params.fixWinRad,dotState);
        if ~ok
            % didn't hold fixation during target display
            sendCode(codes.BROKE_FIX);
            dotState = rfDotForceOff(dotState);
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
            dotState = rfDotForceOff(dotState);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(2500);
            result = codes.BROKE_FIX;
            return;
        end
        % NOTE: catch trial - fixation point stays ON here (no go-cue)
    elseif (((e.targetOnsetDelay + e.targetDuration) > e.fixDuration) && (e.targetOnsetDelay < e.fixDuration))
        % Delayed Visually Guided Saccade (catch)
        sendCode(2003); % send code specific to this stimulus type
        msgAndWait('obj_on 2');
        sendCode(codes.TARG_ON);

        waitRemainder = e.fixDuration - e.targetOnsetDelay;
        [ok,dotState] = waitForMSFlash(waitRemainder,e.fixX,e.fixY,params.fixWinRad,dotState);
        if ~ok
            % didn't hold fixation during target display
            sendCode(codes.BROKE_FIX);
            dotState = rfDotForceOff(dotState);
            msgAndWait('all_off');
            sendCode(codes.TARG_OFF);
            sendCode(codes.FIX_OFF);
            waitForMS(e.noFixTimeout);
            result = codes.BROKE_FIX;
            return;
        end
        % NOTE: catch trial - fixation point stays ON here (no go-cue)
    else
        warning('*** EX_SACCADETASKANDRFMAP_CATCH: Condition not valid');
        return;
    end

    % KKN 2026/07/17 - this is the catch-trial substitute for the
    % go-cue/saccade/target-acquisition sequence in ex_SaccadeTaskAndRFmap.
    % No saccade happens, so there is no target window to search for or
    % acquire - the subject just has to keep fixating the ORIGINAL
    % fixation point through catchLatencyBuffer (standing in for the
    % saccade initiation+execution time a real trial would spend here)
    % plus stayOnTarget (drawn the same as the real task's target-hold
    % requirement). The RF-map distractor keeps flashing throughout.
    [ok,dotState] = waitForMSFlash(e.catchLatencyBuffer,e.fixX,e.fixY,params.fixWinRad,dotState);
    if ~ok
        sendCode(codes.BROKE_FIX);
        dotState = rfDotForceOff(dotState);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        waitForMS(e.noFixTimeout);
        result = codes.BROKE_FIX;
        return;
    end

    [ok,dotState] = waitForMSFlash(e.stayOnTarget,e.fixX,e.fixY,params.fixWinRad,dotState);
    if ~ok
        sendCode(codes.BROKE_FIX);
        dotState = rfDotForceOff(dotState);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        waitForMS(e.noFixTimeout);
        result = codes.BROKE_FIX;
        return;
    end

    % KKN 2026/07/17 - RF-map distractor explicitly stops flashing now
    % (forced off if mid-flash), so the code stream doesn't have a
    % STIM_ON left orphaned without a matching STIM_OFF. The subject then
    % has to continue fixating, flash-free, for postTargetBuffer ms
    % before reward. Uses plain waitForMS (not flash-aware) since the dot
    % is intentionally not restarted here.
    dotState = rfDotForceOff(dotState);

    if ~waitForMS(e.postTargetBuffer,e.fixX,e.fixY,params.fixWinRad)
        sendCode(codes.BROKE_FIX);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        waitForMS(e.noFixTimeout);
        result = codes.BROKE_FIX;
        return;
    end

    sendCode(codes.FIXATE);
    sendCode(codes.CORRECT);
    sendCode(codes.TARG_OFF);
    % KKN 2026/07/17 - unlike the real task (where fixation already went
    % off at the go-cue, long before this point), fixation has been on
    % this WHOLE trial in a catch trial, so it has to be explicitly
    % cleared here before reward.
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    sendCode(codes.REWARD);
    giveJuice();
    result = 1;

    if isfield(e,'InterTrialPause')
        waitForMS(e.InterTrialPause);
    end

end

% ---------------------------------------------------------------------
% RF-map distractor dot helpers
% Identical to ex_SaccadeTaskAndRFmap.m (see that file for full
% explanatory comments on the position-logging/code-collision-safety
% design) - duplicated here rather than shared so this file has no
% dependency on the real task's file.
% ---------------------------------------------------------------------

function dotState = rfDotInit(e,objID)
% builds the shuffled position grid and initial (off) state for the
% RF-map distractor dot. The first call to rfDotService will trigger the
% first flash immediately, regardless of dotISIFrames.

    global params;

    [gx,gy] = ndgrid(e.dotXPositions(:),e.dotYPositions(:));
    dotState.grid = [gx(:) gy(:)];
    dotState.queue = [];
    dotState.lastIdx = [];
    dotState.objID = objID;
    dotState.dotRad = e.dotRad;
    dotState.dotColor = e.dotColor;
    dotState.dotAlpha = e.dotAlpha;
    dotState.dotDur = e.dotDurFrames * params.displayFrameTime * 1000;
    dotState.dotISI = e.dotISIFrames * params.displayFrameTime * 1000;
    dotState.posShiftForCode = e.posShiftForCode;
    dotState.phase = 'off';
    dotState.phaseTic = tic;
    dotState.needsInit = true;
end

function dotState = rfDotService(dotState,remainingMS)
% called once per polling iteration of waitForMSFlash; toggles the
% distractor dot on/off on its own schedule, independent of whatever
% fixation logic is currently running. remainingMS is how much time is
% left in the CURRENT wait call - a new flash is only started if there's
% enough of that time left for it to finish (dotDur), so a flash never
% gets truncated by the trial ending partway through.

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
% exhausted, avoiding an immediate repeat of the last position shown),
% turns the distractor dot on there, and logs its (x,y) through the code
% stream (STIM_ON followed by x+posShiftForCode, y+posShiftForCode - see
% ex_SaccadeTaskAndRFmap.m's rfDotBeginFlash for the full rationale on
% the shift value and the collision-safety assertion below).

    global codes;

    posShiftForCode = dotState.posShiftForCode;
    safeCodeFloor = 15000; % clears 12697 with margin, and is well inside the post-processing filter's >=1000 floor
    safeCodeCeiling = 29000; % clears 31791 with margin, and is well inside the post-processing filter's <=32000 ceiling

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

    pos = round(dotState.grid(idx,:));
    xCode = pos(1) + posShiftForCode;
    yCode = pos(2) + posShiftForCode;
    assert(xCode>safeCodeFloor && xCode<safeCodeCeiling && yCode>safeCodeFloor && yCode<safeCodeCeiling, ...
        'rfDotBeginFlash:codeCollisionRisk', ...
        'dotXPositions/dotYPositions include a position too far from screen center to safely encode as a code (must stay within roughly +/-15000 px) - check the RF-map distractor grid in the xml.');

    msg('set %d oval 0 %i %i %i %i %i %i %.2f', ...
        [dotState.objID pos(1) pos(2) dotState.dotRad dotState.dotColor(1) dotState.dotColor(2) dotState.dotColor(3) dotState.dotAlpha]);
    msg('obj_on %d',dotState.objID);
    sendCode(codes.STIM_ON);
    sendCode(xCode);
    sendCode(yCode);

    dotState.phase = 'on';
    dotState.phaseTic = tic;
end

function dotState = rfDotForceOff(dotState)
% KKN 2026/07/17 - if a distractor flash is currently on, turns it off
% immediately and sends a matching STIM_OFF code. Needed because a trial
% can end - either successfully or via a failure branch - mid-flash, and
% nothing else would ever close that flash out: 'all_off' clears the
% object visually but does NOT send any code, so a STIM_ON with no
% matching STIM_OFF could otherwise be left in the code stream. Call this
% at every trial-ending point, right before 'all_off'.

    global codes;

    if strcmp(dotState.phase,'on')
        msg('obj_off %d',dotState.objID);
        sendCode(codes.STIM_OFF);
        dotState.phase = 'off';
    end
end

% ---------------------------------------------------------------------
% flash-aware wait function (mirrors waitForMS.m, but additionally
% services the RF-map distractor dot on every poll). waitForFixationFlash
% is intentionally not included here - this file never searches for a
% target window, since there is no saccade.
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

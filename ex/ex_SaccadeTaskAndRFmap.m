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
% 3 - helper target (optional; only turns on once the target window has
%     been acquired - see ACQUIRE_TARG below - not during the saccade
%     itself, and used for both normal and antisaccade trials; there is
%     no separate obj 4 fallback anymore, since a single post-acquisition
%     trigger covers both cases)
% 5 - RF-map distractor dot (obj 4 is intentionally unused/skipped, kept
%     free rather than renumbered so this stays a minimal, low-risk diff)
%
% KKN 2026/07/17 - changed the helper target (obj 3) to turn on only
% after the target window is acquired (sendCode(codes.ACQUIRE_TARG)),
% not during the saccade as it originally did in ex_SaccadeTask_varDelays
% and the base version of this file. This change is local to this file
% only - ex_SaccadeTask_varDelays.m and ex_PursuitTaskAndRFmap.m are
% unaffected. Also added helperTargetSize (xml) to control the helper
% target's radius independently of the main saccade target's size.
%
% XML REQUIREMENTS (saccade task, same as ex_SaccadeTask_varDelays)
% angle, distance, size, targetColor, stimType, fixX, fixY, fixRad,
% fixColor, timeToFix, noFixTimeout, targetOnsetDelay, targetDuration,
% delay, stayOnTarget, saccadeInitiate, saccadeTime, targWinRadScale,
% incorrectTimeout. Optional: extraBorder, fixJuice, helperTargetColor,
% helperTargetSize (required if helperTargetColor is present - radius in
% px of the helper target, independent of the main target's size),
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
% dotDurFrames: how many display frames each distractor flash stays on
%   screen (same meaning as the old rfMapping_dots.xml 'frameCount')
% dotISIFrames: gap between distractor flashes, in display frames
% posShiftForCode: the offset added to each flash's x/y before sending it
%   as a code (see IMPORTANT note below). Recommended: 22000 - do NOT set
%   this above ~29000 or below ~15000 (see rfDotBeginFlash for why: it
%   has to both clear every other code in use AND stay inside the
%   [1000,32000] window that downstream post-processing code keeps,
%   values outside that window are silently discarded). This is an xml
%   param rather than a hardcoded value specifically so it gets saved
%   into xmlParams in the trial data - if it's ever changed, the value
%   actually used for a given session stays recoverable.
%
% Note: the distractor grid is defined in absolute screen coordinates
% (like the original RF mapping task), independent of fixX/fixY.
%
% IMPORTANT - decoding which position was flashed when: unlike the
% original rfMapping task, where each flashed position was a
% pre-generated condition (so it's recoverable from the saved trial/
% condition data), the position of each distractor flash here is chosen
% at runtime and is NOT saved anywhere else. STIM_ON alone only gives you
% timing. The position is logged through the code stream itself: every
% STIM_ON code is immediately followed by two more codes - the flash's X
% then Y position, each shifted by +posShiftForCode (from the xml, saved
% to xmlParams) so negative pixel coordinates stay positive, clear of
% every other code used anywhere in this codebase (highest is 31791),
% AND inside the [1000,32000] range downstream post-processing code
% actually keeps.
% Subtract that session's posShiftForCode from each of those two codes to
% recover the actual pixel position - check xmlParams.posShiftForCode for
% that session rather than assuming a fixed value. No hardware/joystick
% dependency - this is only a code-numbering scheme, chosen to match how
% this codebase already encodes a runtime x/y position as two codes
% elsewhere, just with a larger, collision-checked offset (see
% rfDotBeginFlash for why).
%
% Note on frame-based timing: dotDurFrames/dotISIFrames are converted to
% milliseconds inside rfDotInit() using params.displayFrameTime, which
% runex.m measures live off the actual connected monitor at the start of
% each session (its 'framerate' query to the display computer). So the
% same xml produces the same real-world flash duration regardless of
% which rig/monitor refresh rate it's run on, exactly like the old
% frameCount behavior. The reason the on/off timing itself is still
% tracked in milliseconds on the control side (rather than relying on the
% display's own frame-count auto-off, as frameCount originally did) is
% that it needs to be interleaved, every polling iteration, with the
% saccade task's own fixation/saccade checks - a display-side auto-off
% can't be paused or coordinated with a separate, already-running
% control-side timeline the way this needs to be.
%
% Last modified:
% 2026/07/17 by KK Noneman - created by combining ex_activeFixation and
% ex_SaccadeTask_varDelays

    global params codes behav;

    e = e(1); %in case more than one 'trial' is passed at a time...

    objID = 2;
    rfObjID = 5; % KKN 2026/07/17 - object ID for the RF-map distractor dot

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
    % Helper Target - single object; only defined if helperTargetColor is
    % present. KKN 2026/07/17 - now turns on only after the target window
    % is acquired (see below), not during the saccade - so antisaccade no
    % longer needs a second "fallback" helper object (the old obj 4); one
    % object serves both branches. Size is set independently via
    % helperTargetSize, not e.size (the main saccade target's size).
    if isfield(e, 'helperTargetColor')
        if isfield(e, 'antiSaccade') & e.antiSaccade == 1
            msg('set 3 oval 0 %i %i %i %i %i %i',[-newX -newY e.helperTargetSize e.helperTargetColor(1) e.helperTargetColor(2) e.helperTargetColor(3)]);
        else
            msg('set 3 oval 0 %i %i %i %i %i %i',[newX newY e.helperTargetSize e.helperTargetColor(1) e.helperTargetColor(2) e.helperTargetColor(3)]);
        end
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

    % KKN 2026/07/17 - initial fixation is acquired, so start the RF-map
    % distractor dot cycling now, and keep it running for the rest of the
    % trial. From here on, waitForMS/waitForFixation are swapped for the
    % waitForMSFlash/waitForFixationFlash variants defined at the bottom
    % of this file, which also service the distractor dot every polling
    % iteration alongside the normal fixation/saccade checks.
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

        if isfield(e,'helperTargetColor')
            % KKN 2026/07/17 - helper now turns on only once the target
            % window has been acquired (not during the saccade)
            if isfield(e, 'helperTargetRatio')
                if rand < e.helperTargetRatio
                    msg('obj_on 3');
                    sendCode(codes.TARG_ON);
                end
            else
                msg('obj_on 3');
                sendCode(codes.TARG_ON);
            end
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

        if isfield(e,'helperTargetColor')
            % KKN 2026/07/17 - helper now turns on only once the target
            % window has been acquired (not during the saccade)
            if isfield(e, 'helperTargetRatio')
                if rand < e.helperTargetRatio
                    msg('obj_on 3');
                    sendCode(codes.TARG_ON);
                end
            else
                msg('obj_on 3');
                sendCode(codes.TARG_ON);
            end
        end

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
% Added 2026/07/17 by KK Noneman
% ---------------------------------------------------------------------

function dotState = rfDotInit(e,objID)
% builds the shuffled position grid and initial (off) state for the
% RF-map distractor dot. The first call to rfDotService will trigger the
% first flash immediately, regardless of dotISIFrames.
%
% dotDurFrames/dotISIFrames are specified in DISPLAY FRAMES (like the old
% rfMapping_dots.xml 'frameCount' param) and converted here to
% milliseconds using params.displayFrameTime, which is measured live off
% the actual connected monitor at the start of the session (see
% runex.m's 'framerate' query). This keeps the flash duration correct in
% real time regardless of what refresh rate a given rig runs at, while
% the on/off timing itself is still tracked in ms on the control side (as
% opposed to frameCount's own auto-off) so it can be interleaved with the
% saccade task's fixation checks.

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
    dotState.posShiftForCode = e.posShiftForCode; % KKN 2026/07/17 - stored from xml (not hardcoded) so it's saved to xmlParams in the trial data and can be recovered later even if this value gets changed
    dotState.phase = 'off';
    dotState.phaseTic = tic;
    dotState.needsInit = true;
end

function dotState = rfDotService(dotState,remainingMS)
% called once per polling iteration of the flash-aware wait functions;
% toggles the distractor dot on/off on its own schedule, independent of
% whatever fixation/saccade logic is currently running.
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
%
% KKN 2026/07/17 - logs the (x,y) of THIS flash through the code stream,
% since that's the only record of it (unlike the original rfMapping task,
% positions here are picked at runtime, not pre-generated as conditions,
% so nothing about them is saved to the trial data otherwise). Follows
% a code-numbering scheme also used elsewhere in this codebase for
% logging a runtime x/y position (no hardware dependency involved):
% STIM_ON is immediately followed by two more codes containing X and Y,
% each shifted by +posShiftForCode so negative pixel coordinates stay
% within sendCode's required 0-2^16 range. To decode offline: for every
% STIM_ON code, the next two codes in the stream are
% (x + posShiftForCode) and (y + posShiftForCode) for that flash.
%
% posShiftForCode comes from the xml (e.posShiftForCode, stored into
% dotState by rfDotInit), NOT hardcoded here, specifically so its value
% is saved into xmlParams as part of the trial data every session - if
% this ever gets changed (in the xml, or by editing the default below),
% the actual shift used for a given session stays permanently
% recoverable instead of having to be inferred/guessed later.
%
% Default of 22000 was chosen for two reasons that both have to hold at
% once: (1) it has to clear every other code sent anywhere in this
% codebase (2001-2003, 12697, 31791 are the relevant ones in this
% range - not the 10000 used by this codebase's other position-logging
% code, waitForJoystick.m, which is too close to 12697 for a wide dot
% grid), and (2) unlike sendCode's own 0-2^16 hardware limit, downstream
% post-processing code discards any code that isn't <256 or in
% [1000,32000] - so anything shifted above 32000 (e.g. the 50000 this
% was first set to) silently vanishes before it's ever decodable. 22000
% sits in the 12697-31791 gap, comfortably inside [1000,32000], with the
% assertion below (safeCodeFloor/safeCodeCeiling) enforcing both
% constraints so a misconfigured (too-wide) dotXPositions/dotYPositions
% grid, or a posShiftForCode edited to an unsafe value, throws a loud
% error instead of silently losing codes.

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

% ---------------------------------------------------------------------
% flash-aware wait functions (mirror waitForMS.m / waitForFixation.m, but
% additionally service the RF-map distractor dot on every poll)
% Added 2026/07/17 by KK Noneman
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

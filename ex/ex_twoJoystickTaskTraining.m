function result = ex_twoJoystickTaskTraining(e)

targetTask = true;
grabOrHold = false;

% only matters if targetTask is true
includeTarget = true;

global params codes behav;   
global joystickUsedHistory
persistent joystickOverallHistory % NOTE PLEASE REMOVE IN FINAL TASK
% persistent firstTimeInBlock
% if ~isempty(joystickOverallHistory) && e.currentBlock == 1 && firstTimeInBlock
%     joystickOverallHistory = [];
%     firstTimeInBlock = false;
% else
%     firstTimeInBlock = true;
% end
% connect to the joystick
joystickDevInds = connectToJoysticks(e(1).joystickName);
rewardTimeProportion = 1;


% obj 1 is fix spot, obj 2 is stimulus, diode attached to obj 2
objID = 2;
msg(['diode ' num2str(objID)]);

msgAndWait('ack');
leftJoystickRect = 3;
rightJoystickRect = 4;
% leftJoystickOnMsg = sprintf('mset %i rect 0 %i %i %i %i %i %i %i',leftJoystickRect, e(1).leftJoyX, e(1).leftJoyY, e(1).rectHalfWidth, e(1).rectHalfHeight, e(1).rectColorOn(1), e(1).rectColorOn(2), e(1).rectColorOn(3));
% leftJoystickOffMsg = sprintf('mset %i rect 0 %i %i %i %i %i %i %i',leftJoystickRect, e(1).leftJoyX, e(1).leftJoyY, e(1).rectHalfWidth, e(1).rectHalfHeight, e(1).rectColorOff(1), e(1).rectColorOff(2), e(1).rectColorOff(3));
% rightJoystickOnMsg = sprintf('mset %i rect 0 %i %i %i %i %i %i %i',rightJoystickRect, e(1).rightJoyX, e(1).rightJoyY, e(1).rectHalfWidth, e(1).rectHalfHeight, e(1).rectColorOn(1), e(1).rectColorOn(2), e(1).rectColorOn(3));
% rightJoystickOffMsg = sprintf('mset %i rect 0 %i %i %i %i %i %i %i',rightJoystickRect, e(1).rightJoyX, e(1).rightJoyY, e(1).rectHalfWidth, e(1).rectHalfHeight, e(1).rectColorOff(1), e(1).rectColorOff(2), e(1).rectColorOff(3));
% joystickOnMsgs = {leftJoystickOnMsg, rightJoystickOnMsg};
% joystickOffMsgs = {leftJoystickOffMsg, rightJoystickOffMsg};

% Initialize colored bottom squares (these signal whether or not the
% joysticks are held down) to red. 
% msg(leftJoystickOffMsg(2:end))
% msg(rightJoystickOffMsg(2:end))
% msgAndWait('obj_on %i', leftJoystickRect);
% msgAndWait('obj_on %i', rightJoystickRect);

% Check if monkey holds down atari joystick and applies twist to joystick 
joystickXYDown = [-32768 0];
checkAll = true;
result = ones(1,numel(e));
joystickAtariAcqPosArgs = {joystickXYDown(1), joystickXYDown(2), joystickDevInds, checkAll};
joystickHEXYHold = [0 0];
joystickHEAngHoldAtLeast = 8;


distanceTolerance = e(1).fixRad;
angleTolerance = 1; % from checking...
joystickHEAcqPosArgs = {joystickHEXYHold(1), joystickHEXYHold(2), joystickHEAngHoldAtLeast, distanceTolerance, angleTolerance};
disp('**** NEW TRIAL ****')
if targetTask
    rewardTimeProportionBase = 0.5;
    msg('set 1 oval 0 %i %i %i %i %i %i',[e(1).fixX e(1).fixY e(1).cursorRad e(1).fixColor(1) e(1).fixColor(2) e(1).fixColor(3)]);
    msgAndWait('obj_on 1');
    sendCode(codes.FIX_ON);
    [conditional, perFuncConditional] = waitForEvent(e(1).timeToStaticJoystickGrab, {@joystickAtariAcquirePosition, @joystickHallEffectGrabCheck}, {joystickAtariAcqPosArgs, joystickHEAcqPosArgs});
%     [conditional, perFuncConditional] = waitForEvent(e(1).timeToStaticJoystickGrab, {@joystickAtariAcquirePosition, @joystickHallEffectGrabCheck, @joystickAtariAcquirePositionOrHallEffectGrabCheck}, {joystickAtariAcqPosArgs, joystickHEAcqPosArgs, {joystickAtariAcqPosArgs, joystickHEAcqPosArgs}});
%     [conditional, perFuncConditional] = waitForEvent(e(1).timeToStaticJoystickGrab, {@joystickAtariAcquirePositionOrHallEffectGrabCheck}, {{joystickAtariAcqPosArgs, joystickHEAcqPosArgs}});

%     if ~waitForEvent(e(1).timeToStaticJoystickGrab, {@joystickAtariAcquirePosition, @joystickHallEffectGrabCheck}, {joystickAtariAcqPosArgs, joystickHEAcqPosArgs})
%     if ~waitForEvent(e(1).timeToStaticJoystickGrab, {@joystickAtariAcquirePositionOrHallEffectGrabCheck}, {{joystickAtariAcqPosArgs, joystickHEAcqPosArgs}})
    if ~conditional
        % moved cursor too or broke fixation too early
%         if ~perFuncConditional(1)
        fprintf('joystick hold pattern [%s]\n', num2str(perFuncConditional))
            sendCode(codes.IGNORED);
%             pause(max(1, abs(1000-e(1).timeToStaticJoystickGrab)/1000))
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            result = codes.IGNORED;
            joystickUsedHistory = [];
            return
%         end
    end
%     joystickOverallHistory = [joystickOverallHistory; joystickUsedHistory(end, :)];
    disp('joystick click')
%     joystickUsedHistory(end, :)
%     joystickUsedHistory = [];
    joystickOverallHistory = [1, 1];
    
    
    % Monkey must keep holding down atari joystick and twist HE joystick for
    % movementJoyStickHoldMS time.
    joystickAtariHoldArgs =  {joystickXYDown(1), joystickXYDown(2), joystickDevInds};
    joystickAtariHoldMsArgs = {e(1).movementJoystickHold, joystickXYDown(1), joystickXYDown(2), joystickDevInds};
    joystickHEHoldMsArgs = [joystickHEAcqPosArgs,e(1).movementJoystickHold];
    rewardTimeProportionBoth = 1;
    if all(joystickOverallHistory(end, :))
        disp('holding both')
        % Reduce Holding Times (instant feedback) if monkey holds BOTH. 
%         joystickHEHoldMsArgs = [joystickHEAcqPosArgs,e(1).movementJoystickHold/4];
        fprintf('required hold time [%s]\n', num2str(e(1).movementJoystickHold))
        if ~waitForEvent(e(1).movementJoystickHold, {@joystickAtariHold, @joystickHallEffectHoldForMs}, {joystickAtariHoldArgs, joystickHEHoldMsArgs})
            % moved cursor too or broke fixation too early
            sendCode(codes.FALSE_START);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            result = codes.FALSE_START;
            pause(1) % this is a timeout if he fails the holds
            return
        end
    elseif joystickOverallHistory(end,1)
        disp('holding Atari only')
         if ~waitForEvent(e(1).movementJoystickHold, {@joystickAtariHoldForMs}, {joystickAtariHoldMsArgs})
            % moved cursor too or broke fixation too early
            sendCode(codes.IGNORED);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            result = codes.IGNORED;
            %     pause(1)
            return
        end       
    elseif joystickOverallHistory(end,2)
        disp('holding HallEffect only')
         if ~waitForEvent(e(1).movementJoystickHold, {@joystickHallEffectHoldForMs}, {joystickHEHoldMsArgs})
            % moved cursor too or broke fixation too early
            sendCode(codes.IGNORED);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            result = codes.IGNORED;
            %     pause(1)
            return
        end       
    else
        raise('ERROR: Should not have gotten here.')
    end
    disp('Held Correctly')
    
    stochasticRewardThresh = 0.75;
    stochRewardCheck = rand(1);
    if stochRewardCheck > stochasticRewardThresh
        rewardTimeProportionHold = 0.5; % reward for just holding...
        juiceX = 1; % number of rewards
        juiceInterval = 1; % time between rewards (ignored if juiceX = 1)
        juiceTTLDuration = round(rewardTimeProportionHold*params.juiceTTLDuration); % duration of reward
        giveJuice(juiceX,juiceInterval,juiceTTLDuration);
    end

    msgAndWait('obj_off 1');

    cursorColorDisp = e(1).cursorColor;
    startCursX = 0;
    startCursY = 0;
    cursorR = e(1).cursorRad;
    msg('set 3 oval 0 %i %i %i %i %i %i', [startCursX startCursY cursorR cursorColorDisp(1) cursorColorDisp(2) cursorColorDisp(3)]);
    msgAndWait('obj_on 3');
    sendCode(codes.CURSOR_ON)

    
 
    rewardForBothProp = 1;
    if includeTarget
        % choose a target location randomly around a circle
        theta = deg2rad(e(1).targetAngle);
        targetX = round(e(1).targetDistance * cos(theta)) + e(1).fixX;
        targetY = round(e(1).targetDistance * sin(theta)) + e(1).fixY;
        msg('set 4 oval 0 %i %i %i %i %i %i',[targetX targetY e(1).targRad e(1).targColor(1) e(1).targColor(2) e(1).targColor(3)]);
        
        % move the cursor
        msgAndWait('obj_on 4');
        sendCode(codes.TARG_ON);
        movementToTargetJoystickHEArgs = {targetX,targetY, e(1).targRad, cursorR, cursorColorDisp, e(1).targWinCursRad};
        if true %all(joystickOverallHistory(end, :))
            [conditionalOpps, funcSuccesses] = waitForEvent(e(1).movementJoyTime, {@joystickHallEffectCursorReachTarget, @joystickAtariHold}, {movementToTargetJoystickHEArgs, joystickAtariHoldArgs});
            conditional = ~conditionalOpps;
        else
            holdBothForMoreRewardMs = e(1).movementJoyTime; % if he holds the Atari joystick this amount of time while the cursor is red, he gets more reward
            totalCursorMoveTime = e(1).movementJoyTime;
%             joystickAtariHoldMsArgsForBoth = {holdBothForMoreRewardMs, joystickXYDown(1), joystickXYDown(2), joystickDevInds};
            startHoldBoth  = tic;
%             conditionalBothHeldIfFalse = ~waitForEvent(holdBothForMoreRewardMs, {@joystickHallEffectCursorReachTarget, @joystickAtariHoldForMs}, {movementToTargetJoystickHEArgs, joystickAtariHoldMsArgsForBoth});
            [conditionalTrueIfTargetReachWhileHolding, funcSuccesses] = waitForEvent(holdBothForMoreRewardMs, {@joystickHallEffectCursorReachTarget, @joystickAtariHold}, {movementToTargetJoystickHEArgs, joystickAtariHoldArgs});
            toc(startHoldBoth)
            if conditionalTrueIfTargetReachWhileHolding
                disp('held for period and target reached')
                rewardForBothProp = 2;
                conditional = false; % references conditional in else statement
            else
                rewardForBothProp = 1;
                keepCheckingForTargetReach = true;
                if ~any(funcSuccesses>0) % both wasn't held *and* didn't reach target
                    disp('not held for period, didn''t reach targ')
                    totalHeld = toc(startHoldBoth)*1000; % convert from s to ms
                    leftOverTime = totalCursorMoveTime - totalHeld;
                elseif funcSuccesses(1)>0 % wasn't held, but *did* reach target
                    % NOTE: I think this is (close to) impossible to get to
                    disp('not held for period, but reached targ')
                    disp("HOW DID WE GET HERE?")
                    keepCheckingForTargetReach = false;
                    totalHeld = toc(startHoldBoth)*1000; % convert from s to ms
                    leftOverTime = totalCursorMoveTime - totalHeld;
                elseif funcSuccesses(2)>0 % was held, but did *not* reach target
                    disp('held for period, didn''t reached targ')
                    totalHeld = toc(startHoldBoth)*1000; % convert from s to ms % probably equivalent to setting this equal to holdBothFroMoreRewardMs
                    leftOverTime = totalCursorMoveTime - totalHeld;
                    rewardForBothProp = 2;
                else
                    error('Not supposed to be here')
                end
                if keepCheckingForTargetReach && leftOverTime > 0
                    conditional = ~waitForEvent(leftOverTime, {@joystickHallEffectCursorReachTarget}, {movementToTargetJoystickHEArgs});
                elseif leftOverTime < 0
                    conditional = true; % so he *didn't* reach the target, oddly
                else
                    conditional = false; % which confusingly means the target was reached...
                end
            end
        end
    else
        % move the cursor
        movementFromPositionJoystickHEArgs = {joystickHEXYHold, distanceTolerance, cursorR, cursorColorDisp};
%         movementAnywhereJoystickHEArgs = {cursorR, cursorColorDisp, e(1).movementJoyTime};
        if false %all(joystickOverallHistory(end, :))
            conditional = ~waitForEvent(e(1).movementJoyTime, {@joystickHallEffectMoveCursorFromPosition, @joystickAtariHold}, {movementFromPositionJoystickHEArgs, joystickAtariHoldArgs});
%             conditional = ~waitForEvent(e(1).movementJoyTime, {@joystickHallEffectShowCursor, @joystickAtariHold}, {movementAnywhereJoystickHEArgs, joystickAtariHoldArgs});
        else
            conditional = ~waitForEvent(e(1).movementJoyTime, {@joystickHallEffectMoveCursorFromPosition}, {movementFromPositionJoystickHEArgs});
%             conditional = ~waitForEvent(e(1).movementJoyTime, {@joystickHallEffectShowCursor}, {movementAnywhereJoystickHEArgs});
        end
    end
   
%     if ~waitForEvent(e(1).movementJoyTime, {@joystickHallEffectCursorReachTarget, @joystickAtariHold}, {movementToTargetJoystickHEArgs, joystickAtariHoldArgs})
%     if ~waitForEvent(e(1).movementJoyTime, {@joystickHallEffectShowCursor, @joystickAtariHold}, {movementAnywhereJoystickHEArgs, joystickAtariHoldArgs})
    if conditional
        disp('didn''t hit target')
        % moved cursor too or broke fixation too early
        sendCode(codes.WRONG_TARG);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        sendCode(codes.REWARD);
%         rewardTimeProportion = rewardTimeProportionBase * rewardTimeProportionBoth * rewardTimeProportionHold;
%         juiceX = 1; % number of rewardqxs
%         juiceInterval = 1; % time between rewards (ignored if juiceX = 1)
%         juiceTTLDuration = round(rewardTimeProportion * params.juiceTTLDuration); % duration of reward
%         giveJuice(juiceX,juiceInterval,juiceTTLDuration);
        if numel(result)==1
            result = codes.WRONG_TARG;
        else
            result = [result codes.WRONG_TARG];
        end
        if funcSuccesses(2)<0
            disp('failed to hold atari joystick')
            pause(2) % timeout period
        else
            pause(0.5)
        end
        return
    end
    disp('moved cursor to target!')
    rewardTimeTargetConditional = 2; % this is if he either moves the cursor or moves it to the target, depending
    rewardTimeProportion = rewardForBothProp * rewardTimeProportionBase * rewardTimeProportionBoth * rewardTimeTargetConditional;
end

if grabOrHold
    joystickNoInteractX = 0;
    joystickNoInteractY = 0;
    joystickAtariInteractArgs = {joystickNoInteractX, joystickNoInteractY, joystickDevInds, checkAll};
    joystickHEInteractArgs = joystickHEAcqPosArgs;
    joystickHEInteractArgs{end-1} = 50;
%     if ~waitForEvent(e(1).timeToStaticJoystickGrab, {@joystickAtariOrHallEffectInteract}, {{joystickAtariInteractArgs, joystickHEInteractArgs}})
    if ~waitForEvent(e(1).timeToStaticJoystickGrab, {@joystickAtariAcquirePositionOrHallEffectGrabCheck}, {{joystickAtariAcqPosArgs, joystickHEAcqPosArgs}})
        % moved cursor too or broke fixation too early
        sendCode(codes.IGNORED);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        result = codes.IGNORED;
    %     pause(1)
        joystickUsedHistory = [];
        return
    end
    joystickOverallHistory = [joystickOverallHistory; joystickUsedHistory(end, :)];
    joystickUsedHistory = [];

    rewardTimeProportion = .5;
    rewardTimeProportionProp = 2;
    if all(joystickOverallHistory(end, :))
        % this both were clicked
        rewardTimeProportion = rewardTimeProportionProp*1;
    elseif size(joystickOverallHistory, 1)>1 && ~all(joystickOverallHistory(end-1, :)) 
        if ~isequal(joystickOverallHistory(end, :), joystickOverallHistory(end-1, :))
            % current and previous are different
            rewardTimeProportion = rewardTimeProportionProp*.5;
        elseif size(joystickOverallHistory, 1)>2 && ~isequal(joystickOverallHistory(end, :), joystickOverallHistory(end-2, :))
            % current and previous are the same, but current and two ago are
            % different
            rewardTimeProportion = rewardTimeProportionProp*0.25;
        else
            % if current is the same as the last two, always give quarter
            % reward
            rewardTimeProportion = rewardTimeProportionProp*0.125;
            if size(joystickOverallHistory, 1)>5
                if all(joystickOverallHistory(:, 1) == joystickOverallHistory(end, 1)) && all(joystickOverallHistory(:, 2) == joystickOverallHistory(end, 2))
                    rewardTimeProportion = 0;
                end
            end
        end
    else
        % last time both were clicked, but not this time
        rewardTimeProportion = 1;
    end

    if size(joystickOverallHistory, 1) > 10
        joystickOverallHistory(1, :) = [];
    end
end



sendCode(codes.CORRECT);
msgAndWait('all_off'); % added MAS 2016/10/12 to turn off fix spot before reward
sendCode(codes.REWARD);
juiceX = 1; % number of rewards
juiceInterval = 1; % time between rewards (ignored if juiceX = 1)
juiceTTLDuration = round(rewardTimeProportion * params.juiceTTLDuration); % duration of reward
giveJuice(juiceX,juiceInterval,juiceTTLDuration);
% giveJuice();

pause(0.5)
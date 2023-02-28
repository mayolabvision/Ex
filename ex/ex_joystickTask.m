function result = ex_joystickTask(e)
% ex file: ex_activeFixation
%
% Active fixation tasks for any stimuli
%
% XML REQUIREMENTS
% runline: a list of strings which correspond to other parameter names.
%   This list of names is used to construct the custom set command to the
%   display
% NAMES: all the parameters listed in runline
% type: the type of stimulus (e.g. fef_dots,oval,etc)
% timeToFix: the number of ms to wait for initial fixation
% joyTime: maximum time allowed to reach target
% preStimFix: time after fixation pt onset before stim onset
% targetDistance: distance of target from fixation
% noFixTimeout: time after breaking fixation before next trial can begin
% fixX, fixY, fixRad: fixation spot location in X and Y as well as RGB
%   color
% targetAngle: angle of target to fixation, usually set with a random
%


    global params codes behav;   
    
    
    % Here be code to grab the joystick device number, which is needed for
    % querying it with PsychToolbox; do it before anything appears on the
    % screen to make timing better
    joystickName = e(1).joystickName;
    allGamepadLike = Gamepad('GetNumGamepads');
    gamepadNames = Gamepad('GetGamepadNamesFromIndices', 1:allGamepadLike);
    trueJoystickDevInd = find(~cellfun('isempty', strfind(gamepadNames, joystickName)));
    if length(trueJoystickDevInd) > 1
        numAx = [];
        for i = 1:length(trueJoystickDevInd)
            numAx = [numAx Gamepad('GetNumAxes', trueJoystickDevInd(i))];
        end
        trueJoystickDevInd = trueJoystickDevInd(numAx ~= 0);
    end
    
    if isempty(trueJoystickDevInd)
        error(['\n\nNo connected joystick found! Perhaps the name has changed? If you think \n'...
                       'that might be the case, check the names of the available GamePads using \n\n'...
                       '    [ind, name] = GetGamepadIndices \n\n'...
                       'and check the output names against the joystickName value in the XML \n'...
                       'file (currently %s). You might have to see what name disappears after \n'...
                       'unplugging the joystick if you''re not sure which name refers to the \n'...
                       'joystick. \n\n'...
                       '(For the code-hunters among us, realize that the inds found in the \n'...
                       'output variable ind do not actually match the deviceInd expected in other \n'...
                       'GamePad functions, and the way it''s done in the code is the way it has to \n'...
                       'be done. For the not code-hunters, don''t worry about it.) \n\n'], e(1).joystickName)
    end
  
    objID = 2;
    % obj 1 is fix spot, obj 2 is stimulus, diode attached to obj 2
    msg('set 1 oval 0 %i %i %i %i %i %i',[e(1).fixX e(1).fixY e(1).fixRad e(1).fixColor(1) e(1).fixColor(2) e(1).fixColor(3)]);
    msg(['diode ' num2str(objID)]);    
    
    msgAndWait('ack');
    
    if isfield(e(1),'isi'),
        pause(e(1).isi/1000);
    end;
       
    msgAndWait('obj_on 1');
    sendCode(codes.FIX_ON);

    
    if ~waitForFixation(e(1).timeToFix,e(1).fixX,e(1).fixY,params.fixWinRad)
        % failed to achieve fixation
        sendCode(codes.IGNORED);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        result = codes.IGNORED;        
        return;
    end
    
    
    
    sendCode(codes.FIXATE);
    
    start = tic;
    
    if ~waitForMS(e(1).preStimFix,e(1).fixX,e(1).fixY,params.fixWinRad)
        % hold fixation before stimulus comes on
        sendCode(codes.BROKE_FIX);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        waitForMS(e(1).noFixTimeout);
        result = codes.BROKE_FIX;
        return;
    end
    
    
    
    result = ones(1,numel(e));
    %'e' loop starts here:
    for e_indx = 1:numel(e)
        %disp(['Cnd: ',num2str(e(e_indx).currentCnd),' Blk: ',num2str(e(e_indx).currentBlock)]);
        % this automatically generates the stimulus command, as long as there
        % is a runline variable in the e struct.
        runLine = e(e_indx).runline;
        runString = '';
        while ~isempty(runLine)
            [tok runLine] = strtok(runLine);
            while ~isempty(tok)
                [thisTok tok] = strtok(tok,',');

                runString = [runString num2str(eval(['e(e_indx).' thisTok]))];
            end
            
            runString = [runString ' '];
        end
        runString = [e(e_indx).type ' ' runString(1:end-1)];
        msg(['set ' num2str(objID) ' ' runString]);
        
        
        if e_indx>1
            if isfield(e(e_indx),'interStimInterval'), holdTime = e(e_indx).interStimInterval; else, holdTime = e(e_indx).preStimFix; end;
            if ~waitForMS(holdTime,e(e_indx).fixX,e(e_indx).fixY,params.fixWinRad)
                % hold fixation before stimulus comes on
                sendCode(codes.BROKE_FIX);
                msgAndWait('all_off');
                sendCode(codes.FIX_OFF);
                waitForMS(e(e_indx).noFixTimeout);
                result(e_indx:end) = codes.BROKE_FIX;
                return;
            end;
        end;
        

        msgAndWait('obj_on 2');

        if ~waitForDisplay(e(e_indx).fixX,e(e_indx).fixY,params.fixWinRad)
            % failed to keep fixation
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.STIM_OFF);
            sendCode(codes.FIX_OFF);
            waitForMS(e(e_indx).noFixTimeout);
            result(e_indx:end) = codes.BROKE_FIX;
            return;
        end
        
  
        
        if e_indx==numel(e)
            % choose a target location randomly around a circle
            theta = deg2rad(e(e_indx).targetAngle);
            newX = round(e(e_indx).targetDistance * cos(theta)) + e(e_indx).fixX;
            newY = round(e(e_indx).targetDistance * sin(theta)) + e(e_indx).fixY;
            msg('set 4 oval 0 %i %i %i %i %i %i',[newX newY e(1).targRad e(1).targColor(1) e(1).targColor(2) e(1).targColor(3)]);
        end;
        msgAndWait('obj_on 4');
        sendCode(codes.TARG_ON);

        
        % UNCOMMENT for targ off before cursor on
        if e(e_indx).targToCursorDelay > 0
%             pause(e(e_indx).targToCursorDelay/1000)

            cursR = 10;
            if ~waitForMS(e(1).targetDuration,e(e_indx).fixX,e(e_indx).fixY,params.fixWinRad)
%             if ~waitForMSJoystickAndFix(e(1).targetDuration,e(1).fixX,e(1).fixY,params.fixWinRad,e(1).fixX,e(1).fixY,cursR,trueJoystickDevInd,e(1).cursorColor, e(1).cursorRad, e(1).joystickPxPerSec)
                % hold fixation before stimulus comes on
                sendCode(codes.BROKE_FIX);
                msgAndWait('all_off');
                sendCode(codes.FIX_OFF);
                sendCode(codes.STIM_OFF);
                waitForMS(e(1).noFixTimeout);
                result = codes.BROKE_FIX;
                return;
            end
            msgAndWait('obj_off 4');
            sendCode(codes.TARG_OFF);
        end
        % skeleton code for the moment... will be turning on cursor after
        % appropriate pause eventually...
%         msg('set 3 oval 0 %i %i %i %i %i %i', [0 0 e(1).cursorRad e(1).cursorColor(1) e(1).cursorColor(2) e(1).cursorColor(3)]);
%         msgAndWait('obj_on 3');

%         newX = 500;
%         newY = 500;
        
    end;  
    

    % detect saccade here - we're just going to count the time leaving the
    % fixation window as the saccade but it would be better to actually
    % analyze the eye movements.
    %
    % One weird thing here is it doesn't move the target window (on the
    % controls screen) until you leave the fixation window. Doesn't matter
    % to monkey, but a little harder for the human controlling the
    % computer. Maybe we can fix this when we implement a saccade-detection
    % function.
    %
%     if false %(e(1).saccadeInitiate > 0) % in case you don't want to have a saccade
%         if params.recenterFixWin
%             newFixWinmsxRad = params.sacWinRad;
%         else
%             newFixWinRad = params.fixWinRad;
%         end
%         
% %         if waitForMS(e(1).saccadeInitiate,e(1).fixX,e(1).fixY,newFixWinRad,'recenterFlag',params.recenterFixWin)
% %         %if waitForMS(e(1).saccadeInitiate,e(1).fixX,e(1).fixY,params.fixWinRad)
% %             % didn't leave fixation window
% %             sendCode(codes.NO_CHOICE);
% %             msgAndWait('all_off');
% %             sendCode(codes.FIX_OFF);
% %             if numel(result)==1
% %                 result = codes.NO_CHOICE;
% %             else
% %                 result = [result codes.NO_CHOICE];
% %             end;
% %             return;
% %         end
%         
%         sendCode(codes.SACCADE);
%         
%         
% 
%         if ~waitForFixation(e(1).saccadeTime,newX,newY,params.targWinRad)
%             % didn't reach target
%             sendCode(codes.NO_CHOICE);
%             msgAndWait('all_off');
%             sendCode(codes.FIX_OFF);
%             if numel(result)==1
%                 result = codes.NO_CHOICE;
%             else
%                 result = [result codes.NO_CHOICE];
%             end;
%             return;
%         end
%         elapsed = toc(start);
%         
% %         if ~waitForMS(e(1).stayOnTarget,newX,newY,params.targWinRad)
% %             % didn't stay on target long enough
% %             sendCode(codes.BROKE_TARG);
% %             msgAndWait('all_off');
% %             sendCode(codes.FIX_OFF);
% %             if numel(result)==1
% %                 result = codes.BROKE_TARG;
% %             else
% %                 result = [result codes.BROKE_TARG];
% %             end;
% %             return;
% %         end
        
%     if true
%         disp('harhar')
%         newX = 500;
%         newY = 500;

        cursR = 10; % this is super small to prevent any cursor movement
        
%         if ~waitForMSJoystick(e(1).targToCursorDelay,e(1).fixX,e(1).fixY,cursR,trueJoystickDevInd,e(1).cursorColor, e(1).cursorRad, e(1).joystickPxPerSec)
        if ~waitForMSJoystickAndFix(e(1).targToCursorDelay,e(1).fixX,e(1).fixY,params.fixWinRad,e(1).fixX,e(1).fixY,cursR,trueJoystickDevInd,e(1).cursorColor, e(1).cursorRad, e(1).joystickPxPerSec)
            % moved cursor too or broke fixation too early
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            if numel(result)==1
                result = codes.BROKE_FIX;
            else
                result = [result codes.BROKE_FIX];
            end;
            return;
        end
        
%         sendCode(codes.TARG_ON)
%         msgAndWait('obj_on 4');

        cursorColorDisp = e(1).cursorColor;
        cursorPos = [0,0];
        msg('set 3 oval 0 %i %i %i %i %i %i', [cursorPos(1) cursorPos(2) e(1).cursorRad cursorColorDisp(1) cursorColorDisp(2) cursorColorDisp(3)]);
        msgAndWait('obj_on 3');
        sendCode(codes.CURSOR_ON)

        if isfield(e(1), 'joystickInitiate')
            [success, cursorPos] = waitForJoystickMove(e(1).joystickInitiate, e(1).cursorRad, trueJoystickDevInd, e(1).joystickPxPerSec, e(1).cursorColor);
            if ~success
                sendCode(codes.IGNORED);
                msgAndWait('all_off');
                sendCode(codes.CURSOR_OFF);
                sendCode(codes.FIX_OFF);
                if numel(result)==1
                    result = codes.IGNORED;
                else
                    result = [result codes.IGNORED];
                end
                return;
            else
                sendCode(codes.CURSOR_ON)
            end
        end
        
        if e(1).fixateWhileMove
            fixWinRad = params.fixWinRad;
            [trialSuccess, reason, endPos] = waitForJoystickWhileFix(e(1).joyTime,e(1).fixX,e(1).fixY,fixWinRad,newX,newY,e(1).targWinCursRad,trueJoystickDevInd,e(1).cursorColor, e(1).cursorMoveColor, e(1).cursorRad, e(1).joystickPxPerSec, cursorPos);
            msg('obj_off 1');
            sendCode(codes.FIX_OFF)
        else
            % fixation off
            msg('obj_off 1');
            sendCode(codes.FIX_OFF)
            [trialSuccess, reason, endPos] = waitForJoystick(e(1).joyTime,newX,newY,e(1).targRad,e(1).cursorRad,trueJoystickDevInd,e(1).cursorColor, e(1).cursorMoveColor, e(1).targWinCursRad, e(1).joystickPxPerSec);
        end
        if ~trialSuccess
            % didn't reach target
            if strcmp(reason, 'WRONG_TARG') && e(1).allowLateChoice
                if isequal(e(1).cursorMoveColor, e(1).bgColor)
                    joyTime = 1.5*e(1).joyTime;
                else
                    joyTime = e(1).joyTime;
                end                    
                sendCode(codes.(reason));
                msgAndWait('obj_on 4');
                sendCode(codes.TARG1_ON);
                startPos = endPos;
                [trialSuccess, reason] = waitForJoystick(joyTime,newX,newY,e(1).targRad,e(1).cursorRad,trueJoystickDevInd,e(1).cursorColor, e(1).cursorColor, e(1).targWinCursRadLC, e(1).joystickPxPerSec, startPos);
                sendCode(codes.TARG1_OFF);
                if trialSuccess
                    % returning here forces the condition to keep getting
                    % redone until it's right without the help
                    sendCode(codes.LATE_CHOICE);
                    if numel(result)==1
                        result = codes.LATE_CHOICE;
                    else
                        result = [result codes.LATE_CHOICE];
                    end
                    juiceX = 1;
                    juiceInterval = 1;
                    juiceTTLDuration = round(2/3*params.juiceTTLDuration);
%                     juiceTTLDuration = round(1/3*params.juiceTTLDuration);
                    giveJuice(juiceX,juiceInterval,juiceTTLDuration);
                    return
                end
    %                 msgAndWait('obj_off 4');
%                 giveJuice(1,1,50)
            elseif strcmp(reason, 'BROKE_FIX')
                sendCode(codes.(reason));
                % this is icky... I want to separate fixation breaks during
                % movement from those during delay, while also not adding
                % anything to runex >.>... so my result is to still send
                % the 'BROKE_FIX' code, but to in addition send a 'SACCADE'
                % code as the *result* of the trial. This means that the
                % trial doesn't get repeated, but also that we can have an
                % indication that what happened was a fixation break. Not
                % ideal...
                reason = 'SACCADE'; 
            end
            if ~trialSuccess
                sendCode(codes.(reason));
                msgAndWait('all_off');
                if numel(result)==1
                    result = codes.(reason);
                else
                    result = [result codes.(reason)];
                end;
                return
            end
        else
            if e(1).fixateWhileMove && e(1).extraRewForFixateWhileMove
                sendCode(codes.REWARD);
                giveJuice()
            end
        end
        

%     end
    

    sendCode(codes.CORRECT);
    msgAndWait('all_off'); % added MAS 2016/10/12 to turn off fix spot before reward
    sendCode(codes.REWARD);
    giveJuice();

    if isfield(e,'InterTrialPause')
        waitForMS(e.InterTrialPause); 
    end

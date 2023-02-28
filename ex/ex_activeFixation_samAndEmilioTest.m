function result = ex_activeFixation_samAndEmilioTest(e)
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
% 2012/10/22 by Adam Snyder - support multiple stimuli per fixation
% 2016/03/16 by Matt Smith - cleanup of option for no saccade, proper
% sending of results codes, add optional interTrialPause after
%

    global params codes behav;   
  
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
        error(sprintf(['\n\nNo connected joystick found! Perhaps the name has changed? If you think \n'...
                       'that might be the case, check the names of the available GamePads using \n\n'...
                       '    [ind, name] = GetGamepadIndices \n\n'...
                       'and check the output names against the joystickName value in the XML \n'...
                       'file (currently %s). You might have to see what name disappears after \n'...
                       'unplugging the joystick if you''re not sure which name refers to the \n'...
                       'joystick. \n\n'...
                       '(For the code-hunters among us, realize that the inds found in the \n'...
                       'output variable ind do not actually match the deviceInd expected in other \n'...
                       'GamePad functions, and the way it''s done in the code is the way it has to \n'...
                       'be done. For the not code-hunters, don''t worry about it.) \n\n'], e(1).joystickName))
    end
    
    sendCode(codes.FIXATE);
    % Juice to keep on task, now with a parameter - MAS 2013/09/20
    if isfield(e(1),'fixJuice')
        if rand < e(1).fixJuice, giveJuice(1); end;
    end
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
    disp(numel(e))
    for e_indx = 1:numel(e)
        disp('blam')
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
        disp(['set ' num2str(objID) ' ' runString]);
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
        
        disp('blam2')
    

        msgAndWait('obj_on 2');
        sendCode(codes.STIM_ON);
        disp('blam3')

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
        
        % stim is automatically turned off by waitForDisplay. This used to
        % send a msg command to make that happen but it was useless. now we
        % just send this code. This does change the code timing a bit in
        % the files now - MAS 2013/09/20
        sendCode(codes.STIM_OFF); 
        
        if e_indx==numel(e)
            % choose a target location randomly around a circle
            theta = deg2rad(e(e_indx).saccadeDir);
            newX = round(e(e_indx).saccadeLength * cos(theta)) + e(e_indx).fixX;
            newY = round(e(e_indx).saccadeLength * sin(theta)) + e(e_indx).fixY;
            msg('set 4 oval 0 %i %i %i %i %i %i',[newX newY params.targWinRad e(1).fixColor(1) e(1).fixColor(2) e(1).fixColor(3)]);
        end;
        msgAndWait('obj_on 4');
%         newX = 500;
%         newY = 500;
        
        if e_indx==numel(e)
            sendCode(codes.FIX_MOVE);
        end;
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
    if (e(1).saccadeInitiate > 0) % in case you don't want to have a saccade
        if params.recenterFixWin
            newFixWinRad = params.sacWinRad;
        else
            newFixWinRad = params.fixWinRad;
        end
        
        if waitForMS(e(1).saccadeInitiate,e(1).fixX,e(1).fixY,newFixWinRad,'recenterFlag',params.recenterFixWin)
        %if waitForMS(e(1).saccadeInitiate,e(1).fixX,e(1).fixY,params.fixWinRad)
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
        elapsed = toc(start);
        
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
        disp('harhar')
%         newX = 500;
%         newY = 500;
        if ~waitForJoystick(e(1).timeForJoy,newX,newY,params.targWinRad,e(1).cursorRad,trueJoystickDevInd,e(1).cursorColor, params.targWinRad)
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
        
%         if ~waitForMSJoystick(e(1).stayOnTarget,newX,newY,params.targWinRad)
%             % didn't stay on target long enough
%             sendCode(codes.BROKE_TARG);
%             msgAndWait('all_off');
%             sendCode(codes.FIX_OFF);
%             if numel(result)==1
%                 result = codes.BROKE_TARG;
%             else
%                 result = [result codes.BROKE_TARG];
%             end;
%             return;
%         end
    end
    

    sendCode(codes.FIXATE);
    sendCode(codes.CORRECT);
    msgAndWait('all_off'); % added MAS 2016/10/12 to turn off fix spot before reward
    sendCode(codes.FIX_OFF);
    sendCode(codes.REWARD);
    giveJuice();

    if isfield(e,'InterTrialPause')
        waitForMS(e.InterTrialPause); 
    end

function result = ex_hrfStim(e)
% ex file: ex_hrfStim
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
    
    runLine = e(1).runline;
    runString = '';
    while ~isempty(runLine)
        [tok runLine] = strtok(runLine);
        while ~isempty(tok)
            [thisTok tok] = strtok(tok,',');
            
            runString = [runString num2str(eval(['e(1).' thisTok]))];
        end
        
        runString = [runString ' '];
    end
    runString = [e(1).type ' ' runString(1:end-1)];
    %         disp(['set ' num2str(objID) ' ' runString]);
    msg(['set ' num2str(objID) ' ' runString]);

    msgAndWait('ack');
    
    if isfield(e(1),'isi'),
        pause(e(1).isi/1000);
    end;
       
    msgAndWait('obj_on 1');

    unixSendPulse(19,10); % added to send a pulse aligned with fix_on 01/24/22 - DI
    
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
    for I=1:e(1).nFlashes
        %disp(['Cnd: ',num2str(e(1).currentCnd),' Blk: ',num2str(e(1).currentBlock)]);
        % this automatically generates the stimulus command, as long as there
        % is a runline variable in the e struct.

        msgAndWait('obj_on 2');
        sendCode(codes.STIM_ON);

        if isfield(e(1),'ultrasoundStim')
            if e(1).ultrasoundStim==1
                unixSendPulse(20,10); % Ultrasound stim pulse
                sendCode(codes.USTIM_ON);
            end
        end
        
        if ~waitForDisplay(e(1).fixX,e(1).fixY,params.fixWinRad)
            % failed to keep fixation
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.STIM_OFF);
            sendCode(codes.FIX_OFF);
            waitForMS(e(1).noFixTimeout);
            result(1:end) = codes.BROKE_FIX;
            return;
        end
        
        sendCode(codes.STIM_OFF);

           holdTime = e(1).interStimInterval;
            if ~waitForMS(holdTime,e(1).fixX,e(1).fixY,params.fixWinRad)
                % hold fixation before stimulus comes on
                sendCode(codes.BROKE_FIX);
                msgAndWait('all_off');
                sendCode(codes.FIX_OFF);
                waitForMS(e(1).noFixTimeout);
                result(1:end) = codes.BROKE_FIX;
                return;
            end
    end
        
    
    % choose a target location randomly around a circle
    theta = deg2rad(e(1).saccadeDir);
    newX = round(e(1).saccadeLength * cos(theta)) + e(1).fixX;
    newY = round(e(1).saccadeLength * sin(theta)) + e(1).fixY;
    msg('set 1 oval 0 %i %i %i %i %i %i',[newX newY e(1).fixRad e(1).fixColor(1) e(1).fixColor(2) e(1).fixColor(3)]);
    sendCode(codes.FIX_MOVE);
    
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
        if numel(result)==1
            result = codes.CORRECT;
        else
            result = [result codes.CORRECT];
        end;
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

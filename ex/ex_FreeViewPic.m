function result = ex_FreeViewPic(e)
% ex file: ex_FreeViewPic
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
%
%

    global params codes behav;   
  
    e = e(1); %in case more than one 'trial' is passed at a time...
    
    objID = 1;
    
    runLine = e.runline;
    runString = '';
    while ~isempty(runLine)
        [tok runLine] = strtok(runLine);
        
        while ~isempty(tok)
            [thisTok tok] = strtok(tok,',');
            
            runString = [runString num2str(eval(['e.' thisTok]))];
        end
        
        runString = [runString ' '];
    end
    runString = [e.type ' ' runString(1:end-1)];
    msg(['set ' num2str(objID) ' ' runString]);

    % obj 1 is image, diode attached to obj 1
%    msg('set 1 movie 0 %i %i %i %i %i %i',[frameCount dwell startframe Xpos Ypos]);
    %msg('set 1 movie 0 %i %i %i %i %i %i',[e.numframes e.dwell e.startframe e.centerx e.centery]);
    msg(['diode ' num2str(objID)]);    
    
    msgAndWait('ack');
    
    if ~waitForFixation(e.fixWait,e.fixX,e.fixY,[e.fixRadX; e.fixRadY])
        % wait for monkey to look at the screen
        sendCode(codes.IGNORED)
        msgAndWait('all_off');
        sendCode(codes.STIM_OFF);
        result = codes.IGNORED;
        return;
    end
    
    msgAndWait('obj_on 1');
    sendCode(codes.STIM_ON);

    if ~waitForDisplay(e.fixX,e.fixY,[e.fixRadX; e.fixRadY])
        % stay looking at screen during stimulus
        sendCode(codes.BROKE_FIX);
        msgAndWait('all_off');
        sendCode(codes.STIM_OFF);
        waitForMS(e.breakFixTimeout);
        result = codes.BROKE_FIX;
        return;
    end

    result = codes.CORRECT;
    sendCode(codes.CORRECT);
    
    msgAndWait('all_off');
    sendCode(codes.STIM_OFF);

    sendCode(codes.REWARD);
    giveJuice();
%     result = 1;

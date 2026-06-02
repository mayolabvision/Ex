function result = ex_onlyFixationAndLuminance(e)
% ex file: ex_onlyFixationAndLuminance

% This ex function presents a full screen rectangle of varying luminance.

% XML Requirements



% Last modified:
% Initidal script written by SMW 2025/20/10

%% Import Globals 
global params codes behav;

%%  Establish some parameters
% Cleanup of param structure(?)
e = e(1); %in case more than one 'trial' is passed at a time...

% Make rectangle color uniform
recColor = e(1).recColor;

% Set up exponential distribution for preStimFixation
expDist = min(e(1).preStimFixDurationMinimum+exprnd(e(1).preStimFixDurationMean, 10000, 1), e(1).preStimFixDurationMaximum+200);
expDist = expDist(expDist<=e(1).preStimFixDurationMaximum);

e(1).preStimFixationDuration = round(randsample(expDist,1));

% Set up Objects
objID = 2;
% obj 1 is fix spot, diode attached to obj 2
msg('set 1 oval 0 %i %i %i %i %i %i',[e(1).fixX e(1).fixY e(1).fixRad e(1).fixColor(1) e(1).fixColor(2) e(1).fixColor(3)]);
msg('set 2 rect 0 %i %i %i %i %i %i %i',[e(1).fixX+1 e(1).fixY e(1).horzHalf e(1).vertHalf recColor recColor recColor]);
msg('set 3 rect 0 %i %i %i %i %i %i %i',[e(1).fixX e(1).fixY-1 e(1).horzHalf e(1).vertHalf recColor recColor recColor]);
msg(['diode ' num2str(objID)]);

%% Start Trial
msgAndWait('ack');

msgAndWait('obj_on 1');
sendCode(codes.FIX_ON);

if ~waitForFixation(e(1).timeToFix,e(1).fixX,e(1).fixY, params.fixWinRad)
    % failed to achieve fixation
    sendCode(codes.IGNORED);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e(1).noFixTimeout);
    result = codes.IGNORED;
    return;
end

sendCode(codes.FIXATE);

if ~waitForMS(e(1).preStimFixationDuration, e(1).fixX, e(1).fixY, params.fixWinRad)
    % hold fixation before stimulus comes on
    sendCode(codes.BROKE_FIX);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e(1).noFixTimeout);
    result = codes.BROKE_FIX;
    return;
end

msgAndWait('timing_begin');
msgAndWait('diode_timing');
msgAndWait('obj_switch 1 2 3');
sendCode(codes.STIM_ON);

if ~waitForMS(e.recDuration, e.fixX,e.fixY,params.fixWinRad)
    % failed to keep fixation
    sendCode(codes.BROKE_FIX);
    msgAndWait('all_off');
    sendCode(codes.STIM_OFF);
    sendCode(codes.FIX_OFF);
    waitForMS(e(1).noFixTimeout);
    result = codes.BROKE_FIX;
    msg('timing_end');
    return;
end
msgAndWait('obj_switch 1 -2 -3');
sendCode(codes.STIM_OFF);

if ~waitForMS(e(1).postStimFixDuration, e(1).fixX, e(1).fixY, params.fixWinRad)
    % hold fixation before stimulus comes on
    sendCode(codes.BROKE_FIX);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e(1).noFixTimeout);
    result = codes.BROKE_FIX;
    return;
end

sendCode(codes.CORRECT);
result = 1;
msgAndWait('all_off')
sendCode(codes.FIX_OFF);
sendCode(codes.REWARD);
giveJuice();

if isfield(e,'InterTrialPause')
    waitForMS(e.InterTrialPause);
end
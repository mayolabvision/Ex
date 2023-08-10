function result = onlyFixationAndVis(e)
% ex file: ex_onlyFixationAndVis
%
% Fixation with stimulus presentation
%
% XML REQUIREMENTS
% timeToFix: the number of ms to wait for initial fixation
% fixDuration: the number of ms to fixate
% noFixTimeout: time after breaking fixation before next trial can begin
% fixX, fixY, fixRad: fixation spot location in X and Y as well as RGB
%   color
% 
%

% Last modified:
% 2023/06/27 by Shawn Willett - wrote the initial function.

global params codes behav;

e = e(1); %in case more than one 'trial' is passed at a time...

% find visual stimulus target 
theta = deg2rad(e.angle);
newX = e.fixX + round(e.distance*cos(theta));
newY = e.fixY + round(e.distance*sin(theta));

objID = 2;
% obj 1 is fix spot, diode attached to obj 2
msg('set 1 oval 0 %i %i %i %i %i %i',[e(1).fixX e(1).fixY e(1).fixRad e(1).fixColor(1) e(1).fixColor(2) e(1).fixColor(3)]);
msg('set 2 oval 0 %i %i %i %i %i %i',[newX newY e.size e.targetColor(1) e.targetColor(2) e.targetColor(3)]);
msg(['diode ' num2str(objID)]);

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

if ~waitForMS(e(1).fixDuration/2, e(1).fixX, e(1).fixY, params.fixWinRad)
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
msgAndWait('obj_on 2');
sendCode(codes.STIM_ON);

if ~waitForMS(e.targetDuration, e.fixX,e.fixY,params.fixWinRad)
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
msgAndWait('obj_off 2');
sendCode(codes.STIM_OFF);

if ~waitForMS(e(1).fixDuration/2, e(1).fixX, e(1).fixY, params.fixWinRad)
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

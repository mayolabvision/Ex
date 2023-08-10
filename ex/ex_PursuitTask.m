function result = ex_PursuitTask(e)
% ex file: ex_PursuitTask
%
%
% General file for pursuit
%

global params codes behav;

e = e(1); %in case more than one 'trial' is passed at a time...

objID = 2;

result = 0;

%     % take radius and angle and figure out x/y for saccade direction
%     theta = deg2rad(e.angle);
%     newX = round(e.distance*cos(theta));
%     newY = round(e.distance*sin(theta));

% Find endpoint

x_endpoint = round(e.fixX + e.jumpSize*deg2pix(1)*cos(deg2rad(e.angle)) + e.pursuitSpeed*deg2pix(1)*cos(deg2rad(e.angle))*((e.pursuitDuration+100)/1000));
y_endpoint = round(e.fixY + e.jumpSize*deg2pix(1)*sin(deg2rad(e.angle)) + e.pursuitSpeed*deg2pix(1)*sin(deg2rad(e.angle))*((e.pursuitDuration+100)/1000));

% obj 1 is fix pt, obj 2 is target, diode attached to obj 2
msg('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad e.fixColor(1) e.fixColor(2) e.fixColor(3)]);
msg('set 2 movingoval 0 %i %i %i %i %i %i %i %i %i',[e.fixX e.fixY e.size e.pursuitSpeed e.angle e.jumpSize e.targetColor(1) e.targetColor(2) e.targetColor(3)]);
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

if ~waitForMS(e.fixDuration,e.fixX,e.fixY,params.fixWinRad)
    % hold fixation before stimulus comes on
    sendCode(codes.BROKE_FIX);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e.noFixTimeout);
    result = codes.BROKE_FIX;
    return;
end

%msg('timing_on');

% turn fix pt off and target on simultaneously
msgAndWait('obj_switch -1 2');
pursuitStartTime = GetSecs;
sendCode(codes.FIX_OFF);
sendCode(codes.TARG_ON);

if ~waitForPursuit(e.pursuitDuration, pursuitStartTime, e.fixX,e.fixY, e.pursuitRadius, e.pursuitSpeed, e.angle, e.jumpSize)
    % keep eye positionon target
    sendCode(codes.BROKE_TARG);
    msgAndWait('all_off');
    sendCode(codes.TARG_OFF);
    waitForMS(e.noFixTimeout);
    result = codes.BROKE_TARG;
    return;
end

% turn target off and turn on fixation target
msgAndWait('obj_off 2')
sendCode(codes.TARG_OFF);
msgAndWait('obj_on 3')
sendCode(codes.TARG3_ON);

if ~waitForMS(e.stayOnTarget, x_endpoint, y_endpoint, params.fixWinRad)
    % hold fixation before stimulus comes on
    sendCode(codes.BROKE_TARG);
    msgAndWait('all_off');
    sendCode(codes.TARG3_OFF);
    waitForMS(e.noFixTimeout);
    result = codes.BROKE_TARG;
    return;
end



% call a waitForPursuit function to monitor eyes
% if ~waitForPursuitMS(onsettime,durationtime,xstart,xstop,etc)
% sendCode(codes.BROKE_PURSUIT)
% return;
%end

% e.displayFrameTime is a value that is set for you - need to figure
% out position in the waitFor loop based on elapsed time

% global values - screenDistance, pixPerCM, pix2deg deg2pix,
% displayFrameTime

% INSTRUCTIONS FOR SHAWN
% (1) in matlab, outside of Ex writing some code that takes X/Y starts,
% speeds, ends, whatever and determines dot position and eye position
% given a frame argument and/or a time argument
% (2) Get the stim_movingoval function to behave how you want it - use
% the speed parameter to move the dot in the direction you want and
% speed you want. Run the XML showing it handles this and randomizes
% the pursuit directions, etc. sv.ifi is inter-frame interval in stim
% (3) work on waitForPursuitMS function (based on waitForMS) with just
% enough extra parameters in it to update the X/Y position that you're
% checking the eye on at each moment in time.
% add a call at very top of function that grabs the time when that
% function was entered. And then, in the while loop update fixX/Y based
% on how much time has elapsed since that initial call.
% (4) test this out in mouse mode, setting the pursuit speed slow,
% windows bit, timing slow so that you can do it by hand
% (5) Fill out the ex function with some more behavioral stuff. Right
% now it's a skeleton - monitor eyes at end of pursuit, make sure the
% error codes are what we want, etc. (Work with Matt Again)
% (6) Double-checking on timing of everything - does it track pursuit
% onset fast enough, does the checking of eye position align well with
% the actual dot on the screen, etc. Probably requires a subject.


%msg('timing_off');

%     if ~waitForMS(e.stayOnTarget,newX,newY,params.targWinRad)
%         % didn't stay on target long enough
%         sendCode(codes.BROKE_TARG);
%         msgAndWait('all_off');
%         sendCode(codes.FIX_OFF);
%         result = codes.BROKE_TARG;
%         return;
%     end
%
%     sendCode(codes.FIXATE);
%     sendCode(codes.CORRECT);
%     sendCode(codes.TARG_OFF);
%     sendCode(codes.REWARD);
msgAndWait('all_off');
sendCode(codes.TARG3_OFF);
sendCode(codes.CORRECT);
sendCode(codes.REWARD)
giveJuice();

result = 1;

if isfield(e,'InterTrialPause')
    waitForMS(e.InterTrialPause);
end


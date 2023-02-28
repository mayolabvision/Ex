function result = ex_twoJoystickTask(e)

global params codes behav;   

% connect to the joystick
joystickDevInds = connectToJoysticks(e(1).joystickName);


% obj 1 is fix spot, obj 2 is stimulus, diode attached to obj 2
msg('set 1 oval 0 %i %i %i %i %i %i',[e(1).fixX e(1).fixY e(1).fixRad e(1).fixColor(1) e(1).fixColor(2) e(1).fixColor(3)]);
objID = 2;
msg(['diode ' num2str(objID)]);

msgAndWait('ack');

% turn on fixation spot
msgAndWait('obj_on 1');
sendCode(codes.FIX_ON);

result = ones(1,numel(e));

% define how second joystick needs to be held
joystickXYDown = [-32768 0];
staticJoyFunc = @joystickHold;
staticJoyInput =  {joystickXYDown(1), joystickXYDown(2), joystickDevInds(1)};

if ~waitForEvent(e(1).timeToStaticJoystickGrab, @joystickAcquirePosition, {joystickXYDown(1), joystickXYDown(2), joystickDevInds(1)})
    % moved cursor too or broke fixation too early
    sendCode(codes.IGNORED);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    result = codes.IGNORED;
    return
end

% choose a target location randomly around a circle
theta = deg2rad(e(1).targetAngle);
newX = round(e(1).targetDistance * cos(theta)) + e(1).fixX;
newY = round(e(1).targetDistance * sin(theta)) + e(1).fixY;
msg('set 4 oval 0 %i %i %i %i %i %i',[newX newY e(1).targRad e(1).targColor(1) e(1).targColor(2) e(1).targColor(3)]);

msgAndWait('obj_on 4');
sendCode(codes.TARG_ON);

% hold joystick without movement
joystickXYStatic = [0,0];
movementJoyHoldInput = {e(1).targetDuration, joystickXYStatic(1), joystickXYStatic(2), joystickDevInds(2)};
if ~waitForEvent(e(1).targetDuration, {@joystickHoldForMs, staticJoyFunc}, {movementJoyHoldInput, staticJoyInput})
    % moved cursor too or broke fixation too early
    sendCode(codes.BROKE_FIX);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    if numel(result)==1
        result = codes.BROKE_FIX;
    else
        result = [result codes.BROKE_FIX];
    end
    return
end

msgAndWait('obj_off 4')
sendCode(codes.TARG_OFF);

% turn on the cursro
cursorColorDisp = e(1).cursorColor;
startCursX = 0;
startCursY = 0;
cursorR = e(1).cursorRad;
msg('set 3 oval 0 %i %i %i %i %i %i', [startCursX startCursY cursorR cursorColorDisp(1) cursorColorDisp(2) cursorColorDisp(3)]);
msgAndWait('obj_on 3');
sendCode(codes.CURSOR_ON)

% move the cursor
movementJoyTimeInput = {newX,newY, e(1).targRad, startCursX, startCursY, cursorR, joystickDevInds(2), cursorColorDisp, e(1).targWinCursRad, e(1).joystickPxPerSec};
if ~waitForEvent(e(1).movementJoyTime, {@joystickCursorReachTarget, staticJoyFunc}, {movementJoyTimeInput, staticJoyInput})
    % moved cursor too or broke fixation too early
    sendCode(codes.WRONG_TARG);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    if numel(result)==1
        result = codes.WRONG_TARG;
    else
        result = [result codes.WRONG_TARG];
    end
    return
end

sendCode(codes.CORRECT);
msgAndWait('all_off'); % added MAS 2016/10/12 to turn off fix spot before reward
sendCode(codes.REWARD);
giveJuice();
function result = ex_ANIblocked_pursuitsacc(e) 

% ex file: ex_ANIblocked_pursuitsacc
%
%
%
%

    global params codes behav; 

    e = e(1); %in case more than one 'trial' is passed at a time....

    objID = 2;

    result = 0;

    %enter what trial type you start with here??
    if isfield(behav,'thisTrialType') == false
        behav.thisTrialType = e.trialtype;
   
    end

    if isfield(behav, 'trialnum') == false
        behav.trialnum = 0;
    end

    if isfield(behav, 'prevTrial') == false % run on the very first trial
            behav.prevTrial = e.angle;
    else % run on the 2nd trial and every one after
           
    end
    %% SACCADE TASK %%


    if behav.thisTrialType == 0;

        sendCode(1000); % code number picked for saccades

        % Added to allow for onset delays this breaks some of the codes
        %%%%% NEED TO FIX BEFORE REAL DATA COLLECTION %%%%%% SMW 2023/07/04
        % To have targetonsetdelay be a function of fixation duration - allows for variable fixdurations. SM Willett 2023/06/16
        if e.stimType == 2001 % visually-guided saccade
            e.targetOnsetDelay = e.sacc_fixDuration; % This is a very temporary "cheat" to have VGS with variable fixations. KK Noneman 2024/06/03
        elseif e.stimType == 2002 % memory-guided saccade
            e.sacc_fixDuration = e.targetOnsetDelay + (e.targetDuration + e.delay);
            %e.targetOnsetDelay = e.sacc_fixDuration - (e.targetDuration + e.delay);
        else % delayed visually-guided saccade
            e.targetOnsetDelay = e.sacc_fixDuration - e.delay;
        end

        % Back to version before temporary change. KK Noneman 2024/11/09
        %e.targetOnsetDelay = e.sacc_fixDuration - (e.targetDuration + e.delay);

        % take radius and angle and figure out x/y for saccade direction

        thisTrialAngle = wrapTo360(behav.prevTrial + e.nextAngle);
        theta = deg2rad(thisTrialAngle);
        newX = round(e.distance*cos(theta));
        newY = round(e.distance*sin(theta));

        %put send struct here

        if isfield(e,'extraBorder')
            extraborder = e.extraBorder; % use XML file if it's there
        else
            extraborder = 10; % default to 10 pixels
        end

        if (abs(newX) + e.sacc_size > (params.displayWidth/2 - extraborder))
            %disp('X exceeds limit, moving fix pt');
            shiftX = abs(newX) + e.sacc_size - params.displayWidth/2 + extraborder;
            if newX > 0
                e.fixX = e.fixX - shiftX;
                newX = newX - shiftX;
            else
                e.fixX = e.fixX + shiftX;
                newX = newX + shiftX;
            end
        end
        if (abs(newY) + e.sacc_size > (params.displayHeight/2 - extraborder))
            %disp('Y exceeds limit, moving fix pt');
            shiftY = abs(newY) + e.sacc_size - params.displayHeight/2 + extraborder;
            if newY > 0
                e.fixY = e.fixY - shiftY;
                newY = newY - shiftY;
            else
                e.fixY = e.fixY + shiftY;
                newY = newY + shiftY;
            end
        end

        % obj 1 is fix pt, obj 2 is target, diode attached to obj 2
        msg('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad e.fixColor(1) e.fixColor(2) e.fixColor(3)]);
        msg('set 2 oval 0 %i %i %i %i %i %i',[newX newY e.sacc_size e.targetColor(1) e.targetColor(2) e.targetColor(3)]);
        if isfield(e,'helperTargetColor')
            msg('set 3 oval 0 %i %i %i %i %i %i',[newX newY e.sacc_size e.helperTargetColor(1) e.helperTargetColor(2) e.helperTargetColor(3)]);
        end
        msg(['diode ' num2str(objID)]);

        %     msgAndWait('ack'); %commented out 03Apr2013, seemed to be causing problems....

        msgAndWait('obj_on 1');

        unixSendPulse(19,10); % This used to be above the 'ack' two lines up, now I moved it so it aligns well to FIX_ON for alignment between this pulse and the FIX_ON code
        % I moved this on 03/25/2019 - MAS
        sendCode(codes.FIX_ON);

        if ~waitForFixation(e.timeToFix,e.fixX,e.fixY,params.fixWinRad)
            % failed to achieve fixation
            sendCode(codes.IGNORED);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.sacc_noFixTimeout);
            result = codes.IGNORED;
            return;
        end
        sendCode(codes.FIXATE);
        if isfield(e,'fixJuice')
            if rand < e.fixJuice, giveJuice(1); end
        end

        if ~waitForMS(e.targetOnsetDelay,e.fixX,e.fixY,params.fixWinRad)
            % hold fixation before stimulus comes on
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.sacc_noFixTimeout);
            result = codes.BROKE_FIX;
            return;
        end


        % Decision point - is this VisGuided, Delay-VisGuided, or Mem-Guided
        if (e.targetOnsetDelay == e.sacc_fixDuration)
            % Visually Guided Saccade
            sendCode(2001); % send code specific to this stimulus type
            % turn fix pt off and target on simultaneously
            msg('queue_begin');
            msg('obj_on 2');
            msg('obj_off 1');
            msgAndWait('queue_end');
            sendCode(codes.FIX_OFF);
            sendCode(codes.TARG_ON);
        elseif ((e.targetOnsetDelay + e.targetDuration) < e.sacc_fixDuration)
            % Memory Guided Saccade
            sendCode(2002); % send code specific to this stimulus type
            msgAndWait('obj_on 2');
            sendCode(codes.TARG_ON);

            if ~waitForMS(e.targetDuration,e.fixX,e.fixY,params.fixWinRad)
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

            % removed additional waitRemainder calculation here
            if ~waitForMS(e.delay,e.fixX,e.fixY,params.fixWinRad)
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
        elseif (((e.targetOnsetDelay + e.targetDuration) > e.sacc_fixDuration) && (e.targetOnsetDelay < e.sacc_fixDuration))
            % Delayed Visually Guided Saccade
            sendCode(2003); % send code specific to this stimulus type
            msgAndWait('obj_on 2');
            sendCode(codes.TARG_ON);

            waitRemainder = e.sacc_fixDuration - e.targetOnsetDelay;
            if ~waitForMS(waitRemainder,e.fixX,e.fixY,params.fixWinRad)
                % didn't hold fixation during target display
                sendCode(codes.BROKE_FIX);
                msgAndWait('all_off');
                sendCode(codes.TARG_OFF);
                sendCode(codes.FIX_OFF);
                waitForMS(e.sacc_noFixTimeout);
                result = codes.BROKE_FIX;
                return;
            end

            msgAndWait('obj_off 1');
            sendCode(codes.FIX_OFF);
        else
            warning('*** EX_SACCADETASK: Condition not valid');
            %%% should there be some other behavior here?
            return;
        end

        % detect saccade here - we're just going to count the time leaving the
        % fixation window as the saccade but it would be better to actually
        % analyze the eye movements.
        %
        % 2015/08/14 MAS - changed code below to adjust eye window around
        % current eye position to make it easier to detect saccades (especially
        % small ones)
        %
        %    if waitForMS(e.saccadeInitiate,e.fixX,e.fixY,params.fixWinRad)
        if params.recenterFixWin
            newFixWinRad = params.sacWinRad;
        else
            newFixWinRad = params.fixWinRad;
        end

        if waitForMS(e.saccadeInitiate,e.fixX,e.fixY,newFixWinRad,'recenterFlag',params.recenterFixWin)
            % didn't leave fixation window
            sendCode(codes.NO_CHOICE);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.incorrectTimeout) % Added by SM Willett - to timeout incorrect trials. 2023/06/16
            result = codes.NO_CHOICE;
            return;
        end

        sendCode(codes.SACCADE);

        if isfield(e,'helperTargetColor')
            %% turn on a target for guidance if 'helperTargetColor' param is present
            if isfield(e, 'helperTargetRatio')
                % turn on a helper in a defined ration of trials
                if rand < e.helperTargetRatio
                    msg('obj_on 3')
                    sendCode(codes.TARG_ON);
                end
            else
                msg('obj_on 3');
                sendCode(codes.TARG_ON);
            end
        end


        targetWindowRadius = round(e.targWinRadScale*e.distance);

        if ~waitForFixation(e.saccadeTime,newX,newY,targetWindowRadius)
            % didn't reach target
            sendCode(codes.NO_CHOICE);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.incorrectTimeout) % Added by SM Willett - to timeout incorrect trials. 2023/06/16
            result = codes.NO_CHOICE;
            return;
        end

        % MAS 2015/08/14 added this code so we know when he reaches the window
        sendCode(codes.ACQUIRE_TARG);


        if ~waitForMS(e.sacc_stayOnTarget,newX,newY,targetWindowRadius)
            % didn't stay on target long enough
            sendCode(codes.BROKE_TARG);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.incorrectTimeout) % Added by SM Willett - to timeout incorrect trials. 2023/06/16
            result = codes.BROKE_TARG;
            return;
        end

        sendCode(codes.FIXATE);
        sendCode(codes.CORRECT);
        sendCode(codes.TARG_OFF);
        sendCode(codes.REWARD);
        giveJuice();
        result = 1;

        % store the current trial's angle in behav so it's ready for the next trial
        % this only stores this value *if* the monkey gets everything correct
        % is that right? Or do we want to update it on errors?
        behav.prevTrial = thisTrialAngle;


    end
    
    

    %% PURSUIT TASK %%

    if behav.thisTrialType == 1

        sendCode(1001); %code picked for pursuit

        % Find Jumpsize

        disp(behav)

        e.jumpSize = (e.reactionTime/1000)*e.pursuitSpeed*e.jump;

        if isfield(behav, 'prevTrial')== false
            behav.prevTrial = e.angle;
        end

        thisTrialAngle  = wrapTo360(behav.prevTrial + e.nextAngle);
        theta = thisTrialAngle;
        x_endpoint = round(e.fixX + e.jumpSize*deg2pix(1)*cos(deg2rad(theta)) + e.pursuitSpeed*deg2pix(1)*cos(deg2rad(theta))*((e.pursuitDuration+100)/1000));
        y_endpoint = round(e.fixY + e.jumpSize*deg2pix(1)*sin(deg2rad(theta)) + e.pursuitSpeed*deg2pix(1)*sin(deg2rad(theta))*((e.pursuitDuration+100)/1000));

        disp(thisTrialAngle); % the angle from the current trial after using the previous trial to help pick

        % send the new angle into the NEV
        sendStruct(struct('newAngle',thisTrialAngle));

        % obj 1 is fix pt, obj 2 is target, diode attached to obj 2
        msg('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad e.fixColor(1) e.fixColor(2) e.fixColor(3)]);
        msg('set 2 movingoval 0 %i %i %i %i %i %f %i %i %i',[e.fixX e.fixY e.pursuit_size e.pursuitSpeed thisTrialAngle e.jumpSize e.targetColor(1) e.targetColor(2) e.targetColor(3)]);
        msg('set 3 oval 0 %i %i %i %i %i %i',[x_endpoint y_endpoint e.pursuit_size e.targetColor(1) e.targetColor(2) e.targetColor(3)]);
        msg(['diode ' num2str(objID)]);

        msgAndWait('obj_on 1');

        sendCode(codes.FIX_ON);

        if ~waitForFixation(e.timeToFix,e.fixX,e.fixY,params.fixWinRad);
            % failed to achieve fixation
            sendCode(codes.IGNORED);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.pursuit_noFixTimeout);
            result = codes.IGNORED;
            return;
        end

        sendCode(codes.FIXATE);
        if isfield(e,'fixJuice')
            if rand < e.fixJuice, giveJuice(1); end;
        end

        if ~waitForMS(e.pursuit_fixDuration,e.fixX,e.fixY,params.fixWinRad)
            % hold fixation before stimulus comes on
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.pursuit_noFixTimeout);
            result = codes.BROKE_FIX;
            return;
        end

        %msg('timing_on');

        % turn fix pt off and target on simultaneously
        msgAndWait('obj_switch -1 2');
        pursuitStartTime = GetSecs;
        sendCode(codes.FIX_OFF);
        sendCode(codes.TARG_ON);

        if ~waitForPursuit(e.pursuitDuration, pursuitStartTime, e.fixX,e.fixY, e.pursuitRadius, e.pursuitSpeed, thisTrialAngle, e.jumpSize)
            % keep eye positionon target
            sendCode(codes.BROKE_TARG);
            msgAndWait('all_off');
            sendCode(codes.TARG_OFF);
            waitForMS(e.pursuit_noFixTimeout);
            result = codes.BROKE_TARG;
            return;
        end

        % turn target off and turn on fixation target
        msgAndWait('obj_off 2')
        sendCode(codes.TARG_OFF);
        msgAndWait('obj_on 3')
        sendCode(codes.TARG3_ON);

        if ~waitForMS(e.pursuit_stayOnTarget, x_endpoint, y_endpoint, params.fixWinRad*e.endPursuitWinScale)
            % hold fixation before stimulus comes on
            sendCode(codes.BROKE_TARG);
            msgAndWait('all_off');
            sendCode(codes.TARG3_OFF);
            waitForMS(e.pursuit_noFixTimeout);
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

        %     if ~waitForMS(e.pursuit_stayOnTarget,newX,newY,params.targWinRad)
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
    end
    
    %% POST TRIAL STUFF %%

    behav.prevTrial = thisTrialAngle;

    behav.trialnum  = behav.trialnum + 1;

    if behav.trialnum > e.blocksize
        behav.trialnum = 0;
        if behav.thisTrialType == 0
            behav.thisTrialType = 1;
        else
            behav.thisTrialType = 0;
        end
    end
    

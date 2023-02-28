function result = ex_MGSBCIBlock(e)
% ex file: ex_SaccadeTask
%
% Uses codes in the 2000s range to indicate stimulus types
% 2001 - visually guided saccade
% 2002 - memory guided saccade
% 2003 - delayed visually guided saccade
%
% General file for memory and visually guided saccade tasks 
%
% XML REQUIREMENTS
% angle: angle of the target dot from the fixation point 0-360
% distance: the distance of the target in pixels from the fixation point
% size: the size of the target in pixels
% targetColor: a 3 element [R G B] vector for the target color
% timeToFix: time in ms for initial fixation
% noFixTimeout: timeout punishment for aborted trial (ms)
% targetOnsetDelay: time after fixation before target appears
% fixDuration: length of initial fixation required
% targetDuration: duration that target is on screen
% stayOnTarget: length of target fixation required
% saccadeInitiate: maximum time allowed to leave fixation window
% saccadeTime: maximum time allowed to reach target
%
% Modified:
%
% 2012/10/22 by Matt Smith - update to helperTargetColor and to make it
% work when multiple 'trials' are passed in 'e'.
%
% 2012/11/09 by Matt Smith - update to allow "extraBorder" as an optional
% parameter in the XML file
%
% 2014/12/10 by Matt Smith - trying to consolidate some stuff.
% InterTrialPause put in at the end
%
% 2015/08/14 by Matt Smith - added ACQUIRE_TARG code before stayOnTarget
% window
%
% 2015/08/14 by Matt Smith - added recentering when detecting saccade
%



% %I think this should work, -ACS24Apr2012 %added the  cue for this particular trial (cue from xml just sets first miniblock) -ACS07oct2015 -added isCueTrial acs12oct2015



% xml: e.miniblocksize e.nCueTrials
% angle

%% initialize globals
    global params codes behav sockets bciCursorTraj trialData allCodes;
    bciCursorTraj = [];

%% Shake Hands with BCI Computer    
    handshakeflag = 0;
    
    if e.errorBadHandshakeFlag    
        matlabUDP2('send',sockets(2),'handshake');
        starthand = tic;
        while toc(starthand)<1
            if matlabUDP2('check',sockets(2))
                temp = matlabUDP2('receive',sockets(2));
                if str2double(temp)==1
                    handshakeflag = 1;
                    break
                end
            end
        end

        if handshakeflag == 0 
            %error('BCI Computer Not Responding')
            error('exFunction:bci_aborted','BCI computer gave a bad handshake flag');
            % Don't need to send the code here because runex does it
            %sendCode(codes.BCI_ABORT);
        end
    end
    %prestim = tic;
    if isfield(e(1),'newTargWinRad')
        thistargwinrad = e(1).newTargWinRad;
        params.targWinRad = thistargwinrad;
    end
    
%% Initialize behav file    (FIX)
    if ~isfield(behav,'bcicorrect')
        behav.cursorloc = [];
        behav.bcicorrect = -1;
        behav.trialNum = 0;
        behav.cue = e(1).angle(randi(length(e(1).angle),1));
       % behav.superBlockCues = behav.cue;        
        behav.superblockcount = 0;
        behav.angle = [];
        behav.angleleft = e(1).allAngles;
        behav.misscount = 0;
        behav.perturbind = 1;
        behav.blockCueOn = 0;
        behav.randomPerturbFlag = 0;
        behav.targetBrightness = 128;
        newangleflag = 1;
        if e.peripheralTargConditionFlag == 1
            behav.peripheralsLeft = zeros(1,length(e.allAngles));
            behav.peripheralsLeft(randperm(length(e.allAngles),e.numPeripheralConds)) = 1;
            behav.thisPeriphflag = behav.peripheralsLeft(1);
        end
        %behav.flipFlag = 0;
%         if isfield(e(1),'iterativeRecal') && e(1).iterativeRecal==1
%             behav.superblockid = 0;
%             behav.currRecal = 1;
%         else
%             behav.superblockid = 1;
%         end
        if e(1).autocalibflag == 1
            behav.superblockid = 1;
        else
            behav.superblockid = 2;
        end
    else
        behav(end+1).bcicorrect = -1;
        behav(end).trialNum = behav(end-1).trialNum;
        behav(end).superblockid = behav(end-1).superblockid;
        behav(end).superblockcount = behav(end-1).superblockcount;
        behav(end).angle = behav(end-1).angle;
        behav(end).angleleft = behav(end-1).angleleft;
        behav(end).misscount = behav(end-1).misscount;
        behav(end).perturbind = behav(end-1).perturbind;
        behav(end).blockCueOn = behav(end-1).blockCueOn;
        behav(end).randomPerturbFlag = behav(end-1).randomPerturbFlag;
        behav(end).targetBrightness = behav(end-1).targetBrightness;
        if e.peripheralTargConditionFlag == 1
            behav(end).peripheralsLeft = behav(end-1).peripheralsLeft;
            behav(end).thisPeriphflag = behav(end-1).thisPeriphflag;
        end
        newangleflag = 0;
%         if isfield(e,'iterativeRecal') && e.iterativeRecal==1
%             behav(end).currRecal = behav(end-1).currRecal;
%         end
    end

    e = e(1); %in case more than one 'trial' is passed at a time...

%% New MGS BCI block code for iterative calibration 
objID = 2;

% figure out what current block should be. Need to separate from next step
% to avoid boundary cases.

switch behav(end).superblockid
    case 1
        curblocklength =  e.numcalibtrials;
        if behav(end).superblockcount>=e.numcalibtrials
            behav(end).superblockid = 2; % fix this so that transition trial has correct params
            behav(end).superblockcount = 0;
            newangleflag = 1;
        end  
    case 2
        curblocklength =  e.NumBlockCueTrials;
        if e.NumBlockCueTrials ~= 0
            if behav(end).superblockcount >= e.NumBlockCueTrials && e.NumBlockNonCueTrials~=0
                behav(end).superblockid = 3;
                behav(end).superblockcount = 0;
                behav(end).misscount = 0;
            elseif e.NumBlockNonCueTrials==0 && (behav(end).superblockcount >= e.NumBlockCueTrials || behav(end).misscount >= e.maxmissesabort)
                behav(end).superblockcount = 0;
                behav(end).misscount = 0;
                newangleflag = 1;
            elseif behav(end).misscount >= e.maxmissesabortCue
                behav(end).superblockcount = 0;
                behav(end).misscount = 0;
                newangleflag = 1;
            end
        end
    case 3
        curblocklength =  e.NumBlockNonCueTrials;
        if behav(end).superblockcount >= e.NumBlockNonCueTrials || behav(end).misscount >= e.maxmissesabort
            behav(end).superblockid = 2;
            behav(end).superblockcount = 0;
            behav(end).misscount = 0;
            newangleflag = 1;
        end
end

% set parameters for the current block
switch behav(end).superblockid  
    case 1% calibration block   
 
        if behav(end).superblockcount == curblocklength && e.autocalibflag == 1
            recalflag = 1; % set this so that if the trial is correct, then recalibration is done
        else
            recalflag = 0;
        end
        peripheralTargVisibleFlag = 1;
        cursorvisibleflag = e.cursorvisiblecalibflag;
        bcirewardflag = 0;
        annulusvisibleflag = e.annulusvisiblecalibflag;
        e.bciTrial = 0;
        annulusTargVisibleFlag = e.annulusTargVisibleFlag;
        behav(end).angle = e.angle;
    case 2% bciblock
        % variables different in cued vs non-cued trials
        if e.NumBlockCueTrials ~= 0 % do a block task
            if  newangleflag == 1
                behav(end).angle = behav(end).angleleft(randi(length(behav(end).angleleft)));
                behav(end).angleleft = setdiff(behav(end).angleleft,behav(end).angle);
                if e.peripheralTargConditionFlag == 1
                    display(behav(end).peripheralsLeft)
                    display(isempty(behav(end).peripheralsLeft))
                    display(behav(end).peripheralsLeft(1))
                    display(behav(end).thisPeriphflag)
                    behav(end).thisPeriphflag = behav(end).peripheralsLeft(1);
                    if length(behav(end).peripheralsLeft)>1
                        behav(end).peripheralsLeft = behav(end).peripheralsLeft(2:end);
                    end
                end
                if isempty(behav(end).angleleft)
                    behav(end).angleleft = e.allAngles;
                    if e.peripheralTargConditionFlag == 1
                        behav(end).peripheralsLeft = zeros(1,length(e.allAngles));
                        behav(end).peripheralsLeft(randperm(length(e.allAngles),e.numPeripheralConds)) = 1;
                    end
                end
                behav(end).blockCueOn = e.blockCueOn; 
                behav(end).targetBrightness = e.targetBrightness;
                behav(end).randomPerturbFlag = e.randomPerturb;
            end           
        else
            behav(end).angle = e.angle;
        end
        % need this option b/c angle is changed in case 2 not case 3, so must have a case 2 trial at beginning of each block
        if e.peripheralTargConditionFlag == 1
            
            peripheralTargVisibleFlag = behav(end).thisPeriphflag;
        else
            
            if e.NumBlockNonCueTrials==0
                    if behav(end).misscount >= e.maxmissesprompt
                        peripheralTargVisibleFlag = 1;
                    else
                        peripheralTargVisibleFlag = e.peripheralTargVisibleDuringCue;
                    end
            else
                peripheralTargVisibleFlag = e.peripheralTargVisibleDuringCue;
            end
        end
        %peripheralTargVisibleFlag = e.peripheralTargVisibleFlag
        % variables the same in cued vs non-cued trials
        cursorvisibleflag = e.cursorVisible;
        bcirewardflag = e.bciRewardEnable;  
        annulusvisibleflag = e.annulusvisibleflag;
        e.bciTrial = 1;
        recalflag = 0;
        annulusTargVisibleFlag = e.annulusTargVisibleFlag;
        display('this is case 2!')
        % TO DO for block task:
        % flag for doing a block task
        % determine target angle in a blockwise manner
        % alternate between peripherally cued trials and non-cued trials
    case 3 % non cued block, note, behav(end).angle is never changed here from trial to trial
        if behav(end).misscount >= e.maxmissesprompt
            peripheralTargVisibleFlag = 1;
        else
            peripheralTargVisibleFlag = behav(end).blockCueOn;
        end
        display('this is case 3!')
        display(peripheralTargVisibleFlag)
        cursorvisibleflag = e.cursorVisible;
        bcirewardflag = e.bciRewardEnable;  
        annulusvisibleflag = e.annulusvisibleflag;
        e.bciTrial = 1;
        recalflag = 0;
        annulusTargVisibleFlag = e.annulusTargVisibleFlag;
        e.targetColor = behav(end).targetBrightness*[1 1 1]';
end  

if isfield(e,'workspaceMult')
    e.cursorRadOnAnnulus = round(e.workspaceMult*e.cursorRadOnAnnulus);
    e.annulusSize = round(e.workspaceMult*e.annulusSize);
    e.annulusThickness = round(e.workspaceMult*e.annulusThickness);
    e.Cmax = round(e.workspaceMult*e.Cmax);
    e.cursorRad = round(e.workspaceMult*e.cursorRad);
    e.BCIDistanceThresh = round(e.workspaceMult*e.BCIDistanceThresh);
    sendStruct(struct('cursorRadOnAnnulus',e.cursorRadOnAnnulus,'annulusSize',e.annulusSize,'annulusThickness',e.annulusThickness,'Cmax',e.Cmax,'cursorRad',e.cursorRad,'BCIDistanceThresh',e.BCIDistanceThresh));
end
sendStruct(struct('angle',behav(end).angle,'bciTrial',e.bciTrial,'superblockcount',behav(end).superblockcount,'superblockID',behav(end).superblockid ,'cursorVisible',cursorvisibleflag,'peripheralTargVisibleDuringCue',peripheralTargVisibleFlag,'targetColor',e.targetColor));

    
%% Check other task input flags    
    result = 0;
    if e.showDelayTargetFlag == 1
        targetColorOther = e.targetColorOther;
    else
        targetColorOther = e.bgColor;
    end
  
%% define bci function  (TO DO: Define function
    if isfield(e,'distfunflag')&&e.distfunflag == 1
        bcifun = @(x,y)(x<=y);
    else
        bcifun = @(x,y)(find(x==max(x))==y);
    end
   



%% set up for perturbation
    if isfield(e,'perturbStartTrialNum') && isfield(e,'perturbEndTrialNum')&&e.perturbStartTrialNum>=0 && behav(end).trialNum >= e.perturbStartTrialNum && behav(end).trialNum <e.perturbEndTrialNum      
        if length(e.perturbAngle)>1
            e.perturbAngle = e.perturbAngle(behav(end).perturbind);
        else
            e.perturbAngle = e.perturbAngle;
        end
    else
        if length(e.perturbAngle)>1
            if behav(end).trialNum>e.washoutEndTrialNum && behav(end).perturbind < length(e.perturbAngle)
                behav(end).trialNum = e.perturbStartTrialNum;
                behav(end).perturbind = behav(end).perturbind + 1;
                e.perturbAngle = e.perturbAngle(behav(end).perturbind);
            else
                e.perturbAngle = 0;
            end
        else
            e.perturbAngle = 0;
        end    
    end
    sendStruct(struct('perturbAngle',e.perturbAngle));
%% set up for peripheral perturbation
    if behav(end).randomPerturbFlag ==0
        if isfield(e,'perturbStartTrialNum') && isfield(e,'perturbEndTrialNum')&&e.perturbStartTrialNum>=0 && behav(end).trialNum >= e.perturbStartTrialNum && behav(end).trialNum <e.perturbEndTrialNum      
            if length(e.peripheralPerturbAngle)>1
                e.peripheralPerturbAngle = e.peripheralPerturbAngle(behav(end).perturbind);
            else
                e.peripheralPerturbAngle = e.peripheralPerturbAngle;
            end
        else
            if length(e.peripheralPerturbAngle)>1
                if behav(end).trialNum>e.washoutEndTrialNum && behav(end).perturbind < length(e.peripheralPerturbAngle)
                    behav(end).trialNum = e.perturbStartTrialNum;
                    behav(end).perturbind = behav(end).perturbind + 1;
                    e.peripheralPerturbAngle = e.peripheralPerturbAngle(behav(end).perturbind);
                else
                    e.peripheralPerturbAngle = 0;
                end
            else
                e.peripheralPerturbAngle = 0;
            end    
        end    
    else
        e.peripheralPerturbAngle = e.randomPerturbAmount;
    end
    sendStruct(struct('peripherPerturbAngle',e.peripheralPerturbAngle));
    
%% define saccade target in cartesian coordinates
    % take radius and angle and figure out x/y for saccade direction
    
    theta = deg2rad(behav(end).angle + e.peripheralPerturbAngle);
    newX = round(e.distance*cos(theta));
    newY = round(e.distance*sin(theta));
%% define annulus target in cartesian coordinates (pixels)
    theta = deg2rad(behav(end).angle);
    newXOnAnnulus = round(e.annulusSize*cos(theta));
    newYOnAnnulus = round(e.annulusSize*sin(theta));
    
%% some relic features of dirmem. Keep this code so that can do dirmem like task
    % now figure out if you need to shift the fixation point around so the
    % saccade will fit on the screen (e.g., for an 'amp' series). The
    % "extraborder" keeps the dot from ever getting within that many pixels
    % of the edge of the screen
    if isfield(e,'extraBorder') 
        extraborder = e.extraBorder; % use XML file if it's there
    else
        extraborder = 10; % default to 10 pixels
    end
    
    if (abs(newX) + e.size > (params.displayWidth/2 - extraborder))
        %disp('X exceeds limit, moving fix pt');
        shiftX = abs(newX) + e.size - params.displayWidth/2 + extraborder;
        if newX > 0
            e.fixX = e.fixX - shiftX;
            newX = newX - shiftX;
        else
            e.fixX = e.fixX + shiftX;
            newX = newX + shiftX;
        end
    end
    if (abs(newY) + e.size > (params.displayHeight/2 - extraborder))
        %disp('Y exceeds limit, moving fix pt');
        shiftY = abs(newY) + e.size - params.displayHeight/2 + extraborder;
        if newY > 0
            e.fixY = e.fixY - shiftY;
            newY = newY - shiftY;
        else
            e.fixY = e.fixY + shiftY;
            newY = newY + shiftY;
        end
    end
    
    % non targets positions. To do: add shift if exceed limits
    nonTargs = setdiff(e.allAngles,behav(end).angle);
    nonTargX = zeros(length(nonTargs),1);
    nonTargY = zeros(length(nonTargs),1);
    for n = 1:length(nonTargs)
        localtheta = deg2rad(nonTargs(n));
        nonTargX(n) = round(e.distance*cos(localtheta));
        nonTargY(n) = round(e.distance*sin(localtheta));
    end
    
    % obj 1 is fix pt, obj 2 is target, diode attached to obj 2
    
    


%% set up the stimuli for dirmem base
    msg('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad e.fixColor(1) e.fixColor(2) e.fixColor(3)]);
    msg('set 2 oval 0 %i %i %i %i %i %i',[newX newY e.size e.targetColor(1) e.targetColor(2) e.targetColor(3)]);  
    if isfield(e,'helperTargetColor')
        if  isfield(e,'helperTargetColorAllOn')
            msg('set 3 oval 0 %i %i %i %i %i %i',[newX newY e.size e.helperTargetColorAllOn(1) e.helperTargetColorAllOn(2) e.helperTargetColorAllOn(3)]);
        else
            msg('set 3 oval 0 %i %i %i %i %i %i',[newX newY e.size e.helperTargetColor(1) e.helperTargetColor(2) e.helperTargetColor(3)]);
        end
    end
%% block out the fixation window so cursor does not enter it

%% set up feedback stim (annulus)   
    bcitest= e.bciTrial;
    anninnerind = 7;
    annouterind = 8;
    if  annulusvisibleflag == 1 % set up the annulus
        msg('set %i oval 0 %i %i %i %i %i %i',[anninnerind e.fixX e.fixY (e.annulusSize-e.annulusThickness) e.bgColor(1) e.bgColor(2) e.bgColor(3)]);
        msg('set %i oval 0 %i %i %i %i %i %i',[annouterind e.fixX e.fixY (e.annulusSize) e.annulusColor(1) e.annulusColor(2) e.annulusColor(3)]);
    else
        msg('set %i oval 0 %i %i %i %i %i %i',[anninnerind e.fixX e.fixY (e.annulusSize-e.annulusThickness) e.bgColor(1) e.bgColor(2) e.bgColor(3)]);
        msg('set %i oval 0 %i %i %i %i %i %i',[annouterind e.fixX e.fixY (e.annulusSize) e.bgColor(1) e.bgColor(2) e.bgColor(3)]);   
    end
    
    if e.blankCursorInFixWinFlag == 1
        blankind = 4;
        cursorind = 5;
        e.cursorind = cursorind; % this is used by msgAndWaitMatlabUDP_MGSBCI
        msg('set %i oval 0 %i %i %i %i %i %i',[blankind e.fixX e.fixY e.blankRad e.bgColor(1) e.bgColor(2) e.bgColor(3)]);
        if  cursorvisibleflag==1 % set up the cursor
            msg('set %i oval 0 %i %i %i %i %i %i',[cursorind e.fixX e.fixY e.cursorRad e.cursorColor(1) e.cursorColor(2) e.cursorColor(3)]);
        else
            msg('set %i oval 0 %i %i %i %i %i %i',[cursorind e.fixX e.fixY e.cursorRad e.bgColor(1) e.bgColor(2) e.bgColor(3)]);
        end
    else
        blankind = 5;
        cursorind = 4;
        e.cursorind = cursorind;
        msg('set %i oval 0 %i %i %i %i %i %i',[blankind e.fixX e.fixY e.blankRad e.bgColor(1) e.bgColor(2) e.bgColor(3)]);
        if  cursorvisibleflag==1 % set up the cursor
            msg('set %i oval 0 %i %i %i %i %i %i',[cursorind e.fixX e.fixY e.cursorRad e.cursorColor(1) e.cursorColor(2) e.cursorColor(3)]);
        else
            msg('set %i oval 0 %i %i %i %i %i %i',[cursorind e.fixX e.fixY e.cursorRad e.bgColor(1) e.bgColor(2) e.bgColor(3)]);
        end
        
    end

    
%% set up target on annulus  
    anntargind = 6;
    if annulusTargVisibleFlag == 1 % set up the cursor       
        msg('set %i oval 0 %i %i %i %i %i %i',[anntargind newXOnAnnulus newYOnAnnulus e.cursorRadOnAnnulus e.annulusTargColor(1) e.annulusTargColor(2) e.annulusTargColor(3)]);
    else
        msg('set %i oval 0 %i %i %i %i %i %i',[anntargind newXOnAnnulus newYOnAnnulus e.cursorRadOnAnnulus e.bgColor(1) e.bgColor(2) e.bgColor(3)]);
    end
    
%% Set up stimuli to show all possible targets
    minnewobj = 9;
    if isfield(e,'delayAngle') && ~isempty(e.delayAngle) && e.delayAngle ~= -1
        delaypositions = zeros(length(e.delayAngle),2);
        for stimind = 1:length(e.delayAngle)
                localtheta = deg2rad(e.delayAngle(stimind));
                localnewX = round(e.distance*cos(localtheta));
                delaypositions(stimind,1) = localnewX;
                localnewY = round(e.distance*sin(localtheta));
                delaypositions(stimind,2) = localnewY;
                msg(['set ',num2str(stimind+minnewobj),' oval 0 %i %i %i %i %i %i'],[localnewX localnewY e.sizeOther targetColorOther(1) targetColorOther(2) targetColorOther(3)]);               
        end
    end
    bciTargRad = [params.targWinRad];
    msg(['diode ' num2str(objID)]);    
    
%% start the task
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
    if ~waitForMS(e.targetOnsetDelay,e.fixX,e.fixY,params.fixWinRad)
        % hold fixation before stimulus comes on
        sendCode(codes.BROKE_FIX);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        waitForMS(e.noFixTimeout);
        result = codes.BROKE_FIX;
        return;
    end
    if isfield(e,'delayAngle') && ~isempty(e.delayAngle)&& e.delayAngle ~= -1
        %fprintf(['obj_switch ',num2str((1:length(e.delayAngle))+minnewobj),' 4 5 6\n'])
        %msgAndWait(['obj_switch ',num2str((1:length(e.delayAngle))+minnewobj),' 4 5 6'])
        %        fprintf('did obj switch\n')
        fprintf('NEED TO FIX DELAY ANGLE IMPLEMENATION')
    else
        if cursorvisibleflag==1
            msgAndWait(['obj_switch ', num2str(cursorind),' ',num2str(blankind), ' ',num2str(anninnerind),' ',num2str(annouterind)])
        else
            msgAndWait(['obj_switch ',num2str(anninnerind),' ',num2str(annouterind)])
        end
    end
    % Decision point - is this VisGuided, Delay-VisGuided, or Mem-Guided
    if (e.targetOnsetDelay == e.fixDuration)
        % Visually Guided Saccade
        sendCode(2001); % send code specific to this stimulus type
        % turn fix pt off and target on simultaneously
        msgAndWait('obj_switch 2 -1');
        sendCode(codes.FIX_OFF);
        sendCode(codes.TARG_ON);
    elseif ((e.targetOnsetDelay + e.targetDuration) < e.fixDuration) 
        % Memory Guided Saccade
        sendCode(2002); % send code specific to this stimulus type
        if peripheralTargVisibleFlag == 1 && annulusTargVisibleFlag == 1
            msgAndWait(['obj_switch 2 ',num2str(anntargind)]);
        elseif annulusTargVisibleFlag == 1
            msgAndWait(['obj_on ',num2str(anntargind)])
        elseif peripheralTargVisibleFlag == 1
             msgAndWait('obj_on 2');
        end
        sendCode(codes.TARG_ON);
        if e.errorBadHandshakeFlag;matlabUDP2('send',sockets(2),'pretrialstart');end % send this so bci code can start preparation
        if ~waitForMS(e.targetDuration,e.fixX,e.fixY,params.fixWinRad)
            % didn't hold fixation during target display
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.TARG_OFF);
            sendCode(codes.FIX_OFF);
            waitForMS(e.noFixTimeout);
            result = codes.BROKE_FIX;
            return;
        end     

        % Pre-BCI delay: this delay gives the neural activity time to settle after the target
        msgAndWait('obj_off 2');
        sendCode(codes.TARG_OFF);
        prewait = tic;
        msgAndWait(['diode ',num2str(cursorind)]);
        if ~waitForMS(e.preBCIDelay-toc(prewait)*1000,e.fixX,e.fixY,params.fixWinRad) 
            % didn't hold fixation during prebci delay
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.noFixTimeout);
            result = codes.BROKE_FIX;
            return;
        end    
        
        sendCode(codes.ALIGN);
        if e.errorBadHandshakeFlag;matlabUDP2('send',sockets(2),['trialstart', num2str(numel(allCodes))]);end % send this to start the bci
        
        % Post BCI Delay: this gives the BCI smoothing time to settle
        % before displaying feedback
        if ~waitForMS(e.postBCIDelay,e.fixX,e.fixY,params.fixWinRad)
            % didn't hold fixation during postbcidelay
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.noFixTimeout);
            result = codes.BROKE_FIX;
            return;
        end    
        waitRemainder = e.fixDuration - (e.targetOnsetDelay + e.targetDuration+e.postBCIDelay + e.preBCIDelay);
        if params.recenterFixWin
            if e.replaceSaccWinRadWithAnnulusFlag == 1
                newFixWinRad = round(e.annulusSize+e.cursorRadOnAnnulus/2);
            else
                newFixWinRad = params.sacWinRad;
            end
        else
            if e.replaceFixWinRadWithAnnulusFlag == 1
                newFixWinRad = round(e.annulusSize+e.cursorRadOnAnnulus/2);
            else
                newFixWinRad = params.fixWinRad;
            end
        end
        [fixsuccess, bcisuccess, behav(end).cursorloc,timevec] = waitForMSmatlabUDP_MGSBCI(waitRemainder,e.fixX,e.fixY,newFixWinRad,newXOnAnnulus,newYOnAnnulus,bciTargRad,...
                                                                        e.updatesOnTarget,cursorvisibleflag,bcirewardflag,e,'recenterFlag',params.recenterFixWin);
%         if recalflag == 1
%             if isfield(e,'recalMissReward') && e.recalMissReward == 1 && fixsuccess==1
%                 bciSuccess = 1;
%             end
%         end
        
        if fixsuccess ~= 1
            % didn't hold fixation during bci period
            if e.errorBadHandshakeFlag; matlabUDP2('send',sockets(2),'trialend0'); end % If bci has been started, need to tell it trial ended
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.noFixTimeoutBCI);
            result = codes.BROKE_FIX;            
            return;
        elseif bcisuccess==1

            if e.bciTrial == 1
                if bcirewardflag == 1
                    if e.errorBadHandshakeFlag; matlabUDP2('send',sockets(2),'trialend2'); end % If bci has been started, need to tell it trial ended
                    sendCode(codes.BCI_CORRECT);
                    result = codes.BCI_CORRECT;

%                     if isfield(e,'delayAngle') && ~isempty(e.delayAngle)
%                         msgAndWait(['obj_switch ',num2str(-1*((1:length(e.delayAngle))+minnewobj)), ' -4 -5'])
%                     end
                    sendCode(codes.REWARD);
                    giveJuice(e.bciJuice);
                    waitForMS(e.BCIRewardPause)
                    msgAndWait('all_off');
                    sendCode(codes.FIX_OFF);
                    behav(end).bcicorrect = 1;
                    behav(end).trialNum = behav(end).trialNum + 1;
                    behav(end).superblockcount = behav(end).superblockcount + 1;
                    if e.resetMissOnCorrect == 1
                        behav(end).misscount = 0;
                    end
                    % the following code can be used (needs to be updated) if you want to recalibrati
%                     if recalflag == 1 
%                         totalbcitrials = sum([behav.bcicorrect]==1) + sum([behav.bcicorrect]==0);
%                         if (totalbcitrials==e.recalTrial(behav(end).currRecal))
%                             if e.errorBadHandshakeFlag; matlabUDP2('send',sockets(2),'recalibrate'); end
%                             waitForMS(e.calibrationpause);
%                         end
%                     end
                    waitForMS(e.BCIPause);
                    return
                else
                    sendCode(codes.BCI_CORRECT);
                    behav(end).bcicorrect =  1;                
                end
            else
                    if e.errorBadHandshakeFlag; matlabUDP2('send',sockets(2),'trialend0');end
                behav(end).bcicorrect = -1;
            end

        elseif bcisuccess == 0
            if e.bciTrial == 1
                if e.errorBadHandshakeFlag;matlabUDP2('send',sockets(2),'trialend1');end
                sendCode(codes.BCI_MISSED);
                result = codes.BCI_MISSED;
                behav(end).bcicorrect = 0;
                if e.countMisses ==1 
                    behav(end).superblockcount = behav(end).superblockcount + 1;
                    behav(end).trialNum = behav(end).trialNum + 1;
                end
                behav(end).misscount = behav(end).misscount + 1;
            else
               
                    if e.errorBadHandshakeFlag;matlabUDP2('send',sockets(2),'trialend0');end
                behav(end).bcicorrect = -1;
            end
        end
        msgAndWait(['obj_off 1 ', num2str(cursorind),' ',num2str(blankind), ' ',num2str(anninnerind),' ',num2str(annouterind),' ',num2str(anntargind)])
        sendCode(codes.FIX_OFF);
        minrxn = tic;       
    else
        warning('*** EX_SACCADETASK: Condition not valid');
        %%% should there be some other behavior here?
        return;
    end
    
    
    if e.detectSaccadeFlag
        if params.recenterFixWin
            newFixWinRad = params.sacWinRad;
        else
            newFixWinRad = params.fixWinRad;
        end
        if waitForMS(e.saccadeInitiate,e.fixX,e.fixY,newFixWinRad,[0 255 0],'recenterFlag',params.recenterFixWin)
            % didn't leave fixation window
            sendCode(codes.NO_CHOICE);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            result = codes.NO_CHOICE;
            %if e.errorBadHandshakeFlag; matlabUDP2('send',sockets(2),'trialend');end
            return;
        end
        sendCode(codes.SACCADE);
        if toc(minrxn) < e.minRxn     
            sendCode(codes.FALSEALARM);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            result = codes.FALSEALARM;
            %if e.errorBadHandshakeFlag; matlabUDP2('send',sockets(2),'trialend');end
            return;
        end
        if isfield(e,'helperTargetColor')||isfield(e,'helperTargetColorAllOn')
            %% turn on a target for guidance if 'helperTargetColor' param is present
            msg('obj_on 3');
            sendCode(codes.TARG_ON);
        end
        
        choiceWin = waitForFixation(e.saccadeTime,[nonTargX' newX],[nonTargY' newY],params.targWinRad*ones(1,length(nonTargX)+1),[repmat([255 0 0],length(nonTargX),1); [255 255 0]]);
        if ~choiceWin
            % didn't reach target
            sendCode(codes.NO_CHOICE);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            result = codes.NO_CHOICE;
            %if e.errorBadHandshakeFlag; matlabUDP2('send',sockets(2),'trialend'); end
            return;
        end
        
        sendCode(codes.ACQUIRE_TARG);
       
        if ~waitForMS(e.stayOnTarget,newX,newY,params.targWinRad)
            % didn't stay on target long enough
            sendCode(codes.BROKE_TARG);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            result = codes.BROKE_TARG;
            %if e.errorBadHandshakeFlag; matlabUDP2('send',sockets(2),'trialend'); end
            return;
        end
        sendCode(codes.FIXATE);
    end    
    
    msgAndWait('all_off');
    sendCode(codes.TARG_OFF);
    sendCode(codes.REWARD);
    if e.bciTrial == 0 || e.bciRewardEnable==0 || e.allowSaccadeRewardFlag ==1
        result = codes.CORRECT;
        sendCode(codes.CORRECT);
        if isfield(e,'BCISaccadeReward')
            
            giveJuice(params.juiceX,params.juiceInterval,e.BCISaccadeReward)
        else
            giveJuice();
        end
        if e.bciTrial == 1 && e.countMisses==0 && e.countSaccades==1
            behav(end).superblockcount = behav(end).superblockcount + 1;
        end
    end
    if recalflag == 1
        % the below commented code might be useful if multiple
        % recalibration steps are needed
%         totalbcitrials = sum([behav.bcicorrect]==1) + sum([behav.bcicorrect]==0);
%         if (totalbcitrials==e.recalTrial(behav(end).currRecal))
%             if e.errorBadHandshakeFlag; matlabUDP2('send',sockets(2),'recalibrate');end
%             waitForMS(e.calibrationpause);
%         end
        if e.errorBadHandshakeFlag; matlabUDP2('send',sockets(2),'recalibrate');end
        waitForMS(e.calibrationpause);
    end

    if isfield(e,'InterTrialPause')
        waitForMS(e.InterTrialPause); %this was for Wile E to lengthen time between trials SBK
    end
    


function result = ex_changeDetect_dotsTrain(e)
% ex file:
%
% Development notes: KA June-August 2018

% --> this is an orientation change detection task, 2 alternative forced choice
% --> choice of whether there was a change is indicated by the subject making a saccade to
% a green or red dot AFTER the change occurred
% --> training version of ex_changeDetect_dots

% 8/3/2018 KA: added the option of showing a red or green dot on the second
% grating depending on whether it's a "catch" or "change" trial. this is
% for helping learn the association between green and change. set
% e.showHole = 1. in xml file, can control the color and size of these helper
% holes.

global params codes behav allCodes;

e = e(1); %in case more than one 'trial' is passed at a time...
%printDebugMessages = false;


%initialize behavior-related stuff like trial count;
if ~isfield(behav,'trialNum'),
    behav.trialNum = 0;
    behav.flipFlag = 0; %will flip every time when block of trials finishes
    behav.cue = e.rewardCueSide; %which side to start the extra reward on. 
    %{cue =1 indicates left and cue=2 indicates right}  
    
    %behav.cueType = e.cueType; %if later want to add another way of cueing
    
end;

% if printDebugMessages,
%     display(behav);
%     fprintf('trial  ', behav.trialNum(end)); %which trial number, for debugging
% end;

switch mod(behav.trialNum(end),e.blockSize),
    case 0, %indicates start of new miniblock
        if behav.trialNum(end)>0&&~behav.flipFlag, %don't flip before the first block
            behav.cue = 3-behav.cue; %set the current cue to the "other" one 
            behav.flipFlag = 1; %mark that flip has been done (in case the subject breaks fixation, etc. and we have to try the first trial again)
        end;
    case 1, %first trial in new block after flip
        behav.flipFlag = 0; %signal that flip will be needed next miniblock
end;

e.cue = behav.cue; %pull the "real" cue for this trial from the behav structure
winColors = [0,255,0;255,0,0];
frameMsec = params.displayFrameTime*1000; %this number is <~10ms> bc each frame is 10 ms long, so 50frames is 500ms
stimulusDuration = e.stimulusDuration; %grating duration in # of frames
choicePeriod = e.choicePeriod; %how long subject has to make a choice, in ms
isCatch = e.isCatch; %is this a catch trial (randoms)
frontdoor = (0).*frameMsec; %made the choice too fast .. 20ms = 0.020 sec (set to 2)
%set to 0 for the control experiment where choice dots appear before fix
%off go cue 

orientations = [e.orientation1,e.orientation2];
%orientations = orientations([e.oriPick 3-e.oriPick]); % KA June2019 : commented out to
%always have the same orientation for the sample first flash

%randomize targ amp change selection here
e.oriTargAmp = sort(e.oriTargAmp,'ascend'); %ensure sorted
targAmpPick = randi(numel(e.oriTargAmp));
targAmp = e.oriTargAmp(targAmpPick);

sendStruct(struct('targAmp',targAmp,'thisTrialCue',e.cue));


%DETERMINE GRATING AND CHOICE DOT POSITION FOR EACH TRIAL
%posPick will also help determine whether to give extra reward 
posPick = e.posPick;
% if printDebugMessages, fprintf('Position pick: %d\n',e.posPick); end;

%NOTE: set e.onex and e.oney for the left grating 
if posPick<0, %indicates that ori change should be in position 1,for ex. on the left (posPick=-1)
    targX = e.onex;
    targY = e.oney;
    tside = 1;
else %posPick = 1, ori change is in position 2 (ex.on the right)
    targX = e.twox;
    targY = e.twoy;
    tside = 2;
end;

%if posPick<0, then distractor should be in position 2 (for ex, on the right) (posPick=-1)
if posPick<0,
    distX = e.twox; %distractor is in position two
    distY = e.twoy;
else %posPick = 1
    distX = e.onex; %distractor is in position one (for ex., on the left)
    distY = e.oney;
end;

%use the position picked for the choice dots (choiceDotPos) to randomize
%choice dot locations (same idea as above)
choiceDotPos = e.choiceDotPos;
if choiceDotPos<0, %(choiceDotPos=-1) green dot is on position 1f side
    greenX = e.fDotx;
    greenY = e.fDoty;
    gd = 1;
else %choiceDotPos = 1; green dot is on position 2s side (for ex., on the right)
    greenX = e.sDotx;
    greenY = e.sDoty;
    gd = 2;
end;

%if choiceDotPos<0, then red dot should in position 2 - for ex. on the right (choiceDotPos=-1)
if choiceDotPos<0,
    redX = e.sDotx; %red dot in position 2s
    redY = e.sDoty;
else
    redX = e.fDotx; %red dot in position 1f
    redY = e.fDoty;
end;


%fixation
msgAndWait('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad 0 0 255]); %constant central fixation (yellow)

%choice dot green:
msgAndWait('set 11 oval 0 %i %i %i %i %i %i %i',...
    [ greenX greenY e.choiceDotRadius 0 255 0]);

%choice dot red:
msgAndWait('set 12 oval 0 %i %i %i %i %i %i %i',...
    [ redX redY e.choiceDotRadius 255 0 0]);

%set up target when target grating will appear (second "flash")

isChange = [zeros(1,1)  ones(1,1)];

msgAndWait('ack'); %to sync to vid refresh
msgAndWait('obj_on 1'); %turn on fixation
unixSendPulse(19,10); % This used to be above the 'ack' two lines up, now I moved it so it aligns well to FIX_ON for alignment between this pulse and the FIX_ON code
                      % I moved this on 03/25/2019 - MAS
sendCode(codes.FIX_ON);

if ~waitForFixation(e.timeToFix,e.fixX,e.fixY,params.fixWinRad)
    % failed to achieve fixation
    sendCode(codes.IGNORED);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e.noFixTimeout);
    result = codes.IGNORED;
    return;
end
%otherwise, fixation achieved
sendCode(codes.FIXATE);

if rand<e.fixJuice,  %fixJuice
    giveJuice(1);
end;
%monkey has to wait and fix a time between 400-600 ms before objects start coming

if ~waitForMS(e.preStimFix,e.fixX,e.fixY,params.fixWinRad)
    % hold fixation before stimulus comes on
    sendCode(codes.BROKE_FIX);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e.noFixTimeout);
    result = codes.BROKE_FIX;
    return;
    
end

%objects 5 & 10 are at the target location, object 6 is the foil on first
%flash of gratings
%objects 11 and 12 are the choice dots

for sx = 1:numel(isChange),
  
    
    %before the gratings come on: variable time
    thisInterval = randi(numel(e.interStimulusInterval));
    if thisInterval>0,
        if ~waitForMS(e.interStimulusInterval(thisInterval),e.fixX,e.fixY,params.fixWinRad)
            % failed to keep fixation during ISI
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.noFixTimeout);
            result = codes.BROKE_FIX;
            return;
        end;
    end;
    
    %SET UP ALL NECESSARY OBJECTS EARLY
    
    %obj 13 for catch trials, 2nd flash
    %obj 5 only for sample flash 1 at left position
    %obj 6 for sample flash 1 at right position
    
    %catch trial, flash 2 : obj 6 & 13
    %change trial, flash 2: obj 6 & 10
    
       
        %grating on left, 1st flash
        msgAndWait('set 5 gabor %i %f %f %f %f %i %i %i %f %f',...
        [stimulusDuration  orientations(1) e.phase e.spatial e.temporal  e.onex e.oney e.radius e.contrast e.radius/4]);
        % KA June 2019: set first flash to always be
        % the same orientation by having orientations(1) appear at left
        % grating position (e.onex, e.oney)
        
        %grating on right, 1st flash
        msgAndWait('set 6 gabor %i %f %f %f %f %i %i %i %f %f',...
        [stimulusDuration  orientations(2) e.phase e.spatial e.temporal e.twox e.twoy e.radius e.contrast e.radius/4]);
        % KA June 2019: set first flash to always be
        % the same orientation by having orientations(2) appear at right
        % grating position (e.twox, e.twoy)
        
        %the changed grating on 2nd flash on randomly picked left or right
        %side
        if posPick < 0 %target on left, where sample flash ori was ori1 
            if ~isCatch
                msgAndWait('set 10 gabor %i %f %f %f %f %i %i %i %f %f',...
                [stimulusDuration  orientations(1)+targAmp e.phase e.spatial e.temporal targX targY e.radius e.contrast e.radius/4]);
            
            %obj 13 appears at 'targ' location if it's a catch trial and there
            %is no ori change
            elseif isCatch
                msgAndWait('set 13 gabor %i %f %f %f %f %i %i %i %f %f',...
                [stimulusDuration  orientations(1) e.phase e.spatial e.temporal targX targY e.radius e.contrast e.radius/4]);
            end 
        elseif posPick > 0 %target on right, where sample flash ori was ori2 
            if ~isCatch
                msgAndWait('set 10 gabor %i %f %f %f %f %i %i %i %f %f',...
                [stimulusDuration  orientations(2)+targAmp e.phase e.spatial e.temporal targX targY e.radius e.contrast e.radius/4]);
             
            elseif isCatch
                msgAndWait('set 13 gabor %i %f %f %f %f %i %i %i %f %f',...
                [stimulusDuration  orientations(2) e.phase e.spatial e.temporal targX targY e.radius e.contrast e.radius/4]);
            end 
            
        
        end
        
       
        %show green or red HELPER dot on second grating
        if e.showHole %8/3/2018 KC
            
            msgAndWait('set 3 oval %i %i %i %i %i %i %i',[stimulusDuration targX targY e.holeRad [0 255 0]]); %green for change
            msgAndWait('set 4 oval %i %i %i %i %i %i %i',[stimulusDuration targX targY e.holeRad [255 0 0]]); %red for no change
        end;
        
        %show HELPER dot on correct choice dot
        %added 07/01/19 RJ
        
        if e.showHoleChoice
            msgAndWait('set 8 oval %i %i %i %i %i %i %i',[choicePeriod  greenX greenY e.choiceHoleRad [0 255 150]]); %red for no change
            msgAndWait('set 9 oval %i %i %i %i %i %i %i',[choicePeriod  redX redY e.choiceHoleRad [255 0 150]]); %red for no change
        end
                

    
    
    
    if ~isChange(sx), %1st flash
        
       %gratings on
       %change - added param e.oneSideOnly... if e.oneSideOnly set to 1
       %then on 1st flash only grating on right will appear... this is
       %mostly for DOT training. KA 10/08/2019
       if ~e.oneSideOnly 
            msg('obj_on 5 6 ');
       elseif e.oneSideOnly && e.whichSide < 0 % do left side
            msg('obj_on 5 ');
       elseif e.oneSideOnly && e.whichSide>0 % do right side
           msg('obj_on 6 ');
       end 
        
        
        sendCode(codes.STIM1_ON);
        
        if ~waitForMS(stimulusDuration.*frameMsec,e.fixX,e.fixY,params.fixWinRad)      % failed to keep fixation
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.noFixTimeout);
            result = codes.BROKE_FIX;
            return;
            
%             sendCode(codes.SACCADE); %when false start or broke fix saccade initiated
%             choiceWin = waitForFixation(10.*frameMsec,[e.onex e.twox],[e.oney e.twoy],e.radius*[1 1]); 
%             %e.radius = radius of grating 
%             switch choiceWin   %did subject saccade to one of the gratings?
%                 case 1
%                     
%                     result = codes.FALSE_START;
%                     choicePos=1; %this means to the left
%                     
%                 case 2
%                     
%                     result = codes.FALSE_START;
%                     choicePos = 2;
%                     %to the right grating
%                     
%                 otherwise
%                     choicePos = 0;
%                     result = codes.BROKE_FIX;
%             end;
%             
%             sendCode(result);
%             sendCode(codes.(sprintf('CHOICE%d',choicePos)));
%             msgAndWait('all_off');
%             sendCode(codes.STIM_OFF);
%             sendCode(codes.FIX_OFF);
%             if result == codes.FALSE_START;
%                             
%                 waitForMS(e.falseStartTimeout);
%             end       
%             return;        
        end;
    end; 
        
           
   %otherwise correct withhold during first flash
    sendCode(codes.WITHHOLD);
    sendCode(codes.STIM_OFF);
    result = codes.WITHHOLD; 
    %don't increment behav trial counter for withholds within the sequence
      
    %CATCH TRIALS : NO GRATING CHANGE ON SECOND FLASH
    
    if isCatch &&  sx==2 ;
           
        msg('obj_on 13 ');
        
        %showHole in the center of the grating
        if e.showHole  %8/3/2018 KC
            msg('obj_on 4 '); %red for correct reject
        end

        sendCode(codes.STIM2_ON);
        if ~waitForMS(stimulusDuration.*frameMsec,e.fixX,e.fixY,params.fixWinRad)   % failed to keep fixation during catch trial
            %treat all cases as break fix, easier this way
            % failed to keep fixation at this point
                sendCode(codes.BROKE_FIX);
                msgAndWait('all_off');
                sendCode(codes.FIX_OFF);
                waitForMS(e.noFixTimeout);
                result = codes.BROKE_FIX;
                return;           
        end;  
            
%             sendCode(codes.SACCADE);
%             
%             choiceWin = waitForFixation(10.*frameMsec,[targX distX],[targY distY],e.radius*[1 1]); %note that target window is always '1' %Not sure about this magic number '8'
%             switch choiceWin
%                 case 1
%                     
%                     result = codes.FALSE_START; %saccade to grating without waiting for choice period
%                     choicePos=1; %this means wherever grating was on this trial.
%                     
%                     
%                 case 2
%                     result = codes.FALSE_START; %is this a correct labeling of the outcome?
%                     choicePos = 2;
%                     %wherever blank distractor was on this trial , saccade to
%                     %that blank area
%                     
%                 otherwise
%                     choicePos = 0;
%                     result = codes.BROKE_FIX; %don't increment trial counter for broken fixation
                %end; 
            
%             sendCode(result);
%             sendCode(codes.(sprintf('CHOICE%d',choicePos)));
%             msgAndWait('all_off');
%             sendCode(codes.STIM_OFF);
%             sendCode(codes.FIX_OFF);
%             if result == codes.FALSE_START;
%                             
%                 waitForMS(e.falseStartTimeout);
%             end   
            
            
            %return;
        
        
        % if no broke fix, or false start happened on the second grating, then go on
        
        sendCode(codes.WITHHOLD);
        sendCode(codes.STIM_OFF);
        result = codes.WITHHOLD; %don't increment trial counter for withholds within the sequence
        
       %just CHOICE DOTS ON NEXT --> AFTER a random ISI
        %needs to choose red for a correct outcome here 
        %the following can be uncommented to return to fix point
        %disappearing and choice dots appearing simultaneously after a ISI
        
        thisInterval = randi(numel(e.interStimulusInterval));
        if thisInterval>0,
            if ~waitForMS(e.interStimulusInterval(thisInterval),e.fixX,e.fixY, params.fixWinRad) 
                % failed to keep fixation at this point
                sendCode(codes.BROKE_FIX);
                msgAndWait('all_off');
                sendCode(codes.FIX_OFF);
                waitForMS(e.noFixTimeout);
                result = codes.BROKE_FIX;
                return;
            end;
        end;
        
        msgAndWait('obj_on 11 12'); 
        sendCode(codes.(sprintf('TARG%d_ON',gd))); %to indicate that the choice dots came on
        
        %1/9/2022 : added a separation interval between target dots coming on and
        %fixation point disappearing ... can set e.beforeGoCueInterval to 0
        %to have fix point go off at same time as choice dots appearing 
        thisInterval = randi(numel(e.beforeGoCueInterval));
        if thisInterval>0,
            if ~waitForMS(e.beforeGoCueInterval(thisInterval),e.fixX,e.fixY, params.fixWinRad) 
                % failed to keep fixation at this point
                sendCode(codes.BROKE_FIX);
                msgAndWait('all_off');
                sendCode(codes.FIX_OFF);
                waitForMS(e.noGoCueTimeout);
                result = codes.BROKE_FIX;
                return;
            end;
        end;
        
        msg('obj_off 1'); % fix off, make a choice
        sendCode(codes.FIX_OFF);
        
        targOnTime = tic; %time to make a choice starts when fix goes off
        
        % added 07/01/19 RJ
        if e.showHoleChoice
            msg('obj_on 9');
        end
          
        
        
       choiceWin = waitForFixation(choicePeriod.*frameMsec,[redX greenX],[redY greenY],params.targWinRad*[1 1],winColors(1:2,:)); %note that target window is always '1'
       sacTime = toc(targOnTime); %how long was target on before subject fixated somewhere
       %is this peroid too long? e.choicePeriod param should be in *frames*        
       % if e.choicePeriod = 100, then wait for 1000ms or 1 sec for subject to make choice/saccade  
                
        switch choiceWin
            case 0 %never makes a choice in either window - whether breaks fix or stays fixating
                sendCode(codes.NO_CHOICE);
                result = codes.NO_CHOICE;
                msgAndWait('all_off');
                waitForMS(e.noFixTimeout);
                
                return;
            case 1 %the red rejection dot window CORRECT attempt
                
                sendCode(codes.SACCADE); %mark the time before the 'stayOnTarget' period
               
                if ~waitForMS(e.stayOnTarget,redX,redY,params.targWinRad) %require to stay on for a while, in case the eye 'accidentally' travels through target window
                    % failed to keep fixation
                    sendCode(codes.BROKE_TARG);
                    msgAndWait('all_off');
                    sendCode(codes.TARG_OFF);
                    waitForMS(e.noFixTimeout);
                    result = codes.BROKE_TARG;
                    return;
                end;
                %frontdoor is *hardcoded* in seconds at beginning
              
                
                if (sacTime >= (frontdoor/1000)) && (sacTime < (choicePeriod.*frameMsec)/1000);  %less than choice duration window but longer than frontdoor
                    sendCode(codes.CORRECT_REJECT); %NOTE so that we can easily tell which trials were no change, should be correct-rejection
                    result = codes.CORRECT_REJECT;
                    behav.trialNum = behav.trialNum+1; 
                    %increment trial counter for CR, FA, MISS or HIT
                elseif sacTime <= frontdoor/1000; %TOO FAST
                    sendCode(codes.FALSE_START);
                                      
                    result = codes.FALSE_START;
                elseif (sacTime > (choicePeriod.*frameMsec)/1000) %not sure if this is necessary
                    sendCode(codes.LATE_CHOICE); 
                    result = codes.LATE_CHOICE;
                end 
                            
               
                
                
            otherwise 
                sendCode(codes.SACCADE);
                % incorrect choice -for example chose green, when there
                % was no  change... this is a False Alarm
                % immediately score it, so that the subject
                % can't then switch to the other stimulus.
                if (sacTime < (choicePeriod.*frameMsec)/1000) %if sacTime is less than the choice period
                
                    sendCode(codes.FALSEALARM);
                    result = codes.FALSEALARM;
                   % behav.trialNum = behav.trialNum+1; 
                    %increment trial counter for CR, FA, MISS or HIT
                else
                    sendCode(codes.LATE_CHOICE); 
                    result = codes.LATE_CHOICE;   
                    
                    
                end;
                %turn stuff off before false Alarm timeout - there will be
                %no reward 
                msgAndWait('all_off');
                sendCode(codes.TARG_OFF);
                
                if result == codes.FALSEALARM   
                    waitForMS(e.falseAlarmTimeout);
                  
                end
                return; %end of trial after timeout 
                          
                
               
        end;
        
        
        
         
           
    elseif ~isCatch && sx == 2; %elseif after "if isCatch && sx==2" 
 
        
        msg('obj_on 10 ');
        
        if e.showHole  %8/3/2018 KC
            msg('obj_on 3 ');
        end
        sendCode(codes.STIM2_ON); %STIM2_ON
      
        
        if ~waitForMS(stimulusDuration.*frameMsec,e.fixX,e.fixY,params.fixWinRad)   % failed to keep fixation
            %treat as break fix , all cases 
            % failed to keep fixation at this point
                sendCode(codes.BROKE_FIX);
                msgAndWait('all_off');
                sendCode(codes.FIX_OFF);
                waitForMS(e.noFixTimeout);
                result = codes.BROKE_FIX;
                return;
        end;
            
            
            %sendCode(codes.SACCADE);
%             choiceWin = waitForFixation(10.*frameMsec,[targX distX],[targY distY],e.radius*[1 1]); %note that target window is always '1' %Not sure about this magic number '8'  here -ACS
%             switch choiceWin
%                 case 1
%                     
%                     result = codes.FALSE_START; %saccade to changed target without waiting for choice period
%                     choicePos=1; %this means target -wherever target was on this trial.
%                     
%                     
%                 case 2
%                     
%                     result = codes.FALSE_START; %saccade to changed target without waiting for choice period
%                     choicePos = 2;
%                     %wherever distractor was on this trial , saccade to
%                     %that blank area
%                     
%                 otherwise
%                     choicePos = 0;
%                     result = codes.BROKE_FIX; %don't increment trial counter for broken fixation
%             end;
            
%             if result == codes.FALSE_START     %integrate new trial outcome into Runex - KC June 27
%                 waitForMS(e.falseStartTimeout);
%             end
            
        
        
        % if no broke fix, or early choice happened, then go on
        
        sendCode(codes.WITHHOLD);
        sendCode(codes.STIM_OFF);
        result = codes.WITHHOLD; %don't increment trial counter for withholds within the sequence
         
        
        thisInterval = randi(numel(e.interStimulusInterval));
        if thisInterval>0,
            if ~waitForMS(e.interStimulusInterval(thisInterval),e.fixX,e.fixY,params.fixWinRad)
                % failed to keep fixation at this point
                sendCode(codes.BROKE_FIX);
                msgAndWait('all_off');
                sendCode(codes.FIX_OFF);
                waitForMS(e.noFixTimeout);
                result = codes.BROKE_FIX;
                return;
            end;
        end;
        
        msgAndWait('obj_on 11 12'); %choice dots before the ISI 
        sendCode(codes.(sprintf('TARG%d_ON',gd))); %to indicate that the choice dots came on, also where the gd is 
        
        %1/9/2022 : added a separation interval between target dots coming on and
        %fixation point disappearing ... can set e.beforeGoCueInterval to 0
        %to have fix point go off at same time as choice dots appearing 
        thisInterval = randi(numel(e.beforeGoCueInterval));
        if thisInterval>0,
            if ~waitForMS(e.beforeGoCueInterval(thisInterval),e.fixX,e.fixY, params.fixWinRad) 
                % failed to keep fixation at this point
                sendCode(codes.BROKE_FIX);
                msgAndWait('all_off');
                sendCode(codes.FIX_OFF);
                waitForMS(e.noGoCueTimeout);
                result = codes.BROKE_FIX;
                return;
            end;
        end;
        
        msg('obj_off 1'); % fix off, make a choice
        sendCode(codes.FIX_OFF); 
        targOnTime = tic;        
     

       % added 07/01/19 RJ
        if e.showHoleChoice
        msg('obj_on 8');
        end
        
        
        choiceWin = waitForFixation(choicePeriod.*frameMsec,[greenX redX],[greenY redY],params.targWinRad*[1 1],winColors(1:2,:)); %note that target window is always '1'
        sacTime = toc(targOnTime); %how long has the target been on when fix achieved)
        
        switch choiceWin
            case 0 %never makes a choice/fixates somewhere other than the dots
                
                sendCode(codes.NO_CHOICE); %is this the corect outcome?
                result = codes.NO_CHOICE;
                msgAndWait('all_off');              
                %there should be a time out punishment for not making a choice
                waitForMS(e.noFixTimeout);
                return; 
              
            case 1 %the green dot window
                sendCode(codes.SACCADE); %mark the time before the 'stayOnTarget' period
                
                if ~waitForMS(e.stayOnTarget,greenX,greenY,params.targWinRad) %require to stay on for a while, in case the eye 'accidentally' travels through target window
                    % failed to keep fixation
                    sendCode(codes.BROKE_TARG);
                    msgAndWait('all_off');
                    sendCode(codes.FIX_OFF);
                    
                    waitForMS(e.noFixTimeout);
                    result = codes.BROKE_TARG;
                    return;
                end;
                
                if (sacTime >= (frontdoor/1000)) && (sacTime < (choicePeriod.*frameMsec)/1000);  %less than choice duration window but longer than frontdoor
                    sendCode(codes.CORRECT);
                    result = codes.CORRECT;
                    behav.trialNum = behav.trialNum+1; %increment trial counter 
                elseif sacTime <= frontdoor/1000; %TOO FAST
                    sendCode(codes.FALSE_START);
                    result = codes.FALSE_START;
                elseif (sacTime > (choicePeriod.*frameMsec)/1000)
                    sendCode(codes.LATE_CHOICE); 
                    result = codes.LATE_CHOICE;
                  
                end; 
                
                
            otherwise
                sendCode(codes.SACCADE);
                % incorrect choice -for example chose red, when there was a
                % change...this is a MISS in the SDT sense
                
                
                if (sacTime < (choicePeriod.*frameMsec)/1000)
                    sendCode(codes.MISSED);
                    result = codes.MISSED; %missed the change, said there was no change
                    %behav.trialNum = behav.trialNum+1; 
                    %increment trial counter for CR, FA, MISS or HIT
                elseif (sacTime >= (choicePeriod.*frameMsec)/1000)
                    sendCode(codes.LATE_CHOICE); 
                    result = codes.LATE_CHOICE; 
                    
                end;
                msgAndWait('all_off');
                sendCode(codes.TARG_OFF);
                if result == codes.MISSED  
                    waitForMS(e.falseAlarmTimeout);
                end
                
               
               
                return; 
              
        end;
   
    end;

end; %isChange

%for the correct trials
msgAndWait('all_off');        
sendCode(codes.TARG_OFF); 
    




%REWARD
%NOTE: set e.noManip to 1 and e.e.manipCriterion & e.e.manipSens both to 0 
%if you don't want extra reward for one of
%the spatial locations or sens/criterion spatially manipulated
%EXAMPLE PARAM SETTINGS
% e.noManip == 0, e.manipCriterion ==1, e.manipSens ==0; e.rewardFactor =4;
% OR e.noManip == 0, e.manipCriterion == 0, e.manipSens ==1;
% e.rewardFactor=4;
% OR e.noManip == 1, e.manipCriterion == 0, e.manipSens ==0;


if (e.manipCriterion ==1) || (e.manipSens ==1)
    
    switch times(posPick, behav.cue)
        case -1 %2nd grating on the left AND reward cue on the left on this trial
            %higher reward for left side if that is the current reward cue side
            %e.manipSens =1, then make reward for corrects and correct
            %rejects equal but higher on the left than the right
            %if e.manipCriterion = 1, then make reward higher only for hits
            %on the left
            if result==codes.CORRECT && e.manipSens ==1 
                giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration.*e.rewardFactor);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
            elseif result==codes.CORRECT && e.manipCriterion ==1
                giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration.*e.rewardFactor);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
            elseif result==codes.CORRECT_REJECT && e.manipSens ==1
                 giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration.*e.rewardFactor);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
            elseif result == codes.CORRECT_REJECT && e.manipCriterion ==1
                giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration);
               % giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
            
              
            end
            
        case -2 %2nd grating on the left BUT the reward cue is on the right for this block
            if result==codes.CORRECT && e.manipSens ==1 
                giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
            elseif result==codes.CORRECT && e.manipCriterion ==1
                giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
            elseif result==codes.CORRECT_REJECT && e.manipSens ==1
                 giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
            elseif result == codes.CORRECT_REJECT && e.manipCriterion ==1
                giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
              
            end
        case 1 %2nd grating on the right, but cue is on the left this block
           if result==codes.CORRECT && e.manipSens ==1 
                giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
            elseif result==codes.CORRECT && e.manipCriterion ==1
                giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
            elseif result==codes.CORRECT_REJECT && e.manipSens ==1
                 giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
            elseif result == codes.CORRECT_REJECT && e.manipCriterion ==1
                giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
              
            end
            
        case 2 %2nd grating on the right AND the reward cue is on the right for this block
            %higher reward for right side if that is the reward cue side on this block
            %if e.manipSens =1 , make reward for corrects and correct rejects on the right side equal
            %if e.manipCriterion =1, make reward higher only for hits on the
            %right side
           if result==codes.CORRECT && e.manipSens ==1 
                giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration.*e.rewardFactor);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
            elseif result==codes.CORRECT && e.manipCriterion ==1
                giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration.*e.rewardFactor);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
            elseif result==codes.CORRECT_REJECT && e.manipSens ==1
                 giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration.*e.rewardFactor);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
            elseif result == codes.CORRECT_REJECT && e.manipCriterion ==1
                giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration);
                %giveJuice(params.juiceX.*e.rewardFactor, params.juiceInterval, params.juiceTTLDuration);
                sendCode(codes.REWARD);
              
            end
    end
elseif e.noManip
    if result == codes.CORRECT || (result == codes.CORRECT_REJECT)
        giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration);
        sendCode(codes.REWARD);
    end 
end 
 
if isfield(e,'InterTrialPause')
        waitForMS(e.InterTrialPause); %this was for Wakko to lengthen the intertrial interval to get Wakko to work slower 
end
    
% 
% if posPick<0 && behav.cue<0 %2nd grating on the left AND reward cue on the left on this trial
%     %higher reward for left side if that is the cue  side
%     %but keep reward for corrects and correct rejects equal
%     if result==codes.CORRECT
%         giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration.*e.rewardFactor);
%         sendCode(codes.REWARD);
%                
%     elseif (result == codes.CORRECT_REJECT)
%         giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration.*e.rewardFactor);
%         sendCode(codes.REWARD);
%     end
% elseif posPick<0 && behav.cue>0 %2nd grating on the left BUT the reward cue is on the right for this block
%     %just give the reward set at begin of task
%     if result==codes.CORRECT
%         giveJuice();
%         sendCode(codes.REWARD);
%                
%     elseif (result == codes.CORRECT_REJECT)
%         giveJuice();
%         sendCode(codes.REWARD);
%     end
% elseif posPick>0 && behav.cue>0 %2nd grating on the right AND the reward cue is on the right for this block
%     %higher reward for right side if that is the cue  side on this block
%     %but keep reward for corrects and correct rejects equal
%     if result==codes.CORRECT
%         giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration.*e.rewardFactor);
%         sendCode(codes.REWARD);
%                
%     elseif (result == codes.CORRECT_REJECT)
%         giveJuice(params.juiceX, params.juiceInterval, params.juiceTTLDuration.*e.rewardFactor);
%         sendCode(codes.REWARD);
%     end
% 
% elseif posPick>0 && behav.cue<0 %2nd grating on the right But the reward cue is on the left for this block
%     %just give the reward set at begin of task
%     if result==codes.CORRECT
%         giveJuice();
%         sendCode(codes.REWARD);
%                
%     elseif (result == codes.CORRECT_REJECT)
%         giveJuice();
%         sendCode(codes.REWARD);
%     end
% end
% 
% 
% 
% 
% 
% 
% 
% 




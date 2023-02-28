
function result = ex_changeDetect_dots(e)
% ex file: 
%
% Development notes: KC July 11, 2018

% --> this is an orientation change detection task, 2 alternative forced choice
% --> choice of whether there was a change is indicated by the subject making a saccade to
% a green or red dot AFTER the change occurred 
% --> position of green/red dot is random trial to trial
% --> possible to manipulate reward based on spatial location and trial
% outcome (lines562,and on) 
% --> 07/05/2018 choice dots appear after subject achieves fixation and
% stay on until choice time (fix point goes off) 
% --> stim folder has to be on PATH


global params codes behav allCodes;

e = e(1); %in case more than one 'trial' is passed at a time...
printDebugMessages = false;


%initialize behavior-related stuff like trial count; 
if ~isfield(behav,'trialNum'),
  
    behav.trialNum = 0; 
    % behav.flipFlag = 0; %if we decide to have blocks 
end; 

if printDebugMessages,
    display(behav);
    fprintf('trial  ', behav.trialNum(end)); %which trial number, for debugging
end;

winColors = [0,255,0;255,0,0];
frameMsec = params.displayFrameTime*1000; %this number should be <10> bc each frame is 10 ms long, so 50 frames is 500ms 
stimulusDuration = e.stimulusDuration; %gratings frames
choicePeriod = e.choicePeriod; % this is how long subject has to make a choice...frames
isCatch = e.isCatch; %is this a catch trial
backdoor = choicePeriod.*frameMsec; %make this backdoor longer than choice Period 
frontdoor = (e.frontDoor).*frameMsec; %made the choice too fast .. frontdoor in frames 
    
orientations = [e.orientation1,e.orientation2];
orientations = orientations([e.oriPick 3-e.oriPick]); %randomize orientations

%randomize targ amp change selection here 
e.oriTargAmp = sort(e.oriTargAmp,'ascend'); %ensure sorted
targAmpPick = randi(numel(e.oriTargAmp)); 
targAmp = e.oriTargAmp(targAmpPick);

sendStruct(struct('targAmp',targAmp)); %do we need this? 
%I think this is sent as ascii ?  


if printDebugMessages, fprintf('Position pick: %d\n',posPick); end;

%DETERMINE GRATING AND CHOICE DOT POSITION 
posPick = e.posPick; 
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
msgAndWait('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad 255 255 0]); %constant central fixation (yellow)
%choice dots 

%choice dot green:
msgAndWait('set 11 oval 0 %i %i %i %i %i %i %i',...
    [ greenX greenY e.choiceDotRadius 0 255 0]);

%choice dot red:
msgAndWait('set 12 oval 0 %i %i %i %i %i %i %i',...
    [ redX redY e.choiceDotRadius 255 0 0]);

%set up target when target grating will appear (second "flash")

%if isCatch 
    % isChange = [zeros(1,1) zeros(1,1) ones(1,1)]; 
    % isChange((find(isChange>0,1,'first'))) = [];
 
     %isChange((find(isChange>0,1,'first')):end) = []; %no targets in catch trials, end after withholding on second flash
%else 
     isChange = [zeros(1,1)  ones(1,1)]; 
%end 

msgAndWait('ack'); %to sync to vid refresh
msgAndWait('obj_on 1'); %turn on fixation
sendCode(codes.FIX_ON);

if ~waitForFixation(e.timeToFix,e.fixX,e.fixY,params.fixWinRad)
    % failed to achieve fixation
    sendCode(codes.IGNORED);
    msgAndWait('all_off');
    sendCode(codes.FIX_OFF);
    waitForMS(e.noFixTimeout); % no full time-out in this case
    result = codes.IGNORED;
    return;
end
%otherwise, fixation achieved
sendCode(codes.FIXATE);

if rand<e.fixJuice,  %fixJuice
    giveJuice(1);
end;

%then choice dots come on and stay with fix point for some time before gratings
%come ,continue staying thorughout trial until fix point off 

msg('obj_on 11 12');
sendCode(codes.(sprintf('TARG%d_ON',gd))); %to indicate that the choice dots came on 
%TARG1 means green dot in position 1 and red dot in 2. TARG2 is vice versa

   if ~waitForMS(e.timeWithDots,e.fixX,e.fixY,params.fixWinRad)
            % failed to keep fixation during time with dots
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.noFixTimeout);
            result = codes.BROKE_FIX;
            return;
   end;

%objects 5 & 10 are at the target location, object 6 is the foil on first
%flash of gratings 
%objects 11 and 12 are the choice dots 

for sx = 1:numel(isChange),
    if sx==2, trialStart = tic; end; %mark the time of the  ori change
    
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
    
    %SET UP OBJECTS EARLY
    %Apparently this has to be done anew each stim: 
    
    %unchanged grating 1st flash:
    msgAndWait('set 5 gabor %i %f %f %f %f %i %i %i %f %f',...
        [stimulusDuration  orientations(1) e.phase e.spatial e.temporal targX targY e.radius e.contrast e.radius/4]); 
   
    %the changed grating on 2nd flash:
    msgAndWait('set 10 gabor %i %f %f %f %f %i %i %i %f %f',...
        [stimulusDuration  orientations(1)+targAmp e.phase e.spatial e.temporal targX targY e.radius e.contrast e.radius/4]);

   
    %the other grating on the 1st flash. on the 2nd flash it is blanked:
        if sx==2,
            %particularly important for catch trials 
            msgAndWait('set 6 blank %i', stimulusDuration); %make the foil blank for when change appears 
            standardCode = 'STIM2_ON';
           
        else %on the first set of flashes 
            msgAndWait('set 6 gabor %i %f %f %f %f %i %i %i %f %f',...
            [stimulusDuration  orientations(2) e.phase e.spatial e.temporal distX distY e.radius e.contrast e.radius/4]);
            standardCode = 'STIM1_ON';
        end;
   
    
    if ~isChange(sx), %1st flash
        
       %gratings and choice dots  on
       msg('obj_on 5 6');
       
       sendCode(codes.(standardCode));
                    
        if ~waitForMS(stimulusDuration.*frameMsec,e.fixX,e.fixY,params.fixWinRad)             % failed to keep fixation
            
            sendCode(codes.SACCADE);
            
            choiceWin = waitForFixation(8.*frameMsec,[targX distX],[targY distY],params.targWinRad*[1 1]); %note that target window is always '1' %Not sure about this magic number '8'  here
            switch choiceWin
                case 1
                    
                    result = codes.FALSE_START; 
                    %did subject saccade to one of the gratings? 
                    
                    choicePos=1; %this means target -wherever target was on this trial.
                    %posPick 1 - inRF , posPick -1 means outRF 
                 
                case 2
                   
                    result = codes.FALSE_START; 
                    choicePos = 2;
                    %wherever distractor was on this trial 
                    
                otherwise
                    choicePos = 0;
                    result = codes.BROKE_FIX; 
            end;
            sendCode(result);
            sendCode(codes.(sprintf('CHOICE%d',choicePos)));
            msgAndWait('all_off');
            sendCode(codes.STIM_OFF);
            sendCode(codes.FIX_OFF);
            waitForMS(e.falseStartTimeout);
                       
            return;
        end;      
    end;
        %otherwise correct withhold     
        sendCode(codes.WITHHOLD);
        sendCode(codes.STIM_OFF);
            
        result = codes.WITHHOLD; %don't increment trial counter for withholds within the sequence
    
         
        %CATCH TRIALS : NO GRATING CHANGE
        
        if isCatch &&  sx==2 ;
        msg('obj_on 5 6');
        sendCode(codes.(standardCode));  %STIM2_ON
          if ~waitForMS(stimulusDuration.*frameMsec,e.fixX,e.fixY,params.fixWinRad)   % failed to keep fixation during catch trial
                
                sendCode(codes.SACCADE);
                
                choiceWin = waitForFixation(8.*frameMsec,[targX distX],[targY distY],params.targWinRad*[1 1]); %note that target window is always '1' %Not sure about this magic number '8' 
                switch choiceWin
                    case 1
                        
                        result = codes.FALSE_START; %saccade to grating without waiting for choice period 
                        choicePos=1; %this means wherever grating was on this trial.
                        
                        
                    case 2
                        result = codes.BROKE_FIX; %is this a correct labeling of the outcome?
                        choicePos = 0;
                        %wherever blank distractor was on this trial , saccade to
                        %that blank area
                        
                    otherwise
                        choicePos = 0;
                        result = codes.BROKE_FIX; %don't increment trial counter for broken fixation
                end;
                
                
                sendCode(result);
                sendCode(codes.(sprintf('CHOICE%d',choicePos)));
                msgAndWait('all_off');
                sendCode(codes.STIM_OFF);
                sendCode(codes.FIX_OFF);
                
                %no time out if just broke fix... only if made saccade to
                %changed grating
                if result == codes.FALSE_START; 
                    waitForMS(e.falseStartTimeout);
                end
                
                return;
            end;
            
            % if no broke fix, or false start happened, then go on
            
            sendCode(codes.WITHHOLD);
            sendCode(codes.STIM_OFF);
            
            result = codes.WITHHOLD; %don't increment trial counter for withholds within the sequence
                       
                       
            %CHOICE DOTS ON NEXT --> AFTER a random ISI
            %needs to choose red for a correct outcome here 
            
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
            %otherwise go on: 
            
            msg('obj_off 1'); % fix off, make a choice 
            sendCode(codes.FIX_OFF);
            sendCode(codes.(sprintf('TARG%d_ON',gd))); %send TARG code here again, though the dots have been on since beginning of trial
            %TARG1 means green dot in position 1 and red dot in 2. TARG2 is vice versa
            targOnTime = tic; %time to make a choice starts 
            
            
           choiceWin = waitForFixation(choicePeriod.*frameMsec,[redX greenX],[redY greenY],params.targWinRad*[1 1],winColors(1:2,:)); %note that target window is always '1'
           sacTime = toc(targOnTime); %how long was target on before subject fixated somewhere 
           
            %         if choiceWin==0&&backdoor>(stimulusDuration*frameMsec), %extra time to react after stimulus offset %not happening at the moment -acs10dec2015
            %             sendCode(codes.STIM_OFF);
            %             choiceWin = waitForFixation(backdoor-(stimulusDuration.*frameMsec),[targX distX],[targY distY],params.targWinRad*[1 1],winColors(1:2,:)); %note that target window is always '1'
            %         end;
            %
            
            
%             if sacTime < frontdoor; 
%                     sendCode(codes.FALSE_START); %NOTE so that we can easily tell which trials were no change, should be correct-rejection
%                     result = codes.FALSE_START;
%                     msgAndWait('all_off');
%                 
%             else
            
            switch choiceWin
                case 0 %never makes a choice in either window 
                    
%                     if waitForFixation(1,e.fixX,e.fixY,params.fixWinRad)
%                         sendCode(codes.NO_CHOICE);
%                         
%                         result = codes.NO_CHOICE;
%                     else
                        sendCode(codes.BROKE_FIX); %not sure if this is the correct label                         
                        result = codes.BROKE_FIX;
                    %end;
                    msgAndWait('all_off');
                  
                    waitForMS(e.noFixTimeout); %this is a forced choice task, so should make choice
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
                    
                    
                    if ((sacTime<=backdoor/1000) && (sacTime >= frontdoor/1000));  %less than choice duration window but longer than frontdoor 
                       sendCode(codes.CORRECT_REJECT); %NOTE so that we can easily tell which trials were no change, should be correct-rejection
                       result = codes.CORRECT_REJECT;
               
                    elseif sacTime <= frontdoor/1000; %TOO FAST
                        sendCode(codes.FALSE_START); 
                        result = codes.FALSE_START;
                        msgAndWait('all_off');
                        sendCode(codes.TARG_OFF);
                        waitForMS(e.earlyChoiceTimeout);
                    else
                        sendCode(codes.LATE_CHOICE); %chose too late
                        result = codes.LATE_CHOICE;
                        msgAndWait('all_off');
                        sendCode(codes.TARG_OFF);
                        waitForMS(e.lateChoiceTimeout);
                    end; 
                        
                        
                   
                    
                otherwise
                    sendCode(codes.SACCADE);
                    % incorrect choice -for example chose green, when there
                    % was no  change... this is a False Alarm 
                    % immediately score it, so that the subject
                    %can't then switch to the other stimulus.
                    
                    if sacTime<=backdoor/1000
                        sendCode(codes.FALSEALARM);
                        result = codes.FALSEALARM; %change the result code to indicate a false indication
                    else
                        sendCode(codes.LATE_CHOICE); %missed choice window completely 
                        result = codes.LATE_CHOICE;
                        msgAndWait('all_off');
                        sendCode(codes.TARG_OFF);
                        waitForMS(e.lateChoiceTimeout);
                    end;
                    msgAndWait('all_off');
                   
                
                    
                    return;
            end;
       
   
    
   
 
    %trialEnd = toc(trialStart);
    
    
    
        end; %end if isCatch     
           
            
       
     
            
            
        
   
        
     if ~isCatch && sx == 2;  
        msg('obj_on 10 6');
        sendCode(codes.(standardCode)); %STIM2_ON
        
        targOnTime = tic;
       
         if ~waitForMS(stimulusDuration.*frameMsec,e.fixX,e.fixY,params.fixWinRad)   % failed to keep fixation
            
            sendCode(codes.SACCADE);
            
            choiceWin = waitForFixation(8.*frameMsec,[targX distX],[targY distY],params.targWinRad*[1 1]); %note that target window is always '1' %Not sure about this magic number '8'  here -ACS
            switch choiceWin
                case 1
                    
                    result = codes.FALSE_START; %saccade to changed target without waiting for choice period
                    choicePos=1; %this means target -wherever target was on this trial.
                    
                 
                case 2
                   
                    result = codes.BROKE_FIX; %is this a correct labeling of the outcome?
                    choicePos = 0;
                    %wherever distractor was on this trial , saccade to
                    %that blank area
                    
                otherwise
                    choicePos = 0;
                    result = codes.BROKE_FIX; %don't increment trial counter for broken fixation
            end;
                       
           
            sendCode(result);
            sendCode(codes.(sprintf('CHOICE%d',choicePos)));
            msgAndWait('all_off');
            sendCode(codes.STIM_OFF);
            sendCode(codes.FIX_OFF);
            
            %no time out if just broke fix... only if made saccade to
            %changed grating 
            if result == codes.FALSE_START     %integrate new trial outcome into Runex - KC June 27
                waitForMS(e.falseStartTimeout);
            end
            
            return;
        end;
        
        % if no broke fix, or early choice happened, then go on    
            
        sendCode(codes.WITHHOLD);
        sendCode(codes.STIM_OFF);
            
        result = codes.WITHHOLD; %don't increment trial counter for withholds within the sequence
        
             
        
        %CHOICE DOTS COME ON NEXT AFTER A ISI
       
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
        
        msg('obj_off 1'); % fix off, make a choice 
        targOnTime = tic;
        sendCode(codes.FIX_OFF);
           
        sendCode(codes.(sprintf('TARG%d_ON',gd))); 
        %TARG1 means green dot in position 1 and red dot in 2. TARG2 is vice versa
                
        choiceWin = waitForFixation(choicePeriod.*frameMsec,[greenX redX],[greenY redY],params.targWinRad*[1 1],winColors(1:2,:)); %note that target window is always '1'
        sacTime = toc(targOnTime); %how long has the target been on when fix achieved)
            
        switch choiceWin
            case 0 %never makes a choice/fixates somewhere other than the dots 

                    sendCode(codes.BROKE_FIX); %is this the corect outcome? 
                    
                    result = codes.BROKE_FIX; 
                %end;
                msgAndWait('all_off');
                sendCode(codes.FIX_OFF);
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
                
                 if ((sacTime<=backdoor/1000) && (sacTime > frontdoor/1000));  %less than choice duration window but longer than frontdoor 
                        sendCode(codes.CORRECT); 
                        result = codes.CORRECT;
                        behav.trialNum = behav.trialNum+1; %increment trial counter %only incrementing for hits!
                   
                        
                 elseif sacTime <= frontdoor/1000; %TOO FAST
                     sendCode(codes.FALSE_START);
                     result = codes.FALSE_START;
                     msgAndWait('all_off');
                     sendCode(codes.TARG_OFF);
                     waitForMS(e.earlyChoiceTimeout);
                 else
                     sendCode(codes.LATE_CHOICE); %missed choice window
                     result = codes.LATE_CHOICE;
                     msgAndWait('all_off');
                     sendCode(codes.TARG_OFF);
                     waitForMS(e.lateChoiceTimeout);
                 end;
                                  
                
              
                
            otherwise
                sendCode(codes.SACCADE);
                % incorrect choice -for example chose red, when there was a
                % change...this is a MISS in the SDT sense
                         
                
                if sacTime<=backdoor/1000
                    sendCode(codes.MISSED);
                    result = codes.MISSED; %missed the change, said there was no change
                else
                    sendCode(codes.LATE_CHOICE); %missed the time for the choice making 
                    result = codes.LATE_CHOICE;
                    msgAndWait('all_off');
                    sendCode(codes.TARG_OFF);
                    waitForMS(e.lateChoiceTimeout);
                end;
                msgAndWait('all_off');
                sendCode(codes.STIM_OFF);
                sendCode(codes.FIX_OFF);
              
                
                return;
        end;
    end;
    end; %isChange

msgAndWait('all_off');

%trialEnd = toc(trialStart); %from the time the grating change appeared 


%REWARD 

    if result==codes.CORRECT 
            giveJuice();
          
            sendCode(codes.REWARD);
   
       
    %elseif (result == codes.CORRECT_REJECT)  %manipulate criterion
        % giveJuice(e.CRreward); 
        % sendCode(codes.REWARD);
         
         %return;
    end
    

%sensitivity reward manipulation at a spatial location..I think this should work...KC June2018

%     if result==codes.CORRECT && (posPick ==1)
%        
%             giveJuice(1);
%               
%             sendCode(codes.REWARD);
%             
%     elseif result==codes.CORRECT && (posPick == -1)
%         giveJuice(5);
%               
%         sendCode(codes.REWARD);
%        
% 
%     end



end

   
           
           

        
       
          
      
            
       

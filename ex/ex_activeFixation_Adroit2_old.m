function result = ex_activeFixation_Adroit2(e)
% ex file: ex_activeFixation
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
  
    e = e(1);  % e is set up to possibly have multiple stimuli per trial, but not sure
                % how this works, so only considering "one" trial -BRC

    %initialize behavior-related stuff:
    if ~isfield(behav,'imageShuffle')
        behav.nGroups = e.maxImages/e.imagesPerFixation;
        if rem(e.maxImages,e.imagesPerFixation)~=0
            error('maxImages must be evenly divisible by imagesPerFixation');
        end
        behav.d=RandStream.create('mrg32k3a','seed',str2double(e.day_id));
        behav.imageShuffle = reshape(randperm(behav.d,e.maxImages),e.imagesPerFixation,behav.nGroups);
        behav.grpList = randperm(behav.d,behav.nGroups);
    end

    % if you ran out of groups, reset
    if isempty(behav.grpList)
        behav.imageShuffle = reshape(randperm(behav.d,e.maxImages),e.imagesPerFixation,behav.nGroups);
        behav.grpList = randperm(behav.d,behav.nGroups);
    end

    % reshuffle on every trial to make sure images are run in same sequence
    % twice in a row
    behav.grpList = behav.grpList(randperm(behav.d,numel(behav.grpList)));
    
    imageList = behav.imageShuffle(:,behav.grpList(1));
    imageList = imageList(randperm(behav.d,numel(imageList)));
    tempSend.imageList = imageList;
    sendStruct(tempSend); % store as ascii
    
    % obj 1 is fix spot, obj 2 is stimulus, diode attached to obj 2
    msg('set 1 oval 0 %i %i %i %i %i %i',[e.fixX e.fixY e.fixRad e.fixColor(1) e.fixColor(2) e.fixColor(3)]);
    
    %%% prepare 6 stimuli to show with set (obj Ids: 2,3,4,5,6,7)
        
    image_filepath = [e.image_folder e.day_id filesep];

        for iimage = 1:e.imagesPerFixation
            % set image
            image_filename = sprintf('%s%04d.mat', e.file_prefix, imageList(iimage));  % e.g., "image0001.mat"
            runString_part1 = [e.movieType ' ' image_filepath image_filename];
            runString_part2 = sprintf('%d %d %d %d %d 1000 0 0 %d', e.numframes, e.dwell, e.startframe, e.centerx, e.centery, e.imgDisplaySize);
                % stim_movie_morph params: frameCount, dwell, start_frame, x_pos, y_pos, aperature, morph_type, morph_angle, pixelsize

            runString = [runString_part1 ' ' runString_part2];

            objId = iimage + 1;
            msg(['set ' num2str(objId) ' ' runString]);
        end

            
    % set diode
    diodeList = 1 + (1:e.imagesPerFixation);
    msg(['diode ',num2str(diodeList)]);    
    
    msgAndWait('ack');
    
    pause(e.interTrialInterval/1000);   
    msgAndWait('obj_on 1');
    sendCode(codes.FIX_ON);

    if ~waitForFixation(e.timeToFix,e.fixX,e.fixY,params.fixWinRad)
        % failed to achieve fixation
        sendCode(codes.IGNORED);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        result = codes.IGNORED;        
        return;
    end
    
    sendCode(codes.FIXATE);

    % Juice to keep on task, now with a parameter - MAS 2013/09/20
    if isfield(e,'fixJuice')
        if rand < e.fixJuice, giveJuice(1); end;
    end
    start = tic;
    
    if ~waitForMS(e.preStimFix,e.fixX,e.fixY,params.fixWinRad)
        % animal did *not* hold fixation before stimulus comes on
        sendCode(codes.BROKE_FIX);
        msgAndWait('all_off');
        sendCode(codes.FIX_OFF);
        waitForMS(e.noFixTimeout);
        result = codes.BROKE_FIX;
        return;
    end
    

    %%% present 6 images (100ms each) with inter-image intervals (100ms each)

        result = 1;

        for iimage = 1:6

            % present image
            objId = iimage + 1;
            msgAndWait(['obj_on ' num2str(objId)]);
            sendCode(codes.STIM_ON);
            sendCode(10000+imageList(iimage)); % send image ID

            %tic

            if ~waitForDisplay(e.fixX,e.fixY,params.fixWinRad)
                % animal did not keep fixation during stimulus presentation
                sendCode(codes.BROKE_FIX);
                msgAndWait('all_off');
                sendCode(codes.STIM_OFF);
                sendCode(codes.FIX_OFF);
                waitForMS(e.noFixTimeout);
                result = codes.BROKE_FIX;
                return;
            end

            %msgAndWait(['obj_off ' num2str(objId)])
            sendCode(codes.STIM_OFF);
            %toc

            % inter-image interval
            if iimage < 6   % no interval for last image presented
                if ~waitForMS(e.interImageInterval,e.fixX,e.fixY,params.fixWinRad)
                    % animal did *not* hold fixation before next stimulus comes on
                    sendCode(codes.BROKE_FIX);
                    msgAndWait('all_off');
                    sendCode(codes.FIX_OFF);
                    waitForMS(e.noFixTimeout);
                    result = codes.BROKE_FIX;
                    return;
                end
            end

        end


    %%% 6 images have been presented, so now present a target to saccade to, after a
            %  brief (random) amount of time

        % pre-target waiting period (random)
        if ~waitForMS(e.preTargetInterval,e.fixX,e.fixY,params.fixWinRad)
            % animal did *not* hold fixation before next stimulus comes on
            sendCode(codes.BROKE_FIX);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            waitForMS(e.noFixTimeout);
            result = codes.BROKE_FIX;
            return;
        end
        

        % choose a target location randomly around a circle
        theta = deg2rad(e.saccadeDir);
        newX = round(e.saccadeLength * cos(theta)) + e.fixX;
        newY = round(e.saccadeLength * sin(theta)) + e.fixY;
        msg('set 1 oval 0 %i %i %i %i %i %i',[newX newY e.fixRad e.fixColor(1) e.fixColor(2) e.fixColor(3)]);
  
        sendCode(codes.FIX_MOVE);

        % recenter fixation window
        if params.recenterFixWin
            newFixWinRad = params.sacWinRad;
        else
            newFixWinRad = params.fixWinRad;
        end

        % animal should make a saccade within a certain time
        if waitForMS(e.saccadeInitiate,e.fixX,e.fixY,newFixWinRad,'recenterFlag',params.recenterFixWin)
            sendCode(codes.NO_CHOICE);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            result = codes.NO_CHOICE;
            return;
        end
        
        sendCode(codes.SACCADE);
        
        % animal should complete saccade within a certain time
        if ~waitForFixation(e.saccadeTime,newX,newY,params.targWinRad)
            % animal did not reach target
            sendCode(codes.NO_CHOICE);
            msgAndWait('all_off');
            sendCode(codes.FIX_OFF);
            result = codes.NO_CHOICE;
            return;
        end
        elapsed = toc(start);
        
        % animal stays on target for a brief amount of time
        if ~waitForMS(e.stayOnTarget,newX,newY,params.targWinRad)
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

        sendCode(codes.FIXATE);
        sendCode(codes.CORRECT);
        msgAndWait('all_off'); % added MAS 2016/10/12 to turn off fix spot before reward
        sendCode(codes.FIX_OFF);
        sendCode(codes.REWARD);
        giveJuice();
        behav.grpList(1)=[]; % get rid of the current entry on correct trials

%         if isfield(e,'InterTrialPause')
%             waitForMS(e.InterTrialPause); 
%         end



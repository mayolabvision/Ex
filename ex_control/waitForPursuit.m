function trialSuccess = waitForPursuit(waitTime, pursuitStartTime, startX, startY, pursuitRadius, pursuitSpeed, angle, jumpSize, varargin)
% function success = waitForPursuit(waitTime,fixX,fixY,r)
% 
% ex trial helper function: waits for t ms, checking to ensure that the eye
% remains within the fixation window.  If time expires, trialSuccess = 1, 
% but if fixation is broken first, trialSuccess returns 0
%
% waitTime: time to maintain fixation (in ms)
% fixX, fixY: in pixels, the offset of the fixation from (0,0)
% r: in pixels, the radius of the fixation window
%
% 2015/08/14 by Adam Snyder and Matt Smith. Now aloopTopllows user to pass a
% 'recenterFlag' such that the fixX and fixY will be ignored and instead
% the current eye position is used.
%

global params;

    winColors = [255 255 0];
    pursuitRadius = pursuitRadius*deg2pix(1); %# of pixels per 1 degree
    recenterFlag = false;
    if nargin > 7        
        vx = 1;
        while vx <= numel(varargin),
            switch class(varargin{vx})
                case 'char'
                    recenterFlag = varargin{vx+1};      
                    vx = vx+2;
                otherwise
                    if ~isempty(varargin{vx}),
                        winColors = varargin{vx};
                    end;
                    vx = vx+1;
            end;
        end;   
    end;
    
    if recenterFlag,
        d=samp;
        eyePos = projectCalibration(d(end,:)); %changed to new project calibration function (supports polynomial regressors) -ACS 29Oct2013
        startX = eyePos(1);
        startY = eyePos(2); 
%        fixX = eyePos(1)+fixX; % removed the fixX/Y addition here - that's
%        not right % MAS Sept2019
%        fixY = eyePos(2)+fixY; %is the sign here correct? -ACS 14Aug2015
    end;
    
    if nargin >= 7
%        drawFixationWindows(startX,startY,pursuitRadius,winColors);
    elseif nargin ~= 7 || nargin ~=8
        error('waitForPursuit can have exactly 7 or 8  input arguments');
    end
    
    % Draw the fixation window
    time_weight = 0:1/3:1;
    
    horz_input = startX + jumpSize*deg2pix(1)*cos(deg2rad(angle)) + pursuitSpeed*deg2pix(1)*cos(deg2rad(angle))*(waitTime/1000)*(time_weight);
    vert_input = startY + jumpSize*deg2pix(1)*sin(deg2rad(angle)) + pursuitSpeed*deg2pix(1)*sin(deg2rad(angle))*(waitTime/1000)*(time_weight);
    
    
    drawFixationWindows(horz_input, vert_input, ones(1, numel(time_weight))*pursuitRadius, ones(numel(time_weight),1)*winColors)
    
    
    trialSuccess = 1;
    thisStart = tic;

    if nargin >= 7         
        while (toc(thisStart)*1000) <= waitTime
            % Create Window
            xPos = startX + jumpSize*deg2pix(1)*cos(deg2rad(angle)) + pursuitSpeed*deg2pix(1)*cos(deg2rad(angle))*(GetSecs-pursuitStartTime);
            yPos = startY + jumpSize*deg2pix(1)*sin(deg2rad(angle)) + pursuitSpeed*deg2pix(1)*sin(deg2rad(angle))*(GetSecs-pursuitStartTime);
            
%            
            
%            trialSuccess = 1;
            
            % Eye Stuff
            loopTop = GetSecs;
            d=samp;
            eyePos = projectCalibration(d(end,:)); %changed to new project calibration function (supports polynomial regressors) -ACS 29Oct2013

 %           eyePos = eyePos - [fixX fixY];

            relPos = bsxfun(@minus,eyePos(:),[xPos;yPos]); %position relative to each window        
            switch size(pursuitRadius,1)
                case 1, %circular window        
                    inWin = sum(relPos.^2,1)<pursuitRadius.^2; 
                case 2, %rectangular window
                    inWin = all(abs(relPos)<abs(pursuitRadius),1);
                otherwise
                    error('EX:waitForMS:badRadius','Radius must have exactly 1 or 2 rows');
            end;

            if keyboardEvents()||~inWin
                trialSuccess = 0;
                break;
            end
            if (GetSecs-loopTop)>params.waitForTolerance, warning('waitFor:tooSlow','waitForMS exceeded latency tolerance - %s',datestr(now)); end; %warn tolerance exceeded -acs22dec2012
            
        end
    else %don't worry about fixation window - this is essentially just a pause (can be broken with a key press)
        while (toc(thisStart)*1000) <= waitTime
            loopTop = GetSecs;            
            if keyboardEvents()
                trialSuccess = 0;
                break;
            end
            if (GetSecs-loopTop)>params.waitForTolerance, warning('waitFor:tooSlow','waitForMS exceeded latency tolerance - %s',datestr(now)); end; %warn tolerance exceeded -acs22dec2012
        end
    end
    if nargin > 2
        drawFixationWindows()
    end
end

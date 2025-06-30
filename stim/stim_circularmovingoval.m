function stim_circularmovingoval(optstr,w,objID,arg)
%function stim_circularmovingoval(optstr,w,objID,arg)
%
% showex helper function for 'circularmovingoval' stim class
%
% Each helper function has to have the ability to do 3 things:
% (1) parse the input arguments from the 'set' command and precompute
% anything that is necessary for that stimulus
% (2) issue the display commands for that object
% (3) clean up after that object is displayed (not always necessary)

global objects;
global sv;

if strcmp(optstr,'setup')
    a = sscanf(arg,'%i %f %i %f %i %i %i %i');
    % arguments: (1) frameCount
    %            (2) eccentricity - radius of of circle perferably in dva
    %            (3) ang velocity - angular change per second
    %            (4) starting angle - starting position in degrees
    %            (5) radius - size of oval 
    %            (6) color, R
    %            (7) color, G
    %            (8) color, B
    stimname = mfilename;
    objects{objID} = struct('type',stimname(6:end),'frame',0,'fc',a(1),'eccentricity',a(2), ...
        'angVelocity',a(3),'startingAngle',a(4),'rad',a(5), 'col',a(6:end));
    
    % Angle Change per frame 
    % sv.ppd = pixels in 1 degree of visual angle
    % sv.ifi = interframe interval in seconds (1/sv.ifi = round(1/0.0083) = 120)
    objects{objID}.angularChangePerFrame = a(3)/round(1/sv.ifi); % angular change per second / frames per second
      
%     % Find starting cartesian coordinates 
%     objects{objID}.startX = a(2)*sv.ppd*cos(deg2rad(a(4))); % eccentricity* pixels in 1 dva * cos(staring angle in radians)
%     objects{objID}.startY = -1*(a(2)*sv.ppd*sin(deg2rad(a(4)))); % same as X but with cosign... -1 to flip
    
elseif strcmp(optstr,'display')
    % SHAWN - put in code that moves the dot to where it should go
    % or, use the .frame variable to figure out targetPos with a bit of code
    %    targetPos = [sv.midScreen + [objects{objID}.x objects{objID}.y] - objects{objID}.rad,sv.midScreen + [objects{objID}.x objects{objID}.y] + objects{objID}.rad];
    
    newx = objects{objID}.eccentricity*sv.ppd*cos(deg2rad(objects{objID}.startingAngle + objects{objID}.frame*objects{objID}.angularChangePerFrame));
    newy = objects{objID}.eccentricity*sv.ppd*sin(deg2rad(objects{objID}.startingAngle + objects{objID}.frame*objects{objID}.angularChangePerFrame));
    
    % need a little more logic to get this dot to stop moving
    
    targetPos = [sv.midScreen + [newx newy] - objects{objID}.rad,sv.midScreen + [newx newy] + objects{objID}.rad];
    Screen(w,'FillOval',objects{objID}.col,targetPos);
elseif strcmp(optstr,'cleanup')
    % nothing necessary for this stim class
else
    error('Invalid option string passed into stim_*.m function');
end

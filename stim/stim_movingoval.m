function stim_movingoval(optstr,w,objID,arg)
%function stim_movingoval(optstr,w,objID,arg)
%
% showex helper function for 'movingoval' stim class
%
% Each helper function has to have the ability to do 3 things:
% (1) parse the input arguments from the 'set' command and precompute
% anything that is necessary for that stimulus
% (2) issue the display commands for that object
% (3) clean up after that object is displayed (not always necessary)

global objects;
global sv;

if strcmp(optstr,'setup')
    a = sscanf(arg,'%i %i %i %i %i %i %f %i %i %i');
    % arguments: (1) frameCount
    %            (2) startx position
    %            (3) starty position
    %            (4) radius
    %            (5) speed
    %            (6) angle
    %            (7) jumpSize
    %            (8) color, R
    %            (9) color, G
    %            (10) color, B
    stimname = mfilename;
    objects{objID} = struct('type',stimname(6:end),'frame',0,'fc',a(1),'x',a(2), ...
        'y',-a(3),'rad',a(4),'spd',a(5), 'ang', a(6), 'jump', a(7), 'col',a(8:end));
    % Frame by Frame offset
    objects{objID}.xoffsetPerFrame = a(5)*sv.ppd*cos(deg2rad(a(6)))/round(1/sv.ifi); % spd (Degrees per second) * Pix2Deg(#  pixels in 1 deg vis ang) *cos(ang (radians))/FrameRate (Hz)
    objects{objID}.yoffsetPerFrame = -1*(a(5)*sv.ppd*sin(deg2rad(a(6)))/round(1/sv.ifi)); % spd*Pix2Deg*sin(ang)/FrameRate) % -1 to flip for PTB vs Ex vertical 
    
    % Jump around fixation
    objects{objID}.startX = a(2) + a(7)*sv.ppd*cos(deg2rad(a(6)));
    objects{objID}.startY = -1*(a(3) + a(7)*sv.ppd*sin(deg2rad(a(6))));
    
elseif strcmp(optstr,'display')
    % SHAWN - put in code that moves the dot to where it should go
    % or, use the .frame variable to figure out targetPos with a bit of code
    %    targetPos = [sv.midScreen + [objects{objID}.x objects{objID}.y] - objects{objID}.rad,sv.midScreen + [objects{objID}.x objects{objID}.y] + objects{objID}.rad];
    newx = objects{objID}.startX + objects{objID}.xoffsetPerFrame * objects{objID}.frame; % objects{objID}.jump * cos(deg2rad(a(6)) +
    newy = objects{objID}.startY + objects{objID}.yoffsetPerFrame * objects{objID}.frame; % objects{objID}.jump * sin(deg2rad(a(6)) +
    % need a little more logic to get this dot to stop moving
    
    targetPos = [sv.midScreen + [newx newy] - objects{objID}.rad,sv.midScreen + [newx newy] + objects{objID}.rad];
    Screen(w,'FillOval',objects{objID}.col,targetPos);
elseif strcmp(optstr,'cleanup')
    % nothing necessary for this stim class
else
    error('Invalid option string passed into stim_*.m function');
end

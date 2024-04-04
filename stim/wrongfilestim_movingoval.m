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
    a = sscanf(arg,'%i %i %i %i %i %i %i %i %i %i %f');
    % arguments: (1) frameCount
    %            (2) startx position
    %            (3) starty position
    %            (4) radius
    %            (5) endx position
    %            (6) endy position
    %            (7) speed
    %            (8) angle
    %            (9) color, R
    %            (10) color, G
    %            (11) color, B
    %            (12) color, alpha   -13/3/19 HS for transparency
    stimname = mfilename;
    objects{objID} = struct('type',stimname(6:end),'frame',0,'fc',a(1),'x',a(2), ...
        'y',-a(3),'rad',a(4),'endx',a(5),'endy',a(6),'spd',a(7), 'ang', a(8),'col',a(9:end));
    % do trig here
    objects{objID}.xoffsetPerFrame = a(7)*27.87*cos(deg2rad(a(8)))/144; % hacked, use spd instead
    objects{objID}.yoffsetPerFrame = a(7)*27.87*sin(deg2rad(a(8)))/144; % hacked
elseif strcmp(optstr,'display')
    % SHAWN - put in code that moves the dot to where it should go
    % or, use the .frame variable to figure out targetPos with a bit of
    % code
    %    targetPos = [sv.midScreen + [objects{objID}.x objects{objID}.y] - objects{objID}.rad,sv.midScreen + [objects{objID}.x objects{objID}.y] + objects{objID}.rad];
    newx = objects{objID}.x+objects{objID}.xoffsetPerFrame*objects{objID}.frame;
    newy = objects{objID}.y+objects{objID}.yoffsetPerFrame*objects{objID}.frame;
    % need a little more logic to get this dot to stop moving
    
    targetPos = [sv.midScreen + [newx newy] - objects{objID}.rad,sv.midScreen + [newx newy] + objects{objID}.rad];
    Screen(w,'FillOval',objects{objID}.col,targetPos);
elseif strcmp(optstr,'cleanup')
    % nothing necessary for this stim class
else
    error('Invalid option string passed into stim_*.m function');
end

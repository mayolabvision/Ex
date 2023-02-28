%function flashBW(tpause,nflips)
%
% This function will flash a black and white screen with a tpause seconds
% pause between flips and nflips number of black-white screen flashes.
%

function flashBW(tpause,nflips)

if (nargin < 2)
    tpause = 0.5;
    nflips = 4;
end

% Don't need gamma correction for this, but you could use it if desired
%Screen('LoadNormalizedGammaTable',0);

% open a new window, fill with black background and pause for 10 seconds
w = Screen('OpenWindow',0);
Screen(w,'FillRect',[0 0 0]); 
Screen('Flip',w); pause(10);

%flash black and white screen
for ii = 1:nflips
    Screen(w,'FillRect',[0 0 0]);
    Screen('Flip',w); 
    % send digital code that goes into NEV file
    unixSendByte(999+(ii*2)-1); % or use any number you want from 1000-32000
    pause(tpause);
    Screen(w,'FillRect',[255 255 255]);
    Screen('Flip',w);
    % send digital code that goes into NEV file    
    unixSendByte(999+(ii*2)); % or use any number you want from 1000-32000
    pause(tpause);
end


% return to black background and pause for 10 seconds
Screen(w,'FillRect',[0 0 0]);
Screen('Flip',w); pause(10);
    
sca

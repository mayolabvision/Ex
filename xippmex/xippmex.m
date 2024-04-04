% xippmex_help.m Help file for XIPPMEX MEX-file
%
% XIPPMEX Matlab interface to NIP and Trellis software through XIPP.
%
% usage: xippmex(cmdstr [, args])
%                 'time' - display latest NIP time
%                 'addoper' - add TCP operator
%                 'processor-restart' - restart the processor
%                 'elec' - retrieve electrode numbers by type of headstage
%                 'spike' - get recent spike counts and times
%                 'spike-thresh' - set and receive spike thresholds
%                 'cont' - get continuous data
%                 'cont-adc' - get continuous data
%                 'digin' - retrieve digital inputs
%                 'digout' - control digital outputs
%                 'stim' - send stim control string
%                 'stimseq' - complex control of stimulation
%                 'signal' - enable or disable signals
%                 'signal-save' - enable or disable recording signals
%                 'filter' - modify and retrieve filter information
%                 'fastsettle' - control or display NIP fast settle
%                 'lowcorner' - set an electrode's hardware filter low corner
%                 'adc2phys' - set an electrode's ADC resolution
%                 'trial' - control file save on Trellis operators
%                 'impedance' - trigger impedance measurement
%                 'ground' - control hardware ground switch on permitted FEs
%                 'reference' -  control hardware reference switch on permitted FEs
%                 'transceiver' - control transceiver for implant
%                 'battery' - retrieve battery charge level
%                 'sensor' - retrieve processor sensor values
%                 'button' - retrieve button-press counts
%                 'led' - get or sed LED illumination status
%                 'audio-tone' - set and retrieve beep frequency and duration
%                 'close' - close UDP socket and delete cached data
%                 'version' - retrieve software and protocol versions
%
%                 For more info, type command strings without arguments
%
% xippmex version 1.7.2.97
% xipplib version 0.9.1.
% XIPP protocol version 0.9.
%
%  MEX-File function

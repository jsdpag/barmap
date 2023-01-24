
% 
% session_launch_script.m
% 
% Task-specific launch setting actions go here. Define sesslaunchparams for
% special actions. It is an optional struct with optional fields:
% 
%   .EyeServer_TransferData - If true then EDF is transferred.
%   .EyeServer_UniqueTmp  - If true then each session number gets its own
%     tmp<session id>.edf file on the EyeLink host PC. Thus, make sure that
%     each session gets a unique id on a given day.
% 

% Open a separate EDF file on EyeLink HostPC for each unique session ID
sesslaunchparams.EyeServer_UniqueTmp = true ;

% Disable automatic transfer of EDF from EyeLink HostPC to ARCADE PC
sesslaunchparams.EyeServer_TransferData = false ;

% Don't open normal ARCADE control screen. Use the minimalist remote,
% instead.
cfg.ControlScreen = 'makeArcadeRemote.m' ;

% Place ARCADE remote in upper-right hand corner of screen
sesslaunchparams.Location_ArcadeRemote = 'northeast' ;

% Starting positions of EyeLinkServer and EchoServer
sesslaunchparams.Position_EyeServer  = [  1  , 1 , -1  , -1  ] ;
sesslaunchparams.Position_EchoServer = [ 871 , 1 , 588 , 647 ] ;


% 
% session_launch_script.m
% 
% Task-specific launch setting actions go here. Define sesslaunchparams for
% special actions.
% 

% Disable automatic transfer of EDF from EyeLink HostPC to ARCADE PC
sesslaunchparams.EyeServer_TransferData = false ;

% Don't open normal ARCADE control screen. Use the minimalist remote,
% instead.
cfg.ControlScreen = 'makeArcadeRemote.m' ;


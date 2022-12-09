
function  syn = initsynapse( cfg , TdtHostPC , TdtExperiment , varargin )
% 
% syn = initsynapse( cfg , TdtHostPC , TdtExperiment , <Gizmo names> )
% 
% Run this function during ARCADE session and task initialisation to
% establish a link with the Synapse server that runs on the TDT Host PC.
% Input arguments include the session's ArcadeConfig object (from
% retrieveConfig) and strings naming the Host PC on the network (TdtHostPC)
% and the expected name of the Synapse experiment (TdtExperiment).
% Remaining input arguments are strings naming Gizmos that are required.
% 
% Makes sure that Synapse is set with the correct experiment and subject
% names. Checks for named Gizmos. Also makes sure that Synapse is in a
% run-time mode.
% 
% Returns empty [ ] if TdtHostPC is 'none'.
% 
% Jackson Smith - December 2022 - Fries Lab (ESI Frankfurt)
  
  
  %%% Global constant %%%
  
  % Number of fixed input args
  NFIXARG = 3 ;

  
  %%% Error check editable vars %%%
  
  % Primary parameters are strings
  checkvar(       TdtHostPC , 'TdtHostPC'       )
  checkvar(   TdtExperiment , 'TdtExperiment'   )
  
    % No TDT Host PC has been named. Quit now and return empty.
    if  strcmp( TdtHostPC , 'none' ) , syn = [ ] ; return , end
  
  % Gizmo names are strings
  for  i = 1 : nargin - NFIXARG
    checkvar( varargin{ i } , sprintf( 'Input arg %d' , i + NFIXARG ) )
  end
  
  
  %%% Establish link to Synapse %%%
  
  %-- Check Synapse properties --%
  
  % CONSTANT - A table matching Synapse to ARCADE properties. Column order
  % is [ Synapse property name , SynapseAPI function name , ARCADE value ].
  P2P = { 'Experiment' , 'getCurrentExperiment' , TdtExperiment ;
          'Subject'    , 'getCurrentSubject'    , cfg.Subject   } ;
  
  % Make a SynapseAPI object
  syn = SynapseAPI( TdtHostPC ) ;
  
  % Property index
  p = 1 ;
  
  % Property loop , expand table's row into named variables
  while  p <= size( P2P , 1 ) , [ snam , psyn , varc ] = P2P{ p , : } ;
    
    % Get value of Synapse property
    vsyn = iget( syn , psyn ) ;
    
    % Property values are the same
    if  strcmp( vsyn , varc )
      
      % Go to next property
      p = p + 1 ;
      
    % Properties differ, instruct user to make a change
    else
      
      % Prompt user
      waitforuser( 'Bar Mapping' , 14 , ...
        'Please change Synapse %s from %s to %s.' , snam , vsyn , varc )
      
    end % check property values
  end % property loop
  
  
  %-- Look for specific named Gizmos --%
  
  if  nargin > NFIXARG
    
    % Check for missing named Gizmos
    missing = ~ ismember( vararg , iget( syn , getGizmoNames ) ) ;
    
    % There are missing Gizmos
    if  any( missing )
      error( [ 'Synapse experiment %s lacks Gizmos required by ' , ...
        'ARCADE task %s: %s' ] , TdtExperiment , cfg.taskFile , ...
          strjoin( varargin( missing ) , ' , ' ) )
    end
    
  end % check for gizmos

  
  %-- Check that Synapse is in a run-time mode --%
  
  % 2 - Preview, 3 - Recording.
  while  iget( syn , 'getMode' ) < 2
    
    % Prompt user
    waitforuser( 'Bar Mapping' , 14 , ...
      'Please put Synapse into a run-time mode.' )
    
  end % run-time mode
  
  
end % initsynapse


%%% Sub-routines %%%

% Check that variable is a classic String
function  checkvar( var , nam )
  
  % Correctly formatted
  if  ischar( var ) && isrow( var ) , return , end
  
  % We only get here if the variable is not correct
  error( '%s must be a classic string i.e. char row vector' , nam )
  
end % checkvar


% Try to retrieve information from SynapseAPI object. Raise an error on
% failure.
function  i = iget( syn , fnam )
  
  % An error indicates lack of connection. But SynapseAPI error messages
  % are not immediately clear.
  try
    
    i = syn.( fnam ) ;
    
  catch
    
    % Throw a simple, reader-friendly error message.
    error( 'No connection to Synapse server on Host: %s' , syn.SERVER )
    
  end
  
end % iget


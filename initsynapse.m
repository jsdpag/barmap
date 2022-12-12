
function  syn = initsynapse( cfg , tab , evm , err , TdtHostPC , ...
  TdtExperiment , varargin )
% 
% syn = initsynapse( cfg , evm , err , TdtHostPC , TdtExperiment , 
%                    <Gizmo names> )
% 
% Run this function during ARCADE session and task initialisation to
% establish a link with the Synapse server that runs on the TDT Host PC.
% Input arguments include the session's ArcadeConfig object (from
% retrieveConfig), a table of trial conditions (tab), struct (evm) of event
% marker names (fields) and codes (field value), struct (err) of trial
% error code names (fields) and codes (field value), and strings naming the
% Host PC on the network (TdtHostPC)  and the expected name of the Synapse
% experiment (TdtExperiment). Remaining input arguments are strings naming
% Gizmos that are required.
% 
% Makes sure that Synapse is set with the correct experiment and subject
% names. Checks for named Gizmos. Also makes sure that Synapse is in a
% run-time mode. Generates ARCADE session header and sends to Synapse as
% run-time note; these include information about the setup, the event
% markers, and error codes.
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
    missing = ~ ismember( varargin , iget( syn , getGizmoNames ) ) ;
    
    % A Gizmo is not missing if the name is 'none'
    missing = missing  &  ~ strcmpi( varargin , 'none' ) ;
    
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
  
  
  %-- ARCADE session header --%
  
  % Tell cellfun to return cell array
  uof = { 'UniformOutput' , false } ;
  
  % Cell array of strings containing names of ArcadeConfig properties to
  % include in header
  C = { 'Experiment' , 'Experimenter' , 'ProjectOwner' , 'Subject' , ...
    'Session' , 'sessionName' , 'DistanceToScreen' , ...
      'MonitorDiagonalSize' , 'PixelsPerDegree' , 'MonitorRefreshRate' ,...
        'BackgroundRGB' } ;
  
  % First block of lines in header with session parameters
  hdr = cellfun( @( c ) val2str( cfg.( c ) ) , C , uof{ : } ) ;
  
  % Extract screen size
  hdr = [ hdr , ...
    { [ 'MonitorWidthPixels '  , cfg.MonitorResolution.width  ] , ...
      [ 'MonitorHeightPixels ' , cfg.MonitorResolution.height ] } ] ;
  
  % Fetch editable variable names and values
  C = cfg.EditableVariables( : , 1 : 2 )' ;
  
  % Add editable variables
  hdr = [ hdr , { sprintf( 'Editable variables %d' , size( C , 2 ) ) } ,...
    cellfun( @( v , x ) [ v , ' ' , x ] , C( 1 , : ) , C( 2 , : ) , ...
      uof{ : } )' ] ;
  
  % Event marker names
  C = fieldnames( evm )' ;
  
  % Add marker names and values
  hdr = [ hdr , { sprintf( 'Event markers %d' , numel( C ) ) } , ...
    cellfun( @( c ) sprintf( '%s %d' , c , evm.( c ) ) , C , uof{ : } ) ] ;
  
  % Error codes
  
  % Table 2 string
  
  % Send synapse api runtime note
  
  hdr = [ { 'ARCADE session header start' } , ...
            cell2mat( @( f ) , [ f , ' ' , cfg.( f ) ] ,  )
            { 'ARCADE session header end' } ] ;
  
  
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


% Convert matrix to string or return string
function  str = val2str( val )
  
  % Already a string, return that. Otherwise, convert numeric matrix to
  % string.
  if  ischar( val )
    str = val ;
  else
    str = mat2str( val ) ;
  end
  
end % val2str

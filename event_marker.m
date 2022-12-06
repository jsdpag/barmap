
function  [ e , h ] = event_marker( states )
% 
% [ e , h ] = event_marker( states )
% 
% Creates unsigned 16-bit integer codes for each state named in states, a
% cell array of strings. Discards special values 1, used by ARCADE for init
% and shutdown time stamps, and the session Pause/Resume codes. The latter
% are found in the session's ArcadeConfig object. Reserves the use of value
% 65534 & 65535 (2^16-[2,1] i.e. intmax( 'uint16' )-[2,1]) to signal the
% start and end of a text stream (see below). All state names must be valid
% MATLAB field names. Returns struct e, where each field names an event and
% contains its numeric code i.e. marker. Also returns struct h, where each
% field is named after a string in states, and contains a cell array with
% two anonymous function handles; the first trigger's the named state's
% *_end event marker, and the second triggers the same state's *_exit
% marker.
% 
% Four unique event markers are assigned to each state to time-stamp the
% following events, each time that the state executes (State.run() called).
% For a state with name <state>, these events are called:
%   
%   <state>_entry - Beginning of onEntry function calls, before any other
%     onEntry function executes.
%   
%   <state>_start - Timer starts and counts down the state's duration.
%     This should be considered mandatory and must always be the last to
%     execute in the onEntry functions.
%
%   <state>_end - The timer has stopped and the state will transition to
%     the next state in the task. This occurs if the timer runs down. Or
%     when an external event is detected that the state must respond to.
%     This should be considered manditory and must always be the first to
%     execute in the onExit functions.
%   
%   <state>_exit - Finised executing all other onExit function calls.
% 
% Two more event markers are defined to signal the beginning and end of a
% text stream:
%   
%   TextUTF16_entry - All event markers that follow this should be
%     interpreted as text with UTF-16 encoding. Only values between 0 and
%     65533 are valid. Has value 65534.
%   
%   TextUTF16_exit - Finished text stream. Interpret all following event
%     markers as time-stamped events in the trial. Has value 65535.
% 
% Written by Jackson Smith - May 2022 - Fries Lab (ESI Frankfurt)
% 
  
  % Empty input
  if  isempty( states )
    
    error( 'states is empty' )
  
  % Input arg must be cell array of strings
  elseif  ~ iscellstr( states )
    
    error( 'states must be cell array of strings' )
    
  % All strings must be valid variable/field names
  elseif  any( ~ cellfun( @isvarname , states ) )
    
    error( 'states must contain valid MATLAB variable/field names' )
    
  end % input check
  
  % Guarantee that states is a row vector
  if  ~ isrow( states ) , states = states( : )' ; end
  
  % Number of events per state
  NSTATE = 4 ;
  
  % Suffixes for each state-specific event name
  SUFFIX = { 'entry' , 'start' , 'end' , 'exit' } ;
  
  % Constant, reserved ARCADE init/shutdown code
  ARCADE_INIT_SHUTDOWN = 1 ;
  
  % Constant, reserved for start and end of text stream
  TEXT_NAME = 'TextUTF16' ;
  TEXT_STREAM_START = struct( 'name' , [ TEXT_NAME , '_entry' ] , ...
                               'val' , 2 ^ 16 - 2 ) ;
  TEXT_STREAM_END   = struct( 'name' , [ TEXT_NAME , '_exit' ] , ...
                               'val' , 2 ^ 16 - 1 ) ;

    % Make sure that no state name is confused with text stream events
    if  any( strcmp( states , TEXT_NAME ) )
      error( 'State name %s is reserved.' , TEXT_NAME )
    end
  
  % Get session ArcadeConfig object
  cfg = retrieveConfig ;
  
  % Reserved values
  RESERVED = [ ARCADE_INIT_SHUTDOWN ;
               TEXT_STREAM_START.val ;
               TEXT_STREAM_END.val ;
               cfg.EventMarker.Pause ;
               cfg.EventMarker.Resume ] ;

	% Check that there are no repeat values, otherwise the same event code
	% will be assigned to multiple events
  if  numel( RESERVED ) ~= numel( unique( RESERVED ) )
    error( 'Duplicate codes used by multiple reserved events.' )
  end
  
  % Create a list of possible event marker values, from one to number of
  % states plus number of reserved values
  eval = 1 : NSTATE * numel( states ) + numel( RESERVED ) ;
  
  % Remove reserved values
  eval( ismember( eval , RESERVED ) ) = [ ] ;
  
  % Marker code index
  i = 0 ;
  
  % State names
  for  STATES = states , nam = STATES{ 1 } ;
    
    % State-specific events, increment marker index, get code value
    for  C = SUFFIX , suffix = C{ 1 } ; i = i + 1 ; val = eval( i ) ; 
    
      % Assign event marker code to named state
      e.( [ nam , '_' , suffix ] ) = val ;
      
    end % state events
    
    % State's *_end and *_exit event marker codes
    emcend  = e.( [ nam , '_end'  ] ) ;
    emcexit = e.( [ nam , '_exit' ] ) ;
    
    % Build h
    h.( nam ) = { @( ) eventmarker( emcend  ) ;
                  @( ) eventmarker( emcexit ) } ;
    
  end % states
  
  % Text stream events
  e.( TEXT_STREAM_START.name ) = TEXT_STREAM_START.val ;
  e.( TEXT_STREAM_END.name   ) =   TEXT_STREAM_END.val ;
	
end % rt_det_train_event_marker


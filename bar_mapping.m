
% 
% bar_mapping.m
% 
% Automated receptive field mapping algorithm. An implementation of Fiorani
% et al. (2014, J. Neurosci. Methods, 221, 112-126). Moves a bar in
% specified directions. Uses SynapseAPI and tdt-windowed-buffering to store
% and retrieve spiking and MUA signals containing visual responses. These
% are projected onto a spatial map, so that the RF location can be
% visualised and estimated.
% 
% Uses Win32 StimServerAnimationDone event from StimServer to
% control the timing on states.
% 
% Jackson Smith - Dec 2022 - Fries Lab (ESI Frankfurt)
% 

%%% GLOBAL INITIALISATION %%%

% Session's ARCADE config object
cfg = retrieveConfig ;

% Condition, block, outcome and reaction time of all previous trials
pre = getPreviousTrialData ;

% Gain access to block selection function's global variable
global  ARCADE_BLOCK_SELECTION_GLOBAL ;


%%% FIRST TRIAL INITIALISATION -- PERSISTENT DATA %%%

if  TrialData.currentTrial == 1
  
  % Store local pointer to table defining blocks of trials
  P.tab = ARCADE_BLOCK_SELECTION_GLOBAL.tab ;
  
    % Task-specific validity tests on block definition table
    P.tab = tabvalchk( P.tab ) ;
  
  % Handle to session's behavioural store object
  P.bhv = SGLBehaviouralStore.launch ;
  
  % Define state names, column of cells
  P.nam = { 'Start' , 'HoldFix' , 'Wait' , 'BarOn' , 'GetFix' , ...
    'Ignored' , 'Blink' , 'BrokenFix' , 'EyeTrackError' , 'Correct' , ...
      'cleanUp' }' ;
  
  % Event marker codes for each state
  [ P.evm , P.evh ] = event_marker( P.nam ) ;
  
  % Make copy of trial error name to value mapping
  P.err = ARCADE_BLOCK_SELECTION_GLOBAL.err ;
  
  % Open Win32 inter-process communication events
  for  E = { 'StimServerAnimationDone' }
    name = E{ 1 } ;
    P.( name ) = IPCEvent( name ) ;
  end
  
  % Get screen parameters
  P.framerate = double( round( StimServer.GetFrameRate ) ) ;
  P.screensize = double( StimServer.GetScreenSize ) ;
  
  % Calculate pixels per degree of visual field. cm/deg * pix/cm = pix/deg.
  P.pixperdeg = ( cfg.DistanceToScreen * tand( 1 ) )  *  ...
    ( sqrt( sum( P.screensize .^ 2 ) ) / cfg.MonitorDiagonalSize ) ;
  
  % Screen size in degrees
  P.screendegs = P.screensize ./ P.pixperdeg ;
  
  % Create flicker objects
  P.Flicker.stim = Rectangle ;
  P.Flicker.anim =   Flicker ;
  
    % Certain properties are fixed
    P.Flicker.stim.faceColor( : ) = double( intmax( 'uint8' ) ) ;
    P.Flicker.stim.width  = P.screensize( 1 ) ;
    P.Flicker.stim.height = P.screensize( 2 ) ;
  
  % Create target stimulus objects, a bit of trickery required to create an
  % empty Stimulus object for 'none'.
  P.Target.circle   = Circle ;
  P.Target.gaussian = Gaussian ;
  P.Target.none     = P.Target.gaussian( [ ] ) ;
    
  % Create gaze fixation stimulus
  P.Fix = Circle ;
  
    % Parameters are fixed
    P.Fix.position = [ 0 , 0 ] ;
    P.Fix.faceColor( : ) = 255 ;
    P.Fix.lineColor( : ) = 255 ;
    P.Fix.lineWidth = 1 ;
    P.Fix.drawMode = 3 ;
    P.Fix.diameter = 0.15 * P.pixperdeg ;
    
    % Fixation window tolerance. Use this to detect if the value has
    % changed beteween trials.
    P.FixTol = [ ] ;
  
  % Make tic time measurement at end of previous trial for ITI measure
  P.ITIstart = StateRuntimeVariable ;
  
  % Initialise ARCADE and Task connection to Synapse server on TDT HostPC
  P.syn = initsynapse( cfg , TdtHostPC , TdtExperiment , SpikeBuffer , ...
    MuaLfpBuffer ) ;
  
  % Create and initialise behaviour plots
  P.ofig = creatbehavfig( cfg , P.err , P.tab ) ;
  
% All subsequent trials
else
  
  % Retrieve persistent data
  P = persist ;
  
  %-- Update behaviour plots based on previous trial --%
  
    %- Behavioural outcome raster plot -%
    newdata = struct( 'pre_err', pre.trialError( end - 1 ), ...
      'pre_block', pre.blocks( end - 1 ), 'nex_block', pre.blocks( end ) );
    
    P.ofig.update( 'BehavRaster' , [ ] , newdata )
    
    %- Trial info panel -%
    newdata = struct( 'ind' , TrialData.currentTrial - [ 1 , 0 ] , ...
      'err' , pre.trialError( end - [ 1 , 0 ] ) , ...
      'con' , pre.conditions( end - [ 1 , 0 ] ) , ...
      'blk' , pre.blocks( end - [ 1 , 0 ] ) , ...
       'rt' , pre.reactionTime( end - [ 1 , 0 ] ) , ...
      'typ' , [ pre.userVariable{ end - 1 }.BlockType , ...
        ARCADE_BLOCK_SELECTION_GLOBAL.typ ] , ...
      'trials' , ARCADE_BLOCK_SELECTION_GLOBAL.count.trials , ...
      'total' , ARCADE_BLOCK_SELECTION_GLOBAL.count.total ) ;
    
    P.ofig.update( 'TrialInfo' , [ ] , newdata )
    
    %- Psychometric and reaction time curves -%
    for  F = { 'Psychometric' , 'Reaction Time' } , f = F{ 1 } ;
      
      % Construct graphics object group identifier
      id = sprintf( '%s Block %d' , ...
        f , pre.userVariable{ end - 1 }.BlockType ) ;
      
      % Information required to update plots
      index = struct( 'x' , ...
        P.tab.Contrast( P.tab.Condition == pre.conditions( end - 1 ) ) ,...
          'err' , pre.trialError( end - 1 ) ) ;
      newdata = pre.reactionTime( end - 1 ) ;
      
      % Update empirical data and find least-squares best fit
      P.ofig.update( id , index , newdata )
      P.ofig.fit( id )
      
    end % psych & RT curves
    
    %- Reaction time histogram -%
    
    % Construct group id
    id = sprintf( 'RT Block %d' , pre.userVariable{ end - 1 }.BlockType ) ;
    
    % Update histogram
    index = pre.reactionTime( end - 1 ) ;
    newdata = pre.trialError( end - 1 ) ;
    P.ofig.update( id , index , newdata )
    
    % Select groups for new block %
    if  diff( pre.blocks( end - [ 1 , 0 ] ) )
      id = sprintf( 'Block %d' , ARCADE_BLOCK_SELECTION_GLOBAL.typ ) ;
      P.ofig.select( 'set' , id )
    end
    
end % first trial init

%- Show changes to plots -%
drawnow


%%% CHECK WHETHER BAR MAPPING IS COMPLETE %%%

% We know this if the current block id is different on the previous and the
% current trials
if  TrialData.currentTrial > 1  &&  diff( pre.blocks( end - 1 : end ) )
  
  % Wait for user to examine online plot
  waitfor( ...
    msgbox( [ '\fontsize{14}Bar mapping is complete.' , newline , ...
                             'Please examine RF map.' , newline , ...
                            'Click OK when finished.' ] , ...
      'Bar Mapping' , 'none' , struct( 'WindowStyle' , 'non-modal' , ...
        'Interpreter' , 'tex' ) ) )
  
  % We will end the running ARCADE session
  requestQuitSession ;
  
  % Make a dummy trial with one state the ends immediately
  done = State( 'done' ) ;
  createTrial( 'done' , done ) ;
  
  % Run trial and end session
  return
  
end % bar mapping is complete


%%% Trial variables %%%

% Error check editable variables
v = evarchk( Reward , BarOriginDeg , TravelDiameterDeg , ...
  BarWidthHightDeg , BarSpeedDegPerSec , BarRGB , FixTolDeg , ...
    BaselineMs , RewardMinMs , ScreenGamma , ItiMinMs , TdtHostPC , ...
      TdtExperiment , LaserController , TdtChannels , SpikeBuffer , ...
        MuaLfpStartIndex , MuaBuffer , LfpBuffer , VisualLatencyMs , ...
          StimRespSim , SynthRfXywDeg ) ;

% Record pixels per degree, computed locally
v.pixperdeg = P.pixperdeg ;

% Add type of block
v.BlockType = ARCADE_BLOCK_SELECTION_GLOBAL.typ ;

% Convert variables with degrees into pixels, without destroying original
% value in degrees
for  F = { 'BarOriginDeg' , 'TravelDiameterDeg' , 'BarWidthHightDeg' , ...
    'BarSpeedDegPerSec' , 'FixTolDeg' , 'SynthRfXywDeg' } ; f = F{ 1 } ;
  
  vpix.( f ) = v.( f ) * P.pixperdeg ;
  
end % deg2pix

% Compute reward size for correct performance
rew = max( RewardMinMs , Reward ) ;
  
  % Store reward size
  v.Reward = rew ;

% Ask StimServer.exe to apply a measure of luminance Gamma correction
StimServer.InvertGammaCorrection( ScreenGamma ) ;


%%% Eye Tracking %%%

% Check to see if fixation point eye tracking window tolerence has changed
% since last trial, because editable variables were changed during task
% pause. Don't reset and rebuild windows if unnecessary because trackeye
% wastes 500ms on each reset (as of ARCADE v2.6).
if  P.FixTol ~= FixTolDeg

  % Delete any existing eye window
  trackeye( 'reset' ) ;

  % Create fixation and target eye windows
  trackeye( [ 0 , 0 ] , vpix.FixTolDeg , 'Fix' ) ;
  
  % Remember new value
  P.FixTol = FixTolDeg ;

end % update eye windows


%%% Stimulus configuration %%%

% Properties of current trial condition.
c = table2struct(  ...
      P.tab( TrialData.currentCondition == P.tab.Condition , : )  ) ;

% Reset flicker colour
P.Flicker.stim.faceColor( : ) = double( intmax( 'uint8' ) ) ;

% Determine screen background colour during Wait state
switch  c.WaitBackground
  case  'default' , WaitBak = { 'Background' ,   cfg.BackgroundRGB } ;
  case    'black' , WaitBak = { 'Background' , [ 000 , 000 , 000 ] } ;
  case      'red' , WaitBak = { 'Background' , [ 255 , 000 , 000 ] } ;
  otherwise
    
    % Attempt to read background contrast
    bakcon = regexp( c.WaitBackground , P.constrreg , 'tokens' , 'once' ) ;
    
    % Check for contrast
    if  ~ isempty( bakcon )
      
      % regexp returns { <string> }, convert string to numeric
      bakcon = str2double( bakcon{ 1 } ) ;
      
      % Convert from Michelson contrast into pixel delta
      bakcon = bakcon .* cfg.BackgroundRGB ;
      
      % Set background ...
      WaitBak = { 'Background' , max( 0 , cfg.BackgroundRGB - bakcon ) } ;
      
      % ... and flicker colours
      P.Flicker.stim.faceColor( : ) = ...
        min( double( intmax( 'uint8' ) ) , cfg.BackgroundRGB + bakcon ) ;
    
    % No recognisable contrast or valid background colour provided
    else , error( 'Unrecognised Wait background: %s', c.WaitBackground )
    end
    
end % background colour

% Background flicker
if  c.BackgroundFlickerHz
  
  % Determine number of frames per cycle. Divided by 2. One half of frames
  % ON, the other half, OFF.
  n = P.framerate  /  c.BackgroundFlickerHz  /  2 ;
  
  % There is a fractional component, so round up to next whole frame
  if  mod( n , 1 ) , n = ceil( n ) ; end
  
  % Set flicker animation object parameters
  P.Flicker.anim.SetFrames( n , n ) ;
  
  % Bind animation to background rectangle
  P.Flicker.stim.play_animation( P.Flicker.anim ) ;
  
  % Point to background rectangle
  BackFlic = P.Flicker.stim ;
  
  % Enable fixation point mask
  FixMask = P.FixMask ;
  
% No background flicker , point to empty stimulus and fix point mask
else , BackFlic = P.Target.none ; FixMask = P.Target.none ;
end


%%% DEFINE TASK STATES %%%

% Special actions executed when state is finished executing. Remember to
% make this a column vector of cells.

  % Pause briefly to allow the first couple of FIXUPDATE events to stream
  % from EyeLink to EyeLinkServer, which then needs time to adjust Win32
  % events pertaining to target windows
  ENDACT.GetSaccadeTarget = { @( ) sleep( 75 ) } ;

  % Correct state. Calculate reaction time, convert unit from seconds to
  % milliseconds. Report RT.
  ENDACT.Correct = ...
    { @( ) reactiontime( 'writeRT' , 1e3 * ( P.RTend.get_value( ) - ...
             P.RTstart.get_value( ) ) ) ;
      @( ) EchoServer.Write( '%8sRT %dms\n' , '' , ...
             ceil( P.bhv.reactionTime( P.bhv.currentTrial ) ) ) } ;
  
  % cleanUp measures time that inter-trial-interval starts, then prints one
  % final message to show that all State objects have finished executing
  % and that control is returning to ARCADE's inter-trial code.
  ENDACT.cleanUp = ...
    { @( ) P.ITIstart.set_value( tic ) ;
      @( ) EchoServer.Write( 'End trial %d\n' , TrialData.currentTrial ) };

% Special constants for value of max reps
MAXREP_DEFAULT = 2 ;
MAXREP_GETFIX  = 100 ;

% Table of states. Each row defines a state. Column order is: state name;
% timeout duration; next state after timeout or max repetitions; wait event
% list; next state(s) after wait event(s), latter two are string or cell of
% strings; cell array of additional Name/Value input args for onEntry
% actions. For onEntry args, the State, State event marker, trial error
% code, and time zero state handle are automatically generated; only
% include additional args.
STATE_TABLE = ...
{           'Start' , 5000 , 'Ignored'        ,     'FixIn' , 'HoldFix' , { 'Stim' , { P.Fix } , 'StimProp' , { P.Fix , 'faceColor' , [ 000 , 000 , 000 ] } , 'Photodiode' , 'off' , 'Reset' , P.Waiting } ;
          'HoldFix' ,  300 , 'Wait'           ,    'FixOut' , 'GetFix' , { 'StimProp' , { P.Fix , 'faceColor' , [ 255 , 255 , 255 ] } } ;
             'Wait' ,WaitMs, 'TargetOn'       ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , [ { 'Reset' , [ P.StartSacc , P.EndSacc , P.BlinkStart , P.BlinkEnd , P.FalseAlarmFlag ] , 'Trigger' , P.Waiting , 'Photodiode' , 'on' , 'Stim' , { FixMask , BackFlic } } , WaitBak ] ;
     'BarOn' ,ReacTimeMinMs, 'ResponseWindow' ,  { 'FixOut' , 'StartSacc' } , { 'BrokenFix' , 'FalseAlarmSaccade' } , { 'Stim' , { Target } , 'Photodiode' , 'off' , 'RunTimeVal' , P.RTstart } ;
           'GetFix' , 5000 , 'Ignored'        ,     'FixIn' , 'HoldFix' , { 'StimProp' , { P.Fix , 'faceColor' , [ 000 , 000 , 000 ] } } ;
          'Ignored' ,    0 , 'cleanUp'        , {} , {} , {} ;
            'Blink' , 5000 , 'cleanUp'        , 'BlinkEnd' , 'cleanUp' , {} ;
        'BrokenFix' ,    0 , 'cleanUp'        , {} , {} , {} ;
    'EyeTrackError' ,    0 , 'cleanUp'        , {} , {} , {} ; 
          'Correct' ,    0 , 'cleanUp'        , {} , {} , { 'Reward' , v.Reward_Correct } ;
          'cleanUp' ,    0 , 'final'          , {} , {} , { 'Photodiode' , 'off' , 'Background' , cfg.BackgroundRGB , 'Stim' , { P.ItiStim.current } , 'StimProp' , { P.Fix , 'visible' , false , Target , 'visible' , false , BackFlic , 'visible' , false , FixMask , 'visible' , false } } ;
} ;

% Error check first trial, make sure that there is an event marker for
% each state name
if  TrialData.currentTrial == 1 && ~isequal( P.nam , STATE_TABLE( : , 1 ) )
    
  error( 'Mismatched event and state names' )
  
end % state name check


%%% MAKE ARCADE STATES %%%

% State table rows
for  row = 1 : size( STATE_TABLE , 1 )
  
  % Map table entry to meaningful names
  [ name , timeout , tout_next , waitev , wait_next , entarg ] = ...
    STATE_TABLE{ row , : } ;
  
  % Create new state
  states.( name ) = State( name ) ;
  
  % Set timeout duration, max number executions, and next state after
  % timeout or max reps. Max reps = 2 so that no inf loops, and don't trig
  % wrong state.
  states.( name ).duration                     =        timeout ;
  states.( name ).maxRepetitions               = MAXREP_DEFAULT ;
  states.( name ).nextStateAfterTimeout        =      tout_next ;
  states.( name ).nextStateAfterMaxRepetitions =      tout_next ;
  states.( name ).waitEvents                   =         waitev ;
  states.( name ).nextStateAfterEvent          =      wait_next ;
  
  % Issue a trial error code if this is an end state i.e. it transitions to
  % cleanUp. Default empty.
  TrialError = { } ;
  if  strcmp( tout_next , 'cleanUp' )
    TrialError = { 'TrialError' , P.err.( name ) } ;
  end
  
  % Default Name/Value pairs for onEntry input argument constructor. Append
  % additional pairs for this state.
  entarg = [ entarg , TrialError , { 'State' , states.( name ) , ...
    'Marker_entry' , P.evm.( [ name , '_entry' ] ) , ...
      'Marker_start' , P.evm.( [ name , '_start' ] ) , ...
        'TimeZero' , states.Start } ] ;
  
  % onEntry input arg struct
  a = onEntry_args( entarg{ : } ) ;
  
  % Define state's onEntry actions
  states.( name ).onEntry = { @( ) onEntry_generic( a ) } ;
  
  % onExit marker values
  states.( name ).onExit = P.evh.( name ) ;
  
end % rows

% States with special action after having executed
for  F = fieldnames( ENDACT )' , name = F{ 1 } ;
  
  % Insert additional actions between event marker triggers
  states.( name ).onExit = [ states.( name ).onExit( 1 ) ;
                                         ENDACT.( name ) ;
                             states.( name ).onExit( 2 ) ] ;
  
end % special onExit actions

% Only GetFix has different Max repetitions
states.GetFix.maxRepetitions = MAXREP_GETFIX ;


%%% Update script's persistent and user variables %%%

persist( P )
storeUserVariables( v )


%%% CREATE TRIAL %%%

states = struct2cell( states ) ;
createTrial( 'Start' , states{ : } )

% Output to message log
EchoServer.Write( [ '\n%s Start trial %d, cond %d, block %d(%d)\n' , ...
  '%9sWait %dms = %d + %d\n' ] , datestr( now , 'HH:MM:SS' ) , ...
    TrialData.currentTrial , TrialData.currentCondition , ...
      TrialData.currentBlock , v.BlockType , '' , ceil( WaitMs ) , ...
        ceil( BaselineMs ) , ceil( v.WaitMs ) )


%%% Complete previous trial's inter-trial-interval %%%

sleep( ItiMinMs  -  1e3 * toc( P.ITIstart.value ) )

% Destroy any ITI stimulus and set previous to empty, in case the current
% trial has no ITI stimulus
if  ~ isempty( P.ItiStim.previous )
  delete( P.ItiStim.previous )
  P.ItiStim.previous = [ ] ;
end


%%% --- SCRIPT FUNCTIONS --- %%%

% Maintain local persistent data
function  pout = persist( pin )
  
  persistent  p
  
  if  nargin  ,  p = pin ; end
  if  nargout , pout = p ; end
  
end % persist


% Task-specific checks on the validity of trial_condition_table.csv
function  tab = tabvalchk( tab , cstrreg )
  
  % Required columns, the set of column headers
  colnam = { 'DirectionDeg' } ;
  
  % Numerical type check
  fnumchk = @( c ) isnumeric( c ) && isreal( c ) && all( isfinite( c ) ) ;
  
  % Numeric support check
  fnumsup = @( val , sup ) val >= sup( 1 ) | val <= sup( 2 ) ;
  
  % String support check
  fstrsup = @( str , sup ) ismember( str , sup ) ;
  
  % Support error strings, for numbers and cell/string arrays
  fnumerr = @( sup ) sprintf( '[%.1f,%.1f]' , sup ) ;
  fstrerr = @( sup ) [ '{''' , strjoin( sup , ''',''' ) , '''}' ] ;
  
  % Contrast string support, allow values between 0 and 1, where contrast
  % strings are provided.
  fconsup = @( c ) fnumsup( str2double( cellfun( @( c ) [ c{ : } ] , ...
    regexp( c , cstrreg , 'tokens' , 'once' ) , ...
      'UniformOutput' , false ) ) , [ 0 , 1 ] ) ;
  
  % Error checking for each column. Return true if column's type is valid.
  valid.DirectionDeg = fnumchk ;
  
  % Support, what values are valid for each column?
  sup.DirectionDeg = [ 0 , 360 ] ;
  
  % Support check function
  supchk.DirectionDeg = fnumsup ;
  
  % Define support error message
  superr.DirectionDeg = fnumerr( sup.DirectionDeg ) ;
  
  % Retrieve table's name
  tabnam = tab.Properties.UserData ;
  
  % Check that all required columns are present
  if  ~ all( ismember( colnam , tab.Properties.VariableNames ) )
    
    error( '%s must contain columns: %s' , ...
      tabnam , strjoin( colnam , ' , ' ) )
    
  end % all columns found
  
  % Column names, point to values
  for  C = colnam , c = C{ 1 } ; v = tab.( c ) ;
    
    % Format error string header
    errstr = sprintf( 'Column %s of %s' , c , tabnam ) ;
    
    % Check if column has correct type
    if  ~ valid.( c )( v )
      
      error( '%s has invalid type, violating %s' , ...
        errstr , func2str( valid.( c ) ) )
      
    % Support is cell array of string
    elseif  iscellstr( sup.( c ) )
      
      % Get lower-case version of column's strings
      v = lower( v ) ;
      
      % Assign these back into the table, returned in output argument
      tab.( c ) = v ;
      
    end % error check
    
    % Values are out of range
    if  ~ all( supchk.( c )( v , sup.( c ) ) )

      error( '%s not in set %s' , errstr , superr.( c ) )

    end % range check
    
  end % cols
end % tabvalchk


% Convert Weber contrast value c to RGB I relative to background RGB Ib.
% Reminder, Weber contrast = ( I - Ib ) / Ib where I is target luminance
% and Ib is background luminance.
function  I = Weber( c , Ib )

  % Compute 'luminance', assuming greyscale background and target
  I = Ib .* ( c + 1 ) ;
  
  % 'Hack' solution for training on black or red backgrounds. Scale zero-
  % valued RGB components from 0 to 255 by c.
  I( Ib == 0 ) = c * double( intmax( 'uint8' ) ) ;
  
  % Guarantee that we don't exceed numeric range
  I = max( I , 0 ) ;
  I = min( I , double( intmax( 'uint8' ) ) ) ;
  
end % Weber


% Sample target location and size. Update editable variables. Input args
% include task script persistent variables and current value of editable
% variables.
function  [ v , RfXDeg , RfYDeg , RfRadDeg ] = newtarget( P , v )
  
  % Safeguard against infinite loop
  counter = 0 ;
  
  % Half of screen size in degrees
  hdegs = P.screendegs ./ 2 ;
  
  % Sample appropriate target location
  while  counter < 1e4
    
    % Generate cartesian coordinate in degrees from fixation point
    xy = P.screendegs .* rand( 1 , 2 )  -  hdegs ;
    
    % Round to nearest hundredth
    xy = round( xy , 2 ) ;
    
    % Eccentricity of point
    ecc = sqrt( sum( xy .^ 2 ) ) ;
    
    % RF centre radius, according to linear fit from Cavanaugh, Bair,
    % Movshon. 2002. J Neurophys. 88:2530-2546.
    rad = ( 0.0456 * ecc + 0.997 ) / 2 ;
    
    % Round to nearest hundreth
    rad = round( rad , 2 ) ;
    
    % Sampled RF centre must be a full RF radius away from fixation window
    % and also a full RF radius away from monitor edges. If not then
    % resample target location.
    if  ecc >= v.FixTolDeg + rad  &&  all( rad <= hdegs - abs( xy ) )
      break
    end
    
  end % sample targ location
  
  % Assign values
  v.RfXDeg = xy( 1 ) ;  v.RfYDeg = xy( 2 ) ;  v.RfRadDeg = rad ;
  
  % Re-assign workspace variables of same name
    RfXDeg = v.RfXDeg   ;
    RfYDeg = v.RfYDeg   ;
  RfRadDeg = v.RfRadDeg ;
  
  % Fetch ARCADE session behavioural store 
  BHVstore = SGLBehaviouralStore.launch ;
  
  % Editable variable names
  nam = BHVstore.cfg.EditableVariables( : , 1 ) ;
  
  % Editable variables to update
  for  E = { 'RfXDeg' , 'RfYDeg' , 'RfRadDeg' } , e = E{ 1 } ;
    
    % Find location in table
    i = strcmp( nam , e ) ;
    
    % Update value
    BHVstore.cfg.EditableVariables{ i , 2 } = num2str( v.( e ) ) ;
    
  end % editable variables
  
end % newtarget


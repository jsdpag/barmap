
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
% The photodiode square flips from white to black on the frame when the bar
% appears. It reverts to white on the moment the bar has completed its
% sweep. Hence, the photodiode square is white unless the bar is moving.
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

% Error check editable variables
v = evarchk( Reward , BarOriginDeg , TravelDiameterDeg , ...
  BarWidthHightDeg , BarSpeedDegPerSec , BarRGB , FixTolDeg , ...
    BaselineMs , RewardMinMs , ScreenGamma , ItiMinMs , TdtHostPC , ...
      TdtExperiment , LaserCtrl , TdtChannels , SpikeBuffer , ...
        MuaStartIndex , MuaBuffer , VisualLatencyMs , StimRespSim , ...
          SynthRfXywDeg ) ;

% Retrieve persistent data
P = persist ;


%%% FIRST TRIAL INITIALISATION -- PERSISTENT DATA %%%

if  TrialData.currentTrial == 1
  
  % Extra toolboxes required by this task
  PATHS = { 'TDTMatlabSDK' , 'mak' , 'tdt-windowed-buffering' } ;
  GENPAT = { 'TDTMatlabSDK' } ;

  % Toolboxes , get absolute path
  for  TB = PATHS , tb = [ 'C:\Toolbox\' , TB{ 1 } ] ;
    
    % Cannot find Toolbox, report error to user
    if  ~ exist( tb , 'dir' ), error( 'Cannot find Toolbox: %s' , tb ), end
    
    % Expand recursively into toolbox sub-directories
    if  any( strcmp( TB{ 1 } , GENPAT ) ) , tb = genpath( tb ) ; end
    
    % Add to path
    addpath( tb )
    
  end % toolboxes
  
  % Store local pointer to table defining blocks of trials
  P.tab = ARCADE_BLOCK_SELECTION_GLOBAL.tab ;
  
    % Task-specific validity tests on block definition table
    P.tab = tabvalchk( P.tab ) ;
  
  % Define state names, column of cells
  P.nam = { 'Start' , 'HoldFix' , 'Wait' , 'BarOn' , 'GetFix' , ...
    'Ignored' , 'Blink' , 'BrokenFix' , 'Correct' , 'cleanUp' }' ;
  
  % Event marker codes for each state
  [ P.evm , P.evh ] = event_marker( P.nam ) ;
  
  % Make copy of trial error name to value mapping
  P.err = ARCADE_BLOCK_SELECTION_GLOBAL.err ;
  
  % Open Win32 inter-process communication events
  for  E = { 'StimServerAnimationDone' , 'BlinkStart' , 'BlinkEnd' }
    name = E{ 1 } ;
    P.( name ) = IPCEvent( name ) ;
  end
  
  % Get screen parameters
  P.framerate = double( round( StimServer.GetFrameRate ) ) ;
  P.screensize = double( StimServer.GetScreenSize ) ;
  
  % Calculate pixels per degree of visual field. cm/deg * pix/cm = pix/deg.
  P.pixperdeg = ( cfg.DistanceToScreen * tand( 1 ) )  *  ...
    ( sqrt( sum( P.screensize .^ 2 ) ) / cfg.MonitorDiagonalSize ) ;
  
    % Rectify this wrong
    cfg.PixelsPerDegree = P.pixperdeg ;
  
  % Screen size in degrees
  P.screendegs = P.screensize ./ P.pixperdeg ;
  
  % Create white bar visual stimulus object and set fixed properties
  P.Bar = Rectangle ;
  
    P.Bar.width  = BarWidthHightDeg( 1 ) .* P.pixperdeg ;
    P.Bar.height = BarWidthHightDeg( 2 ) .* P.pixperdeg ;
    P.Bar.faceColor( : ) = BarRGB ;
    P.Bar.drawMode = 1 ;
    P.Bar.visible = 0 ;
  
  % Create linear motion object for the bar and set fixed properties
  P.Motion = LinearMotion( BarSpeedDegPerSec .* P.pixperdeg , [0 0 0 0] ) ;
  
    P.Motion.terminalAction = '00001101' ;
    
  % Create gaze fixation stimulus
  P.Fix = Circle ;
  
    % Parameters are fixed
    P.Fix.position = [ 0 , 0 ] ;
    P.Fix.faceColor( : ) = 2 ^ 8 - 1 ;
    P.Fix.lineColor( : ) = 2 ^ 8 - 1 ;
    P.Fix.lineWidth = 1 ;
    P.Fix.drawMode = 3 ;
    P.Fix.diameter = 0.15 * P.pixperdeg ;
    
    % Fixation window tolerance. Use this to detect if the value has
    % changed beteween trials. Initialisation value guarantees that new
    % fixation window will be made on first trial.
    P.FixTol = NaN ;
  
  % Make tic time measurement at end of previous trial for ITI measure
  P.ITIstart = StateRuntimeVariable ;
  
    % Initialise P.ITIstart to zero, so that we don't wait on first trial
    P.ITIstart.value = zeros( 1 , 'uint64' ) ;
  
  % Ideal duration of one sweep by the bar, in milliseconds
  P.sweeptime = TravelDiameterDeg ./ BarSpeedDegPerSec .* 1e3 ;
  
  % Extra time that we add to bar sweep when computing state durations and
  % buffer sizes. Unit in milliseconds. Accounts for variability in exact
  % bar + motion onset due to temporal granularity of monitor refresh rate.
  P.extratime = 6 ./ P.framerate .* 1e3 ; % frames
  
  % Initialise connection to Synapse server on TDT HostPC
  P.syn = initsynapse( cfg , P.tab , P.evm , P.err , TdtHostPC , ...
    TdtExperiment , LaserCtrl , SpikeBuffer , MuaBuffer , StimRespSim ) ;
  
    % Create a logical flag that is raised when synapse is in use
    P.UsingSynapse = ~ isempty( P.syn ) ;
    
  % Set up SynapseAPI environment if available
  if  P.UsingSynapse
    
    % Create a LaserController MATLAB object for setting parameter values of
    % the named LaserController Gizmo
    P.laserctrl = LaserController( P.syn , LaserCtrl ) ;

      % Set fixed parameters for remainder of bar mapping session
      P.laserctrl.EventIntOn = P.evm.BarOn_entry ;
      P.laserctrl.EventIntReset = P.evm.cleanUp_entry ;
      P.laserctrl.EventIntRstOpt = P.evm.BarOn_end ;
      P.laserctrl.UseLaser = false ;
      P.laserctrl.UsePhotodiode = true ;
      P.laserctrl.PhotodiodeThreshold = 0.67 ;
      P.laserctrl.PhotodiodeDirectionStr = 'falling' ;
      P.laserctrl.PhotodiodeTimeLow = 4 ;
      P.laserctrl.Enablemanual = false ;

    % Create triggered buffer MATLAB objects
    P.buf.spk = TdtWinBuf( P.syn , SpikeBuffer ) ;
    P.buf.mua = TdtWinBuf( P.syn ,   MuaBuffer ) ;

      %- Set fixed buffer parameters -%

      % Buffer size grabs baseline waiting period + expected time to
      % complete one sweep of the bar. Plus a few frames of the stimulus
      % monitor. And also expected visual latency.
      secs = ...
        ( BaselineMs + VisualLatencyMs + P.sweeptime + P.extratime ) / 1e3;

      % For spike buffer, assume no unit will generate above 1000spk/sec.
      P.buf.spk.setbufsiz( secs , 1000 ) ;
      P.buf.mua.setbufsiz( secs ) ;

      % Response window contains only visual latency plus bar sweep time
      % and half the extra time.
      secs = ( VisualLatencyMs + P.sweeptime + P.extratime / 2 ) / 1e3 ;

      % Again, assume no spike rate above 1000spk/sec
      P.buf.spk.setrespwin( secs , 1000 ) ;
      P.buf.mua.setrespwin( secs ) ;

      % Minimum number of channels
      minchan = ...
        min( [ P.buf.spk.maxchan , P.buf.mua.maxchan , TdtChannels ] ) ;
      
      % Maximum number of channels to return following each buffer read
      P.buf.spk.setchsubsel( minchan ) ;
      P.buf.mua.setchsubsel( minchan ) ;

      % Crop buffered data in specified time window around trigger event.
      % Include a few extra milliseconds so that MUA interpolation by
      % onlinefigure does not return NaN.
      secs = [ -BaselineMs - 5 , VisualLatencyMs + P.sweeptime + 5 ] / 1e3;
      P.buf.spk.settimewin( secs ) ;
      P.buf.mua.settimewin( secs ) ;

    % Simulated ephys signal modulation via FB128 Sync line is enabled
    P.simresp = ~ strcmpi( StimRespSim , 'none' ) ;

      % Set up StimRespSim Gizmo
      if  P.simresp

        % Try to enable the FB128 sync line
        iset( P.syn , StimRespSim , 'Enable' , 1 )

        % Duration of response to bar is the time that it takes for the bar
        % to sweep across the RF, in milliseconds
        iset( P.syn , StimRespSim , 'ResponseMs' , ...
          SynthRfXywDeg( 3 ) / BarSpeedDegPerSec * 1e3 )

      else

        % Try to disable the FB128 sync line
        iset( P.syn , StimRespSim , 'Enable' , 0 )

      end % set StimRespSim Giz

    % Create and initialise receptive field plots
    P.ofig = creatRFfig( cfg , v , P.tab , minchan ) ;
  
  % Not using SynapseAPI, set default values
  else
    
    P.simresp = false ;
    
  end % synapse api actions
  
% All subsequent trials, if SynapseAPI enabled and the previous trial ended
% as 'Correct'
elseif  P.UsingSynapse  &&  pre.trialError( end - 1 ) == P.err.Correct
  
  % Grab the buffered data
  P.buf.spk.getdata( ) ;
  P.buf.mua.getdata( ) ;
  
  % Previous trial's condition
  pcon = pre.conditions( end - 1 ) ;
  
  % Properties of previous trial
  c = P.tab( pcon == P.tab.Condition , : ) ;
  c = table2struct( c ) ;
  
  % Build struct with buffered data from previous trial
  new.spk.time = P.buf.spk.time * 1e3 ;  new.spk.data = P.buf.spk.data ;
  new.mua.time = P.buf.mua.time * 1e3 ;  new.mua.data = P.buf.mua.data ;
  
  % Update RF map
  P.ofig.update( 'rfmap' , c.DirectionDeg , new )
    
end % trial init

%- Show changes to plots -%
drawnow


%%% CHECK WHETHER BAR MAPPING IS COMPLETE %%%

% We know this if the current block id is different on the previous and the
% current trials
if  TrialData.currentTrial > 1  &&  diff( pre.blocks( end - 1 : end ) )
  
  % Synapse in use
  if  P.UsingSynapse
    
    % Wait for user to examine online plot
    waitforuser( 'Bar Mapping' , 14 , ...
      'Bar mapping is complete.\nPlease examine RF map.' )
    
    % Session footer
    ftr = [ 'End session ' , cfg.sessionName ] ;

    % Send header to Synapse server
    if  ~ P.syn.setParameterValue( 'RecordingNotes' , 'Note' , ftr )
      error( 'Failed to send session footer to Synapse.' )
    end
    
    % Drop out of run-time mode to Idle
    if  ~ strcmp( P.syn.getModeStr , 'Idle' )  &&  ...
        ~ P.syn.setModeStr( 'Idle' )
      warning( 'Failed to set Synapse mode to ''Idle''' )
    end
  
    % Explicitly release resources
    delete( P.laserctrl ) , delete( P.buf.spk ) , delete( P.buf.mua )
    delete( P.syn )
  
  end % synapse
  
  % Explicitly release resources
  for  E = { 'StimServerAnimationDone' , 'BlinkStart' , 'BlinkEnd' , ...
      'Bar' , 'Fix' , 'Motion' , 'ITIstart' }
    delete( P.( E{ 1 } ) ) ;
  end
  
  % We will end the running ARCADE session
  requestQuitSession ;
  
  % Make a dummy trial with one state the ends immediately
  done = State( 'done' ) ;
  createTrial( 'done' , done ) ;
  
  % Run trial and end session
  return
  
end % bar mapping is complete


%%% Trial variables %%%

% Record pixels per degree, computed locally
v.pixperdeg = P.pixperdeg ;

% Add type of block
v.BlockType = ARCADE_BLOCK_SELECTION_GLOBAL.typ ;

% Convert variables with degrees into pixels, without destroying original
% value in degrees
for  F = { 'BarOriginDeg' , 'TravelDiameterDeg' , 'FixTolDeg' , ...
    'SynthRfXywDeg' } ; f = F{ 1 } ;
  
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
c = P.tab( TrialData.currentCondition == P.tab.Condition , : ) ;
c = table2struct( c ) ;

% Bar orientation
P.Bar.angle = c.DirectionDeg ;

% Reset linear motion
P.Bar.play_animation( P.Motion ) ;

% Create unit direction vectors. First points to bar's starting position.
% Second points to end position.
P.Motion.vertices( 1 ) = - cosd( c.DirectionDeg ) ;
P.Motion.vertices( 2 ) = - sind( c.DirectionDeg ) ;
P.Motion.vertices( 3 ) = + cosd( c.DirectionDeg ) ;
P.Motion.vertices( 4 ) = + sind( c.DirectionDeg ) ;

% Scale direction vectors by half of the travel distance
P.Motion.vertices = vpix.TravelDiameterDeg / 2  *  P.Motion.vertices ;

% Centre bar's motion onto the bar origin
P.Motion.vertices = P.Motion.vertices  +  vpix.BarOriginDeg([1 2 1 2]) ;


%%% Simulated responses with FB128 %%%

% Simulation mode is enabled
if  P.simresp
  
  % Determine the vector from starting point of the bar to the centre of
  % the simulated RF
  vsim = SynthRfXywDeg( 1 : 2 ) - P.Motion.vertices( 1 : 2 ) / P.pixperdeg;
  
  % Project this onto the unit direction vector of the current trial
  vsim = vsim * [ cosd( c.DirectionDeg ) ;
                  sind( c.DirectionDeg ) ] ;
	
	% Compute the time it takes for the bar to reach the edge of the RF, plus
	% visual latency. In milliseconds.
  iset( P.syn , StimRespSim , 'LatencyMs' , ...
    vsim / BarSpeedDegPerSec * 1e3  +  VisualLatencyMs )
  
end % simulation


%%% DEFINE TASK STATES %%%

% Special actions executed when state is finished executing. Remember to
% make this a column vector of cells.
  
  % Guarantee that bar motion animation is stopped
  ENDACT.BarOn = { @( ) P.Bar.stop_animation( ) } ;
  
  % cleanUp measures time that inter-trial-interval starts, then prints one
  % final message to show that all State objects have finished executing
  % and that control is returning to ARCADE's inter-trial code.
  ENDACT.cleanUp = ...
    { @( ) P.ITIstart.set_value( tic ) ;
      @( ) EchoServer.Write( 'End trial %d\n' , TrialData.currentTrial ) };
    
    % SynapseAPI is live, send run-time note about end of trial
    if  P.UsingSynapse
      ENDACT.cleanUp{ end + 1 } = @( ) iset( P.syn , 'RecordingNotes' , ...
        'Note' , sprintf( 'End trial %d\n' , TrialData.currentTrial ) ) ;
    end

% Special constants for value of max reps
MAXREP_DEFAULT = 2 ;
MAXREP_GETFIX  = 100 ;

% BarOn timout is the ideal sweep time plus several frames
BarTime = P.sweeptime  +  P.extratime ;

% Table of states. Each row defines a state. Column order is: state name;
% timeout duration; next state after timeout or max repetitions; wait event
% list; next state(s) after wait event(s), latter two are string or cell of
% strings; cell array of additional Name/Value input args for onEntry
% actions. For onEntry args, the State, State event marker, trial error
% code, and time zero state handle are automatically generated; only
% include additional args.
STATE_TABLE = ...
{       'Start' ,     5000 , 'Ignored' ,  'FixIn' , 'HoldFix' , { 'Stim' , { P.Fix } , 'StimProp' , { P.Fix , 'faceColor' , [ 000 , 000 , 000 ] , P.Fix , 'lineColor' , [ 255 , 255 , 255 ] } , 'Photodiode' , 'on' , 'Reset' , P.StimServerAnimationDone } ;
      'HoldFix' ,      300 , 'Wait'    ,  { 'FixOut' , 'BlinkStart' } , { 'GetFix' , 'Blink' } , { 'StimProp' , { P.Fix , 'faceColor' , [ 255 , 255 , 255 ] , P.Fix , 'lineColor' , [ 000 , 000 , 000 ] } , 'Reset' , [ P.BlinkStart , P.BlinkEnd ] } ;
         'Wait' ,BaselineMs, 'BarOn'   ,  { 'FixOut' , 'BlinkStart' } , { 'BrokenFix' , 'Blink' } , {} ;
        'BarOn' ,   BarTime, 'Correct' ,  { 'FixOut' , 'BlinkStart' , 'StimServerAnimationDone' } , { 'BrokenFix' , 'Blink' , 'Correct' } , { 'Stim' , { P.Bar } , 'Photodiode' , 'off' } ;
       'GetFix' ,     5000 , 'Ignored' ,  'FixIn' , 'HoldFix' , { 'StimProp' , { P.Fix , 'faceColor' , [ 000 , 000 , 000 ] , P.Fix , 'lineColor' , [ 255 , 255 , 255 ] } } ;
      'Ignored' ,        0 , 'cleanUp' , {} , {} , {} ;
        'Blink' ,     5000 , 'cleanUp' , 'BlinkEnd' , 'cleanUp' , {} ;
    'BrokenFix' ,        0 , 'cleanUp' , {} , {} , {} ;
      'Correct' ,        0 , 'cleanUp' , {} , {} , { 'Reward' , rew } ;
      'cleanUp' ,        0 , 'final'   , {} , {} , { 'Photodiode' , 'on' , 'StimProp' , { P.Fix , 'visible' , false , P.Bar , 'visible' , false } } ;
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
  
  % Default value, no SynapseAPI object is available
  a.synflg = P.UsingSynapse ;
  
  % SynapseAPI is not empty, so add pointer to this in the arg struct
  if  P.UsingSynapse , a.syn = P.syn ; end
  
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
  'Direction %d deg (%d/%d)\n' ] , datestr( now , 'HH:MM:SS' ) , ...
    TrialData.currentTrial , TrialData.currentCondition , ...
      TrialData.currentBlock , v.BlockType , c.DirectionDeg , ...
        ARCADE_BLOCK_SELECTION_GLOBAL.count.trials , ...
          ARCADE_BLOCK_SELECTION_GLOBAL.count.total )

% Synapse is running
if  P.UsingSynapse
  
  % Trial header
  hdr = sprintf( [ 'Start trial %d\nCondition %d\nBlock %d\n' , ...
    'Block type %d\nMotion direction deg %d\nReward ms %d' ] , ...
      TrialData.currentTrial , TrialData.currentCondition , ...
        TrialData.currentBlock , v.BlockType , c.DirectionDeg , rew ) ;

  % Send header to Synapse server
  if  ~ P.syn.setParameterValue( 'RecordingNotes' , 'Note' , hdr )
    error( 'Failed to send trial header to Synapse.' )
  end
  
  % Resume cyclical buffering of ephys signals
  P.buf.spk.startbuff( ) ; P.buf.mua.startbuff( ) ;
  
end % synapse running


%%% Complete previous trial's inter-trial-interval %%%

sleep( ItiMinMs  -  1e3 * toc( P.ITIstart.value ) )


%%% --- SCRIPT FUNCTIONS --- %%%

% Maintain local persistent data
function  pout = persist( pin )
  
  persistent  p
  
  % First use
  if  isempty( p ) , p = struct ; end
  
  if  nargin  ,  p = pin ; end
  if  nargout , pout = p ; end
  
end % persist


% Task-specific checks on the validity of trial_condition_table.csv
function  tab = tabvalchk( tab )
  
  % Required columns, the set of column headers
  colnam = { 'DirectionDeg' } ;
  
  % Numerical type check
  fnumchk = @( c ) isnumeric( c ) && isreal( c ) && all( isfinite( c ) ) ;
  
  % Numeric support check
  fnumsup = @( val , sup ) val >= sup( 1 ) | val <= sup( 2 ) ;
  
  % Support error strings, for numbers and cell/string arrays
  fnumerr = @( sup ) sprintf( '[%.1f,%.1f]' , sup ) ;
  
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


% Try to send information from SynapseAPI object. Raise error on failure.
% Scalar parameters, only.
function  iset( syn , giz , par , val )
  
  % Try to set value of Gizmo parameter
  if  ~ syn.setParameterValue( giz , par , val )
    
    % Throw a simple, reader-friendly error message.
    error( [ 'Failed to set parameter %s of Gizmo %s through ' , ...
      'Synapse server on Host: %s' ] , par , giz , syn.SERVER )
    
  end % failed to set
  
end % iset


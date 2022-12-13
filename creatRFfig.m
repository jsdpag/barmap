
function  ofig = creatRFfig( cfg , evar , tab , minchan )
% 
% ofig = creatRFfig( cfg , evar , tab , minchan )
% 
% Create and initialise receptive field plots. Called by task script. cfg
% is the ArcadeConfig object of the current session. evar is a struct
% containing all editable variables. tab is a Table object containing
% processed version of trial_condition_table.csv, which defines all trial
% conditions and groups them into blocks of trials. Returns an onlinefigure
% object. Create plots before running the first trial.
% 
  
  
  %%% CONSTANTS %%%
  
  % Number of channels
  C.N.chan = minchan ;
  
  % Unique motion directions
  C.dir = unique( tab.DirectionDeg ) ;
  
  % Number of directions
  C.N.dir = numel( C.dir ) ;
  
  % Complete milliseconds per sweep of the bar
  C.N.msperbar = ...
    floor( evar.TravelDiameterDeg / evar.BarSpeedDegPerSec * 1e3 ) ;
  
  % Calculate millisecond time bins that range from start of baseline to
  % end of one bar sweep plus visual latency
  C.time = - evar.BaselineMs : + evar.VisualLatencyMs + C.N.msperbar ;
  
    % Column vector
    C.time = C.time' ;
  
  % Number of time bins
  C.N.time = numel( C.time ) ;
  
  % Assumed visual latency, in milliseconds
  C.vislat = evar.VisualLatencyMs ;
  
  % Conversion factor, visual degrees per millisecond
  C.degperms = evar.BarSpeedDegPerSec / 1e3 ;
  
  % Number of complete spatial bins, one per millisecond of the bar sweep
  C.N.space = C.N.msperbar ;
  
  % Spatial bin width
  C.degperbin = C.degperms ;
  
  % Enumerate spatial bins along x and y axes, zeroed on fixation point
  C.x = C.degperbin * ( 0 : C.N.space - 1 ) + ...
    ( evar.BarOriginDeg( 1 ) - evar.TravelDiameterDeg / 2 ) ;
  C.y = C.degperbin * ( 0 : C.N.space - 1 ) + ...
    ( evar.BarOriginDeg( 2 ) - evar.TravelDiameterDeg / 2 ) ;
  
  % Index of millisecond time bins that will be mapped to visual space.
  % Invert for MATLAB shorthand X( i ) = [ ] to remove selected elements.
  C.i = ~ ( C.time > evar.VisualLatencyMs ) ;
  
  % Spike train convolution kernel with 20ms time constant, millisecond
  % time bins
  C.kern = exp( - ( 0 : 255 )' ./ 20 ) ;
  C.kern = C.kern ./ sum( C.kern ) ;
  
  
  %%% Create figure %%%
  
  % Determine the save name of the onlinefigure
  fnam = [ fullfile( cfg.filepaths.Behaviour, cfg.sessionName ) , '.fig' ];
  
  % Create onlinefigure object, it starts out being invisible
  ofig = onlinefigure( fnam , 'Tag' , 'Behaviour' , 'Visible' , 'off' ) ;
  
  % Point to figure handle
  fh = ofig.fig ;
  
  % Shape and ...
  fh.Position( 3 ) = ( 2 + 1/2 ) * ofig.fig.Position( 3 ) ; % width
  fh.Position( 4 ) = ( 1 + 000 ) * ofig.fig.Position( 4 ) ; % height
  
  % ... position the figure
  fh.Position( 1 : 2 ) = [ 1 , 31 ] ;
  
  
  %%% Create axes %%%
  
  % Spike train RF map
  ofig.subplot( 1 , 3 , 1 , 'Tag' , 'spkrf' ) ;
  
    axis square tight
    grid on
    title( 'Spike RF' )
    xlabel(   'Azimuth (deg)' )
    ylabel( 'Elevation (deg)' )
  
  % MUA RF map
  ofig.subplot( 1 , 3 , 2 , 'Tag' , 'muarf' ) ;
  
    axis square tight
    grid on
    title( 'MUA RF' )
    xlabel( 'Azimuth (deg)' )
  
  % Time series, average spike rate
  ofig.subplot( 2 , 3 , 3 , 'Tag' , 'spktime'  ) ;
  
    axis tight
    grid on
    ylabel( 'spk/sec' )
  
  % Time series, average MUA
  ofig.subplot( 2 , 3 , 6 , 'Tag' , 'muatime' ) ;
  
    axis tight
    grid on
    xlabel( 'Bar time (ms)' )
    ylabel( 'MUA' )
  
  
  %%% Create listbox channel selection control %%%
  
  lstbox = uicontrol( fh , 'Style' , 'listbox' , 'String' , ...
    arrayfun( @( i ) sprintf( '%d' , i ) , 1 : minchan , ...
      'UniformOutput' , false ) , 'Tag' , 'chansel' ) ;
  
  % Position box
  lstbox.Units = 'normalized' ;
  lstbox.Position( 1 ) = 1 - lstbox.Position( 1 ) - lstbox.Position( 3 ) ;
  lstbox.Position( 4 ) = 1 - 2 * lstbox.Position( 2 ) ;
  
  % Label the box
  lab = uicontrol( fh , 'Style' , 'text' , 'String' , 'Channel' ) ;
  lab.Units = 'normalized' ;
  lab.Position( 1 ) = lstbox.Position( 1 ) ;
  lab.Position( 2 ) = lstbox.Position( 2 ) + lstbox.Position( 4 ) ;
  
  
  %%% Colour name to RGB map %%%
  
  % Axes all have the same default ColorOrder set, point to one of them
  col = fh.Children( end ).ColorOrder ;
  
  % Define a struct mapping field names to corresponding RGB values
  col = struct( 'green' , col( 5 , : ) , ...
                 'blue' , col( 1 , : ) , ...
               'yellow' , col( 3 , : ) , ...
                 'plum' , col( 4 , : ) , ...
                'lgrey' , [ 0.6 , 0.6 , 0.6 ] ) ;
  
  
  %%% Populate each axis with appropriate graphics objects %%%
  
  
  %-- Make graphics objects --%
  
  % Line properties with or without highlighting
  prop.hi = { 'LineWidth' , 1.6 , 'Color' , col.green } ;
  prop.lo = { 'LineWidth' , 0.8 , 'Color' , col.blue  } ;
  
  % Data modalities
  for  TAG = { 'spk' , 'mua' } , tag = TAG{ 1 } ;
    
    % Find time axes
    ax = findobj( fh , 'Tag' , [ tag , 'time' ] ) ;
    
    % Create time series line objects
    hms.( tag ) = plot( ax , C.time , nan( C.N.time , C.N.dir ) , ...
      prop.lo{ : } , 'Tag' , [ tag , 'series' ] ) ;
    
    % Highlight line for selected direction
    set( hms.( tag )( 1 ) , prop.hi{ : } )
    
    % Find RF axes
    ax = findobj( fh , 'Tag' , [ tag , 'rf' ] ) ;
    
    % Make image object
    hrf.( tag ) = imagesc( ax , C.x , C.y , zeros( C.N.space ) , ...
      'Tag' , [ tag , 'map' ] ) ;
    
  end % time axes
  
  % Axes of spk time series
  ax = findobj( fh , 'Tag' , 'spktime' ) ;
  
  
  %-- Online plot group --%
  
  % Allocate group data
  dat.C = C ;
  dat.col = col ;
  dat.trials = 0 ;
  dat.dir = C.dir( 1 ) ;
  dat.chsel = lstbox ;
  dat.prop = prop ;
  dat.hms = hms ;
  dat.hrf = hrf ;
  dat.spk.time = zeros( C.N.time  , C.N.dir   , C.N.chan ) ;
  dat.mua.time = zeros( C.N.time  , C.N.dir   , C.N.chan ) ;
  dat.spk.rf   = zeros( C.N.space , C.N.space , C.N.chan ) ;
  dat.mua.rf   = zeros( C.N.space , C.N.space , C.N.chan ) ;
  
  % Add graphics object group to onlinefigure
  ofig.addgroup( 'rfmap' , '' , dat , ax , @fupdate )
  
  % List box selection invokes a special mode of the fupdate() function
  lstbox.Callback = @( ~ , ~ ) ofig.update( 'rfmap' , [ ] , [ ] ) ;
  
  
  %%% Done %%%
  
  % Initialise visibility of graphics objects
  ofig.update( 'rfmap' , [ ] , [ ] )
  
  % Show thine creation
  fh.Visible = 'on' ;
  
  
end % creatRFfig


%%% Define data = fupdate( hdata , data , index , newdata ) %%%

% motiondir gives the direction that was tested in the newly completed
% correct trial. new is a struct with fields .spk and .mua containing
% buffered signals; each has sub-fields .time and .data from the TdtWinBuf
% objects. If motiondir and new are empty, then the visibility of graphics
% objects is adjusted to reflect the channel selection. Note, hdata will be
% spike time series axes, and its title will show highlighted direction.
function  dat = fupdate( ax_spkms , dat , motiondir , new )
  
  % New channel was selected
  if  isempty( motiondir )
    
    % Index of currently selected channel
    ch = dat.chsel.Value ;
    
    % Assign RF maps
    dat.hrf.spk.CData( : , : ) = dat.spk.rf( : , : , ch ) ;
    dat.hrf.mua.CData( : , : ) = dat.mua.rf( : , : , ch ) ;
    
    % Assign time series for each direction
    for  i = 1 : dat.C.N.dir
      dat.hms.spk( i ).YData(:) = dat.spk.time( : , i , ch ) ./ dat.trials;
      dat.hms.mua( i ).YData(:) = dat.mua.time( : , i , ch ) ./ dat.trials;
    end
    
    % Done
    return
    
  end % new channel
  
  % Index of motion direction
  idir = dat.C.dir == motiondir ;
  
  % Old index of motion direction
  iold = dat.C.dir == dat.dir   ;
  
  % Direction was the same, we don't need to highlight different lines
  samedir = any( idir & iold ) ;
  
  % Update time series direction label
  title( ax_spkms , sprintf( 'Motion dir: %d deg' , motiondir ) )
  
  % Accumulate one more trial
  dat.trials = dat.trials + 1 ;
  
  % Data modalities
  for  TAG = { 'spk' , 'mua' } , tag = TAG{ 1 } ;
    
    % Point to buffered time and neural data
    T = new.( tag ).time ;
    X = new.( tag ).data ;
    
    % Process data according to type
    switch  tag
      
      % Spike times
      case  'spk'
        
        % First, allocate spike raster, ms time bins x channels
        R = zeros( dat.C.N.time , dat.C.N.chan ) ;
        
        % Channels
        for  ch = 1 : dat.C.N.chan
          
          % Spike times
          t = T( X( : , ch ) > 0 ) ;
          
          % No spikes, go to next channel
          if  isempty( t ) , continue , end
          
          % Convert from times to ms bin index
          t = ceil( ( t - dat.C.time( 1 ) + 1 ) ) ;
          
          % Discard anything that falls off the edges
          t( t < 0 | t > dat.C.N.time ) = [ ] ;
          
          % Raise raster time bins that contain a spike
          R( t , ch ) = 1 ;
          
        end % channels
        
        % Convolve spike raster with causal exponential kernel
        X = makconv( R , dat.C.kern , 'c' ) ;
        
      % Continuous multiunit activity
      case  'mua'
        
        % Linear interpolation at specified millisecond time bins
        X = interp1( T , X , dat.C.time ) ;
        
    end % process neural data
    
    % Accumulate signals into time series data
    dat.( tag ).time( : , idir , : ) = ...
      dat.( tag ).time( : , idir , : ) + permute( X , [ 1 , 3 , 2 ] ) ;
    
    % Keep only the time bins from the bar sweep
    X( dat.C.i , : ) = [ ] ;
    
    % Accumulate backprojection of responses over time into visual space,
    % for each channel
    for  ch = 1 : dat.C.N.chan
      dat.( tag ).rf( : , : , ch ) = dat.( tag ).rf( : , : , ch ) + ...
        backproj( X( : , ch ) , motiondir , 'yx' ) ;
    end
    
    % Currently selected channel
    ch = dat.chsel.Value ;
    
    % Update RF map
    dat.hrf.( tag ).CData( : , : ) = dat.( tag ).rf( : , : , ch ) ;
    
    % And update time series line with running average
    dat.hms.( tag )( idir ).YData( : ) = ...
      dat.( tag ).time( : , idir , ch )  ./  dat.trials ;
    
    % No direction change, done
    if  samedir , continue , end
    
    % Lower highlighting on old direction line, raise it on new
    set( dat.hms.( tag )( iold ) , dat.prop.lo{ : } )
    set( dat.hms.( tag )( idir ) , dat.prop.hi{ : } )
    
  end % data modalities
  
  % Update direction
  dat.dir = motiondir ;
  
  % Show changes
  drawnow
  
end % fupdate


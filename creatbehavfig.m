
function  ofig = creatbehavfig( cfg , err , tab )
% 
% ofig = creatbehavfig( cfg , err , tab )
% 
% Create and initialise behaviour plots. Called by task script. cfg is the
% ArcadeConfig object of the current session. err is the struct output from
% gettrialerrors mapping the name of each trial outcome to its numeric
% code. tab is a Table object containing processed version of
% trial_condition_table.csv, which defines all trial conditions and groups
% them into blocks of trials. Returns an onlinefigure object. Create plots
% before running the first trial.
% 
  
  
  %%% Blocks of trials %%%
  
  % Unique BlockType values. Here 'Block Type' means a unique grouping of
  % trial conditions.
  blk.typ = unique( tab.BlockType ) ;
  
  % Number of block types
  blk.N = numel( blk.typ ) ;
  
  % Find corresponding sets of target contrasts. This will be the
  % independent variable in the psychometric and RT plots. Return as cell
  % array of vectors.
  blk.x = ...
    arrayfun( @( t ) unique( tab.Contrast( tab.BlockType == t ) )' , ...
      blk.typ , 'UniformOutput' , false ) ;
  
  % Create name for each block
  blk.nam = arrayfun( @( t ) sprintf( 'Block %d' , t ) , blk.typ , ...
    'UniformOutput' , false ) ;
  
  % Concatenate x values
  x = [ blk.x{ : } ] ;
  
  % Global minimum and maximum contrast value when x is scalar
  if  isscalar( x )
  
    % Generate a small interval around the individual value
    blk.min = x  -  0.025 * x ;
    blk.max = x  +  0.025 * x ;
    
  % Multiple x values given
  else , blk.min = min( x ) ;  blk.max = max( x ) ;
  end
  
  % Range
  blk.rng = blk.max - blk.min ;
  
  % X-axis limits +/- 2.5%
  blk.lim = [ -0.025 , +0.025 ] * blk.rng  +  [ blk.min , blk.max ] ;
  
  
  %%% Create figure %%%
  
  % Determine the save name of the onlinefigure
  fnam = [ fullfile( cfg.filepaths.Behaviour, cfg.sessionName ) , '.fig' ];
  
  % Create onlinefigure object, it starts out being invisible
  ofig = onlinefigure( fnam , 'Tag' , 'Behaviour' , 'Visible' , 'off' ) ;
  
  % Point to figure handle
  fh = ofig.fig ;
  
  % Shape and ...
  fh.Position( 3 ) = ( 1 + 1/3 ) * ofig.fig.Position( 3 ) ; % width
  fh.Position( 4 ) =         0.9 * ofig.fig.Position( 4 ) ; % height
  
  % ... position the figure
  fh.Position( 1 : 2 ) = [ 1 , 31 ] ;
  
  
  %%% Create axes %%%
  
  % Outcome raster plot
  ofig.subplot( 6 , 3 , [  1 ,  5 ] , 'Tag' , 'Raster'        ) ;
  
  % Current/previous trial info
  ofig.subplot( 6 , 3 , [  3 ,  9 ] , 'Tag' , 'Info'          ) ;
  
  % Psychometric curves
  ofig.subplot( 6 , 3 , [  7 , 16 ] , 'Tag' , 'Psychometric'  ) ;
  
  % Reaction time curves
  ofig.subplot( 6 , 3 , [  8 , 17 ] , 'Tag' , 'Reaction Time' ) ;
  
  % Grand reaction time histogram
  ofig.subplot( 6 , 3 , [ 12 , 18 ] , 'Tag' , 'RT Histogram'  ) ;
  
  
  %%% Colour name to RGB map %%%
  
  % Axes all have the same default ColorOrder set, point to one of them
  col = fh.Children( 1 ).ColorOrder ;
  
  % Define a struct mapping field names to corresponding RGB values
  col = struct( 'green' , col( 5 , : ) , ...
                 'blue' , col( 1 , : ) , ...
               'yellow' , col( 3 , : ) , ...
                 'plum' , col( 4 , : ) , ...
                'lgrey' , [ 0.6 , 0.6 , 0.6 ] ) ;
  
  
  %%% Populate each axis with appropriate graphics objects %%%
  
  %-- Behav raster --%
  
  % Find its handle
  ax = findobj( fh , 'Tag' , 'Raster' ) ;
  
  % Create group data struct
  
    % Number of trials to track in raster
    dat.N = 500 ;
    
    % Session name for axes Title format string
    dat.nam = cfg.sessionName ;
  
    % Remember trial outcome (error) codes for key outcomes
    dat.out.Corr  = err.Correct    ;
    dat.out.Fail  = err.Failed     ;
    dat.out.False = err.FalseAlarm ;
    
    % Trial counters
    dat.cnt.Corr   = 0 ;
    dat.cnt.Fail   = 0 ;
    dat.cnt.False  = 0 ;
    dat.cnt.Trials = 0 ; % Only correct, failed, and false alarm
  
  % Axis limits
  axis( ax , [ 0.5 , dat.N + 0.5 , -0.5 , 4.0 ] )
  
  % Don't show the axes object, itself
  axis( ax , 'off' )
  
  % Initialise axes title, show string as is without any Tex interpretation
  set( ax.Title , 'String' , dat.nam , 'Interpreter' , 'none' , ...
    'HorizontalAlignment' , 'left' , 'FontSize' , 10 )
  
  % Switch units to pixels ...
  set( [ ax , ax.Title ] , 'Units' , 'pixels' )
  
  % ... so that we can position title near left edge of figure
  ax.Title.Position( 1 ) = -0.8 * ax.Position( 1 ) ;
  ax.Title.Position( 2 ) = 2 + ax.Title.Position( 2 ) ;
  
  % Raster labels
  y = 4 ;
  for  F = { 'corr' , 'fail' , 'false' , 'other' } , f = F{ 1 }; y = y - 1;
    
    text( ax , -0.01 * dat.N , y , f , 'HorizontalAlignment' , 'right' ,...
       'FontName' , 'Arial' , 'FontSize' , 10 )
    
  end % raster labels
  
  % X-axis and baseline y-axis values
  x =   nan( 1 , dat.N ) ;
  y = zeros( 1 , dat.N ) ;
  
  % Create rasters
  h = [ ...
plot( ax, x, y + 3, '.', 'MarkerEdgeColor', col.green , 'Tag' , 'Corr'  ) ;
plot( ax, x, y + 2, '.', 'MarkerEdgeColor', col.blue  , 'Tag' , 'Fail'  ) ;
plot( ax, x, y + 1, '.', 'MarkerEdgeColor', col.yellow, 'Tag' , 'False' ) ;
plot( ax, x, y + 0, '.', 'MarkerEdgeColor', col.plum  , 'Tag' , 'Other' )];
  
  % Add graphics object group to onlinefigure
  ofig.addgroup( 'BehavRaster', '', dat, [ ax , h'], @fupdate_behavraster )
  
  
  %-- Trial information --%
  
  % Find axes
  ax = findobj( fh , 'Tag' , 'Info' ) ;
  
  % Lock axes limits
  axis( ax , [ 0 , 1 , 0 , 1 ] )
  
  % Hide axes
  axis( ax , 'off' )
  
  % Alter err into a struct with cell array of error names in .nam and
  % error codes in .val. Fields are in register so that finding error in
  % .val by code yields the index required to find the error name in .nam.
  dat = struct( 'nam', { fieldnames( err ) }, 'val', struct2array( err ) );
  
  % Add text object to report trial info
  h = text( ax , 0 , 1 , '' , 'FontName' , 'Arial' , ...
    'VerticalAlignment' , 'top' ) ;
  
  % Add group
  ofig.addgroup( 'TrialInfo' , '' , dat , h , @fupdate_trialinfo )
  
  
  %-- Psychometric and reaction time curves --%
  
  % Data specific parameters
  
    % Axes tags
    TAGS = { 'Psychometric' , 'Reaction Time' } ;
    
    % Y-axis limits
    YLIM = { [ 0 , 100 ] , [ ] } ;
  
    % X- and Y-Axis labels
    XLAB = { 'Target contrast' , [ ] } ;
    YLAB = { 'Correct trials (%)' , 'Reaction time (ms)' } ;
    
    % Function handles
    FUPDATE = { @fupdate_psych , @fupdate_rt } ;
       FFIT = {    @ffit_psych ,    @ffit_rt } ;
    
  % Collect relevant trial error codes for group data
  dat.Correct = err.Correct ;
  dat.Failed  = err.Failed  ;
  
  % Selection and un-selection parameters for the error bars and scatter
  % objects that show the empirical data.
  selpar = { ...
    { 'Color' , col.blue / 2 , 'LineWidth' , 1 } ;
    { 'MarkerEdgeColor' , col.blue / 2 , 'MarkerFaceColor' , col.blue , ...
      'LineWidth' , 1 } } ;
  unspar = { ...
    { 'Color' , col.lgrey , 'LineWidth' , 0.5 } ;
    { 'MarkerEdgeColor' , col.lgrey , 'MarkerFaceColor' , col.lgrey , ...
      'LineWidth' , 0.5 } } ;
  
  % Selection and un-selection parameters for the parameter lines, labels,
  % and best-fit curve. Note, there are two parameter lines and labels.
  selparfit = [ repmat( { { 'Visible' ,  'on' } } , 4 , 1 ) ; 
    { { 'Color' , col.blue  , 'LineWidth' , 1.0 } } ] ;
  unsparfit = [ repmat( { { 'Visible' , 'off' } } , 4 , 1 ) ; 
    { { 'Color' , col.lgrey , 'LineWidth' , 0.5 } } ] ;
  
  % Best fit curve sample points
  xfit = blk.lim( 1 ) : blk.rng / 1e3 : blk.lim( 2 ) ;
  yfit = nan( size( xfit ) ) ;
  
  % Data types
  for  dattyp = 1 : numel( TAGS )

    % Find axes
    ax = findobj( fh , 'Tag' , TAGS{ dattyp } ) ;

    % Format the axis
    axis( ax , 'square' )
    xlim( ax , blk.lim )
    if  ~ isempty( YLIM{ dattyp } ) , ylim( ax , YLIM{ dattyp } ) , end

    % Labels
    if  ~ isempty( XLAB{ dattyp } ) , xlabel( ax , XLAB{ dattyp } ) , end
    ylabel( ax , YLAB{ dattyp } )

    % Blocks of trials
    for  i = 1 : blk.N
      
      % Get group and set identifier strings (id & nam)
      nam = blk.nam{ i } ;
      id = [ TAGS{ dattyp } , ' ' , nam ] ;

      % The set of independent variable test values, and NaN vector with the
      % same size
      x = blk.x{ i } ;
      y = nan( size( x ) ) ;

      % Data will be a Welford array, for accumulating an estimate of
      % variance
      dat.w = Welford( size( x ) ) ;

      % Create empirical data graphics objects
      h = [ errorbar( ax , x , y , y , 'LineStyle' , 'none' , ...
              'Marker' , 'none' , 'Tag' , 'error' ) , ...
            scatter( ax , x , y , 'Tag' , 'data' ) ] ;

      % Add graphics object group and bind parameters
      ofig.addgroup ( id , nam , dat , h , FUPDATE{ dattyp } )
      ofig.bindparam( id ,   'seldata' , selpar{ : } )
      ofig.bindparam( id , 'unseldata' , unspar{ : } )
      
      % Too few points to fit curves, skip to next block
      if  numel( x ) < 5 , continue , end

      % Make curve fitting graphics objects
      h = [ plot( ax , nan( 2 , 2 ) , nan( 2 , 2 ) , 'k--' ) ; 
            text( ax , nan( 1 , 2 ) , nan( 1 , 2 ) , { '' , '' } , ...
              'FontName' , 'Arial' , 'VerticalAlignment' , 'bottom' , ...
                'Clipping' , 'on' ) ]' ;

      % Tag them
      h( 1 ).Tag = 'xthreshold' ;  h( 3 ).Tag = 'xthlabel' ;
      h( 2 ).Tag = 'ythreshold' ;  h( 4 ).Tag = 'ythlabel' ;

      % Create fitted function line
      h = [ h , plot( ax , xfit , yfit , 'Tag' , 'curve' ) ] ;

      % Bind fitted function to data, and selection params to fit objects
      ofig.bindfit( id , h , FFIT{ dattyp } )
      ofig.bindparam( id ,   'selfit' , selparfit{ : } )
      ofig.bindparam( id , 'unselfit' , unsparfit{ : } )

    end % blocks
  end % data types
  
  % Find both axes
  ax = [ findobj( fh , 'Tag' , TAGS{ 1 } ) ;
         findobj( fh , 'Tag' , TAGS{ 2 } ) ] ;
       
  % Set units to pixels
  set( [ ax ; ax( 1 ).XLabel ] , 'Units' , 'pixels' )
  
  % Position x-axis label between the two axes
  ax( 1 ).XLabel.Position( 1 ) = ( ax( 2 ).Position( 1 ) - ...
    sum( ax( 1 ).Position( [ 1 , 3 ] ) ) ) / 2  +  ax( 1 ).Position( 3 ) ;
  
  % Reset unit type
  set( ax , 'Units' , 'normalized' )
  
  
  %-- Reaction time histogram --%
  
  % Find axes
  ax = findobj( fh , 'Tag' , 'RT Histogram' ) ;
  
  % Make it a tad shorter
  ax.Position( [ 2 , 4 ] ) = [ +1/3 , -1/3 ] * ax.Position( 4 )  +  ...
    ax.Position( [ 2 , 4 ] ) ;

  % Lock x-axis limits, in milliseconds
  xlim( ax , [ 0 , 500 ] )
  
  % Labels
  xlabel( ax , 'Reaction time (ms)' )
  ylabel( ax , 'Trials' )
  
  % Centre of RT bins
  x = 5 : 10 : 495 ;
  
  % Initialise bar height
  y = zeros( size( x ) ) ;
  
  % Selection display parameters for bar and text objects
  selpar = { { 'EdgeColor', 'k', 'FaceColor', col.blue, 'BarWidth', 1 } ;
             { 'Visible', 'on' } } ;
  unspar = { { 'EdgeColor', 'none', 'FaceColor', col.lgrey, ...
    'BarWidth', 0.9 } ; { 'Visible', 'off' } } ;
  
  % Collect information about bin number and width. Also, get trial error
  % code for correct trial outcome. Also, maintain a total RT sum and trial
  % count.
  dat = struct( 'N', numel( x ), 'width', 10, 'Correct', err.Correct, ...
    'RTsum', 0, 'trials', 0 ) ;
  
  % Blocks of trials. Get group and set identifiers (id & nam).
  for  i = 1 : blk.N , nam = blk.nam{ i } ; id = [ 'RT ' , nam ] ;
    
    % Create bar object to draw the histogram and text object to report the
    % mean RT
    h = [  bar( ax , x , y , 1 , selpar{ 1 }{ : } , 'Tag' , 'data' ) , ...
          text( ax, 1, 1, '', 'Units', 'normalized', 'Tag', 'avg', ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'top' ) ];
    
    % Create new graphics objects group.
    ofig.addgroup( id , nam , dat , h , @fupdate_rthist )
    
    % Bind selection and un-selection parameters
    ofig.bindparam( id , 'seldata'   , selpar{ : } )
    ofig.bindparam( id , 'unseldata' , unspar{ : } )
    
  end % blocks of trials
  
  
  %%% Done %%%
  
  % Apply formatting through selection of first block, by default
  ofig.select( 'set' , blk.nam{ 1 } )
  
  % Show thine creation
  fh.Visible = 'on' ;
  
  
end % creatbehavfig


%%% Define data = fupdate( hdata , data , index , newdata ) %%%

% Tally trials and report in axes title. Adjust raster tick position and
% highlight trial outcome. Maintain dividers to show different blocks.
% index is not required. newdata must be a struct with fields
%   .pre_err - Trial error code of the previous trial.
%   .pre_block - Block index (not type, index) of previous trial.
%   .nex_block - Block index of the next, upcoming trial.
function  data = fupdate_behavraster( hdata , data , ~ , newdata )
  
  % Determine the outcome of the previous trial, and whether to increment
  % the trial count.
  switch  newdata.pre_err
    case  data.out.Corr  , err = 'Corr'  ;
    case  data.out.Fail  , err = 'Fail'  ;
    case  data.out.False , err = 'False' ;
    otherwise            , err = 'Other' ;
  end
  
  % Update trial tally if error string not 'Other'
  if  err( 1 ) ~= 'O'
    data.cnt.Trials  = 1  +  data.cnt.Trials  ;
    data.cnt.( err ) = 1  +  data.cnt.( err ) ;
  end
  
  % Cell array of title sub-strings
  C = cell( 1 , 5 ) ;
  
  % Session name first
  C{ 1 } = data.nam ;
  
  % Trial outcomes, retrieve name, and increment string index
  i = 1 ;
  for  F = { 'Corr', 'Fail', 'False' } , f = F{ 1 } ; i = i + 1 ;
    
    % Count and percentage
    cnt = data.cnt.( f ) ;
    per = data.cnt.( f ) / data.cnt.Trials * 100 ;
    
    % Format <outcome> <count>(<% trials>)
    C{ i } = sprintf( '%s %d(%.1f%%)' , f , cnt , per ) ;
    
  end % outcomes
  
  % Last, the total number of tallied trials
  C{ end } = sprintf( 'Trials %d' , data.cnt.Trials ) ;
  
  % Get axes
  ax = findobj( hdata , 'Type' , 'axes' , 'Tag' , 'Raster' ) ;
  
  % Format new title string for axes
  ax.Title.String = strjoin( C , ', ' ) ;
  
  % Raster lines, we know that these are not the axes
  for  h = hdata( hdata ~= ax )
    
    % Shift all data points to the left
    h.XData( : ) = [ h.XData( 2 : end ) - 1 , NaN ] ;
    
    % Previous trial error is represented by this raster line, show trial
    if  strcmp( h.Tag , err ) , h.XData( end ) = data.N ; end
    
  end % raster lines
  
  % Block divider lines
  for  h = findobj( ax , 'Tag' , 'block' )'
    
    % Subtract position by one trial
    h.XData( : ) = h.XData - 1 ;
    
    % Line falls off edge of axes, kill it
    if  h.XData( 1 ) < ax.XLim( 1 ) , delete( h ) , end
    
  end % block lines
  
  % New block line is needed
  if  newdata.pre_block ~= newdata.nex_block
    
    plot( ax , ax.XLim( [ 2 , 2 ] ) , ax.YLim , 'Tag' , 'block' , ...
      'Color' , [ 0.6 , 0.6 , 0.6 ] )

  end % new block
  
end % fupdate_behavraster


% Simply re-format info string with prev- and next trial info. All of
% this is provided in struct newdata. Each field is a 1x2 vector containing
% [ prev , next ] trial data. Fields:
%   .ind - Trial indices
%   .err - Trial error codes
%   .con - Trial conditions
%   .blk - Block indices
%   .typ - Block types
%   .rt  - Reaction times
%
% There is one additional set of fields. These are scalar values:
%   .trials - Number of correct/failed trials collected in the current
%      block.
%   .total - Total number of trials required by block.
function  data = fupdate_trialinfo( hdata , data , ~ , newdata )
  
  % Accumulate info string
  str = cell( 1 , 3 ) ;
  
  % Init prev/next index
  i = 0 ;
  
  % Previous and next trials
  for  F = { 'Prev' , 'Next' } , f = F{ 1 } ; i = i + 1 ;
    
    % Empty cell of strings
    C = cell( 1 , 5 ) ;
    
    % Trial index
    C{ 1 } = sprintf( '%s trial: %d\n' , f , newdata.ind( i ) ) ;
    
    % Block index and type
    C{ 2 } = sprintf( '  Block(type): %d(%d)\n' , ...
      newdata.blk( i ) , newdata.typ( i ) ) ;
    
    % And trial condition
    C{ 3 } = sprintf( '  Cond: %d' , newdata.con( i ) ) ;
    
    % Previous trial has more info
    if  strcmp( f , 'Prev' )
      
      % Search for trial error code in list
      e = data.val == newdata.err( i ) ;
      
      % Trial outcome name
      C{ 4 } = sprintf( '\n  Result: %s\n' , data.nam{ e } ) ;
      
      % Reaction time
      C{ 5 } = sprintf( '  RT: %dms' , ceil( newdata.rt( i ) ) ) ;
      
    end % prev trial
    
    % Concatenate and accumulate
    str{ i } = [ C{ : } , ...
      sprintf( '\\fontsize{2}\n\\fontsize{%d}\n' , hdata.FontSize ) ] ;
    
  end % prev / next trial
  
  % Block's trial count
  str{ end } = sprintf( 'Trials/Total: %d/%d (%.1f%%)', ...
    newdata.trials, newdata.total, newdata.trials / newdata.total * 100 ) ;
  
  % Show string after final concatenation
  hdata.String = [ str{ : } ] ;
  
end % fupdate_trialinfo


% Updates the psychometric curves. index must be a struct. index.x is the
% target contrast of the previous trial. index.err is the trial error code
% of the previous trial. newdata input arg not used.
function  data = fupdate_psych( hdata , data , index , ~ )
  
  % Previous trial not correct or failed, return now
  if  index.err ~= data.Correct && index.err ~= data.Failed , return , end
  
  % newdata is 0 for failed and 1 for correct
  newdata = index.err == data.Correct ;
  
  % Call generic function with additional scaling arguments
  data = fupdate_targcon( hdata, data, index, newdata, 100, 'binpci' ) ;
  
end % fupdate_psych


% Updates the reaction time vs target contrast curves. Same form as
% fupdate_psych, except that newdata contains previous trial reaction time.
function  data = fupdate_rt( hdata , data , index , newdata )
  
  % Trial is not correct, return now
  if  index.err ~= data.Correct , return , end
  
  % Call generic function with additional scaling arguments
  data = fupdate_targcon( hdata , data , index , newdata , 1 , 'sem' ) ;
  
  % Parent axes
  ax = hdata( 1 ).Parent ;
  
  % Find all data objects in parent axes
  h = findobj( ax , 'Tag' , 'data' ) ;
  
  % Return all y-axis values
  y = get( h , 'YData' ) ;
  
  % Concatenate across multiple objects
  if  iscell( y ) , y = [ y{ : } ] ; end
  
  % Min and max y-axis values
  y = [ min( y ) , max( y ) ] ;
  
  % Difference is zero when there is only one data point, quit now
  if  ~ diff( y ) , return , end
  
  % Y-axis limits are +/-2.5% of min to max range
  ax.YLim = [ -0.025 , +0.025 ] * diff( y )  +  y ;
  
  % Set lower point of vertical threshold lines to new lower y-limit
  for  h = findobj( ax , 'Tag' , 'xthreshold' )'
    h.YData( 1 ) = ax.YLim( 1 ) ;
  end
  
  % And again, re-position x-threshold labels
  for  h = findobj( ax , 'Tag' , 'xthlabel' )'
    h.Position( 2 ) = ax.YLim( 1 ) ;
  end
  
end % fupdate_rt


% Generic fupdate function for psychometric and reaction time vs contrast.
% Has additional scaling factor and names the Welford variance function to
% use.
function  data = fupdate_targcon( hdata, data, index, newdata, scale, fvar)
  
  % Locate graphics objects by data they represent
   herr = findobj( hdata , 'Tag' , 'error' ) ;
  hdata = findobj( hdata , 'Tag' ,  'data' ) ;
  
  % Get a copy of the x-axis values i.e. the stimulus values
  xval = hdata.XData ;
  
  % Locate stimulus value
  i = xval == index.x ;
  
  if  ~ any( i )
    error( 'Cannot find given index value for this group.' )
  end
  
  % Update Welford array
  data.w( i ) = data.w( i ) + newdata ;
  
  % Update plots
  hdata.YData( i ) = scale .* data.w( i ).avg ;
   herr.YData( i ) = hdata.YData( i ) ;
   herr.YNegativeDelta( i ) = scale .* data.w( i ).( fvar ) ;
   herr.YPositiveDelta( i ) = herr.YNegativeDelta( i ) ;
  
end % fupdate_targcon


% Fit psychometric curve to performance data. Least-squares non-linear
% regression.
function  ffit_psych( hfit , hdata , data )
  
  % Define Weibull function.
  % Coefficients c = [ guess rate , lapse rate , shape , threshold ].
  fun = @( c , x )  c( 1 )  +  ( 100 - c( 1 ) - c( 2 ) ) .* ...
    ( 1  -  exp( -( x ./ c( 4 ) ) .^ c( 3 ) ) ) ;
  
  % Lower and upper bounds on coefficients
  bounds = { [ 0 , 0 , 0 , 0 ] , [ 100 , 100 , +Inf , +Inf ] } ; 
  
  % Execute fit
  ffit_targcon( hfit , hdata , data , '%c' , 5 , fun , bounds )
  
end % ffit_psych


% Fit logistic curve to Avg RT data. Least-squares non-linear regression.
function  ffit_rt( hfit , hdata , data )
  
  % Define logistic function.
  % Coefficients c = [ baseline , amplitude , slope , centre ].
  fun = @( c , x )  c( 1 )  +  c( 2 ) ./ ...
    ( 1 + exp( -c( 3 ) .* ( x - c( 4 ) ) ) ) ;
  
  % No bounds
  bounds = { [ 0 , 0 , -Inf , -Inf ] , [ +Inf , +Inf , +Inf , +Inf ] } ;
  
  % Execute fit
	ffit_targcon( hfit , hdata , data , 'rt' , 3 , fun , bounds )
  
end % ffit_rt


% Generic logistic curve fitting. Assumes 1 x 4 coefficients, and that
% coefficients 3 and 4 are the slope and centre.
function  ffit_targcon( hfit , hdata , data , type , n , fun , bounds )
  
  % If count is too low then quit
  if  any( data.w.count < n ) , return , end
  
  % Least-square fitting functions' options objects, disable verbosity
  persistent  opt
  
    % First execution of function
    if  isempty( opt )
      
      % Create options objects just once
      opt.lsqcurvefit = optimoptions( 'lsqcurvefit' , 'Display' , 'off' ) ;
      opt.lsqnonlin   = optimoptions(   'lsqnonlin' , 'Display' , 'off' ) ;
      
      % And grab the default state of Matlab's warnings
      opt.w = warning ;
      
    end % first run
  
  % Locate graphics objects by data they represent
   herr = findobj( hdata , 'Tag' , 'error' ) ;
  hdata = findobj( hdata , 'Tag' ,  'data' ) ;
  
  % Extract x and y coordinates of data
  x = hdata.XData ;
  y = hdata.YData ;
  
  % Variance of each data point. Symmetrical bars, see fupdate_targcon.
  v = herr.YPositiveDelta ;
  
    % Look for any zero values, otherwise we can't do weighted least-
    % squares regression on reciprocal of the variance
    i = v == 0 ;
    
    % All of them are zero. Empty v, skipping weighted least-squares.
    if  all( i ) , v = [ ] ;
      
    % Some of them are
    elseif  any( i )
      
      % Set zero-valued variances to something non-zero. Let's use half of
      % the minimum non-zero value. This way, the zero-variance points will
      % still have more weight than any other.
      v( i ) = min( v( ~i ) ) / 2 ;
      
    end % var check
  
  % Number of data points
  n = numel( x ) ;
  
  % Initialise coefficients
  c0 = zeros( 1 , 4 ) ;
  
  % Set baseline to minimum observed value
  c0( 1 ) = min( y ) ;
  
  % Coefficient 2 has a different meaning for % correct vs RT. In both
  % cases, set slope coefficient to estimate parameter 3.
  switch  type
    case  '%c' , c0( 2 ) = 100 - max( y ) ; % lapse rate
                   scoef = 500 ;
    case  'rt' , c0( 2 ) = max( y ) - c0( 1 ) ; % amplitude
                   scoef =  10 ;
  end
  
  % Use slope of linear regression line as a starting guess
  b = [ ones( n , 1 ) , x( : ) ]  \  y( : ) ;
  
  % Heuristic decision, reduce magnitude of linear slope
  c0( 3 ) = b( 2 ) / scoef ;
  
  % Get middle x-axis value
  if  mod( numel( x ) , 2 )
    c0( 4 ) = x( ceil( n / 2 ) ) ;
  else
    c0( 4 ) = mean( x( n / 2 + [ 0 , 1 ] ) ) ;
  end
  
  % Disable all warnings
  warning off all
  
  % Least-squares without weighting when variances are all zero
  if  isempty( v )
    
    % Best fitting non-linear bounded least-squares
    c = lsqcurvefit( fun , c0 , x , y , bounds{ : } , opt.lsqcurvefit ) ;
    
  % Weighted least-squares
  else
    
    % Compute weights
    weights = 1 ./ v ;
    
    % Normalise weights
    weights = weights ./ sum( weights ) ;
    
    % Build a residuals function to minimise
    res = @( c ) fresidual( x , y , weights , fun , c ) ;
    
    % Weighted non-linear least-squares
    c = lsqnonlin( res , c0 , bounds{ : } , opt.lsqnonlin ) ;
    
  end % weighted least-squares
  
  % Default warnings
  warning( opt.w )
  
  % Locate different elements
  hcurve = findobj( hfit , 'Tag' , 'curve'      ) ;
  hxthr  = findobj( hfit , 'Tag' , 'xthreshold' ) ;
  hxlab  = findobj( hfit , 'Tag' , 'xthlabel'   ) ;
  hythr  = findobj( hfit , 'Tag' , 'ythreshold' ) ;
  hylab  = findobj( hfit , 'Tag' , 'ythlabel'   ) ;
  
  % Draw best fit line
  hcurve.YData( : ) = fun( c , hcurve.XData ) ;
  
  % Locate the threshold value i.e. x-axis position
  hxthr.XData( : ) = c( 4 ) ;
  hythr.XData( : ) = [ hcurve.XData( 1 ) , c( 4 ) ] ;
  
  % Locate the performance at threshold
  hxthr.YData( : ) = [ hxthr.Parent.YLim( 1 ) , fun( c , c( 4 ) ) ] ;
  hythr.YData( : ) = hxthr.YData( 2 ) ;
  
  % Make threshold labels
  hxlab.String = sprintf( '%.2f' , c( 4 ) ) ;
  hylab.String = sprintf( '%.2f' , hxthr.YData( 2 ) ) ;
  
  % Position labels
  hxlab.Position( 1 : 2 ) = [ c( 4 ) , hxthr.YData( 1 ) ] ;
  hylab.Position( 1 : 2 ) = [ hcurve.XData( 1 ) , hxthr.YData( 2 ) ] ;
  
end % ffit_targcon


% Home-made residual/objective function for lsqnonlin. This allows weighted
% regression and also a bounded parameter search. fh is a function as
% accepted by lsqcurvefit.
function  res = fresidual( xdata , ydata , weights , funchandle , coef )

  res = weights .* ( funchandle( coef , xdata ) - ydata ) ;

end % res


% Block-wide reaction time histogram. newdata is the trial error code of
% previous trial. index is the reaction time of previous trial.
function  data = fupdate_rthist( hdata , data , index , newdata )
  
  % Check if previous trial was correct. If not, return immediately because
  % there is no valid reaction time.
  if  data.Correct ~= newdata , return , end
  
  % Find the bar
  hbar = findobj( hdata , 'Tag' , 'data' ) ;
  
  % Compute index of bin that tallies new reaction time
  i = min( ceil( index / data.width ) , data.N ) ;
  
  % Count one more trial
  hbar.YData( i ) = hbar.YData( i ) + 1 ;
  
  % Accumulate sum
  data.RTsum  = data.RTsum  + index ;
  data.trials = data.trials + 1     ;
  
  % Find average RT text object
  htext = findobj( hdata , 'Tag' , 'avg' ) ;
  
  % Format string with latest average RT
  htext.String = sprintf( '%dms\navg', round( data.RTsum / data.trials ) );
  
end % fupdate_rthist


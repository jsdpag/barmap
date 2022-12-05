
function  current_block = block_selection( currentTrial )
% 
% current_block = block_selection( currentTrial )
% 
% dbstop in block_selection.m at 68
  
  %%% Special variables %%%
  
  % Local persistent store of variables
  persistent  P ;
  
  % Global variable for communication with condition_selection( ) and task
  % script
  global  ARCADE_BLOCK_SELECTION_GLOBAL ;
  
  
  %%% Session initialisation %%%
  
  if  currentTrial == 1
    
    % Get a copy of trial error codes
    P.err = gettrialerrors( true ) ;
    
    % Import block definition table into Matlab, keep local copy
    P.tab = gettab ;
    
    % Unique set of block type codes
    P.set = unique( P.tab.BlockType ) ;
    
    % Initialise current block type to first in the set list
    P.typ = P.set( 1 ) ;
    
    % Initialise trial counter for a new block of this type
    P.cnt = initcnt( P.typ , P.tab ) ;
    
    % Initialise block counter
    P.blk = 1 ;
    
    % Share this info with condition selection and task script
    ARCADE_BLOCK_SELECTION_GLOBAL.tab = P.tab ;
    ARCADE_BLOCK_SELECTION_GLOBAL.err = P.err ;
    ARCADE_BLOCK_SELECTION_GLOBAL.typ = P.typ ;
    ARCADE_BLOCK_SELECTION_GLOBAL.condition = P.cnt.condition ;
    ARCADE_BLOCK_SELECTION_GLOBAL.count = ...
      struct( 'trials' , 0 , 'total' , sum( P.cnt.trials ) ) ;
    
    % Can't go further because ARCADE trial data is empty on trial 1
    current_block = P.blk ;
    return
    
  end % session init
  
  
  %%% Track progress of block %%%
  
  % Previous trials' data
  t = getPreviousTrialData ;
  
  % Previous error, condition, and block type codes
  e = t.trialError( end ) ;
  c = t.conditions( end ) ;
  b = t.blocks    ( end ) ;
  
  % Sanity check, is previous block count the same as that on the previous
  % trial?
  if  P.blk ~= b , error( 'Block count mis-match' ) , end
  
  % Locate condition's index inside local counter struct
  i = P.cnt.condition == c ;
  
  % Increment condition's counter if trial was correct or failed
  P.cnt.counter( i ) = P.cnt.counter( i ) + ( e == P.err.Correct ) + ...
    ( e == P.err.Failed ) ;
  
  % Find counter indices of the conditions that are still missing trials
  i = P.cnt.counter < P.cnt.trials ;
  
  % Get sub-set of codes for conditions that still lack trials
  c = P.cnt.condition( i ) ;
  
  % No trials lack conditions, the current block is finished
  if  isempty( c )
    
    % Find block position in set and increment to next item in set
    i = find( P.set == P.typ ) + 1 ;
    
    % Index exceeds number of block types, go back to first one
    if  i > numel( P.set ) , i = 1 ; end
    
    % Set current block type
    P.typ = P.set( i ) ;
    
    % Initialise new counter
    P.cnt = initcnt( P.typ , P.tab ) ;
    
    % Set of conditions
    c = P.cnt.condition ;
    
    % Increment block counter
    P.blk = P.blk + 1 ;
    
    % Tell condition selection and task script what type of block it is
    ARCADE_BLOCK_SELECTION_GLOBAL.typ = P.typ ;
    
    % Total number of trials required by this block
    ARCADE_BLOCK_SELECTION_GLOBAL.count.total = sum( P.cnt.trials ) ;
    
  end % new block
  
  % Pack set of valid trial conditions for condition selection function
  ARCADE_BLOCK_SELECTION_GLOBAL.condition = c ;
  
  % Tally number of completed trials in this block
  ARCADE_BLOCK_SELECTION_GLOBAL.count.trials = sum( P.cnt.counter ) ;
  
  % Return current block type
  current_block = P.blk ;
  
end % block_selection


%%% Sub-routines %%%

% Load CSV table defining blocks of trials and do basic validity tests
function  tab = gettab

  % Name of comma-separated table that defines blocks of trials and
  % their conditions
  tabnam = 'trial_condition_table.csv' ;
  
  % Required set of table column header names
  reqnam = { 'BlockType' , 'Condition' , 'Trials' } ;
  
  % Numerical range of each var, given as inclusive limits
  lim.BlockType = [ 1 , Inf ] ;
  lim.Condition = [ 1 , Inf ] ;
  lim.Trials    = [ 0 , Inf ] ;
  
  % This column must contain unique values across all rows
  unicol = 'Condition' ;

  % Look for table of block definitions
  if  ~ exist( tabnam , 'file' )
    error( 'Cannot find %s that defines blocks of trials' , tabnam )
  end

  % Read in trial definitions
  tab = readtable( tabnam ) ;
  
  % Store table name in user data
  tab.Properties.UserData = tabnam ;

  % Empty table
  if  isempty( tab )
    
    error( '%s is empty' , tabnam )
    
  % Check for required column headers
  elseif  ~ all( ismember( reqnam , tab.Properties.VariableNames ) )
    
    error( '%s must contain columns: %s' , ...
      tabnam , strjoin( reqnam , ' , ' ) )
    
  end % err check
  
  % Check each column, fetch values in v
  for  C = reqnam , c = C{ 1 } ; v = tab.( c ) ;
    
    if  ~( isnumeric( v ) && isreal( v ) && ~any( mod( v , 1 ) ) && ...
         all( isfinite( v ) & lim.( c )( 1 ) <= v & v <= lim.( c )( 2 ) ) )
      
      error( [ 'Column %s of table %s must be real, finite ' , ...
        'integers in the range [%d,%d]' ] , c , tabnam , lim.( c ) )
      
    end
    
  end % col check
  
  % Strip away any condition that is effectively disabled because its trial
  % count is zero
  i = tab.Trials == 0 ;
  tab( i , : ) = [ ] ;
  
  % Have we thrown away all trials?
  if  isempty( tab )
    
    error( 'Trials is zero in all trial conditions of %s' , tabnam )
    
  % Guarantee that all values in this column are unique
  elseif  numel( unique( tab.( unicol ) ) ) ~= numel( tab.( unicol ) )
    
    error( 'All values of column %s in table %s must be unique' , ...
      unicol , tabnam )
    
  end % final err check
  
end % gettab


% Create a new trial counting structure to keep track of current block's
% progress
function  cnt = initcnt( typ , tab )
  
  % Find all trial conditions for this type of block
  i = tab.BlockType == typ ;
  
  % Store trial condition codes and total number of correct/failed trials
  cnt.condition = tab.Condition( i ) ;
  cnt.trials    = tab.Trials( i ) ;
  
  % Initialise trial counter for each condition to zero
  cnt.counter = zeros( size( cnt.condition ) ) ;
  
end % initcnt


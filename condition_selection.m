
function  curCond = condition_selection( ~ , ~ )
% 
% curCond = condition_selection( currentTrial , curBlock )
% 
% dbstop in condition_selection.m at 9
  
  % Read info from block selection function
  global  ARCADE_BLOCK_SELECTION_GLOBAL ;
  
  % Specifically, get the set of valid trial conditions to sample
  c = ARCADE_BLOCK_SELECTION_GLOBAL.condition ;
  
  % Randomly select one of them
  i = ceil( rand * numel( c ) ) ;
  
  % Return randomly selected condition
  curCond = c( i ) ;
  
end % condition_selection

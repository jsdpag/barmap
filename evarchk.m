
function  v = evarchk( RewardMaxMs , RfXDeg , RfYDeg , RfRadDeg , ...
  RfWinFactor , FixTolDeg , TrainingMode , BaselineMs , WaitAvgMs , ...
    WaitMaxProb , ReacTimeMinMs , RespWinWidMs , RewardSlope , ...
      RewardMinMs , RewardFailFrac , ScreenGamma , ItiMinMs )
% 
% evarchk( <ARCADE editable variables> )
% 
% Performs error checking on each variable. Returns struct v where each
% input variable is assigned to a field with the same name.
% 
  
  % Define inclusive limits to each Numeric variable, or the set of valid
  % strings for a Text variable
  lim.RewardMaxMs = [ 0 , Inf ] ;
  lim.RfXDeg = [ -Inf , +Inf ] ;
  lim.RfYDeg = [ -Inf , +Inf ] ;
  lim.RfRadDeg = [ 0 , +Inf ] ;
  lim.RfWinFactor = [ 0 , +Inf ] ;
  lim.FixTolDeg = [ 0 , Inf ] ;
  lim.TrainingMode = { 'off' , 'trial' , 'block' } ;
  lim.BaselineMs = [ 0 , Inf ] ;
  lim.WaitAvgMs = [ 0 , Inf ] ;
  lim.WaitMaxProb = [ 0 , 1 ] ;
  lim.ReacTimeMinMs = [ 0 , Inf ] ;
  lim.RespWinWidMs = [ 0 , Inf ] ;
  lim.RewardSlope = [ 0 , Inf ] ;
  lim.RewardMinMs = [ 0 , Inf ] ;
  lim.RewardFailFrac = [ 0 , 1 ] ;
  lim.ScreenGamma = [ 0 , Inf ] ;
  lim.ItiMinMs = [ 0 , Inf ] ;
  
  % Pack input into struct
  v.RewardMaxMs = RewardMaxMs ;
  v.RfXDeg = RfXDeg ;
  v.RfYDeg = RfYDeg ;
  v.RfRadDeg = RfRadDeg ;
  v.RfWinFactor = RfWinFactor ;
  v.FixTolDeg = FixTolDeg ;
  v.TrainingMode = TrainingMode ;
  v.BaselineMs = BaselineMs ;
  v.WaitAvgMs = WaitAvgMs ;
  v.WaitMaxProb = WaitMaxProb ;
  v.ReacTimeMinMs = ReacTimeMinMs ;
  v.RespWinWidMs = RespWinWidMs ;
  v.RewardSlope = RewardSlope ;
  v.RewardMinMs = RewardMinMs ;
  v.RewardFailFrac = RewardFailFrac ;
  v.ScreenGamma = ScreenGamma ;
  v.ItiMinMs = ItiMinMs ;
  
  % Numeric variables
  for  N = fieldnames( v )' ; n = N{ 1 } ;
    
    % Check type. First see if variable is expected to be Text
    if  iscellstr( lim.( n ) )
      
      % Check that variable is string
      if  ~ ischar( v.( n ) )  ||  ~ isrow( v.( n ) )
        error( '%s must be a char row vector i.e. a string' , n )
      end
      
      % Make sure that string is lower case
      v.( n ) = lower( v.( n ) ) ;
      
      % String not found in set of valid strings. Don't kill session. But
      % do warn user.
      if  ~ any( strcmp( v.( n ) , lim.( n ) ) )
        
        % Format the warning string
        wstr = sprintf( '%s must be one of: %s' , ...
          n , strjoin( lim.( n ) , ', ' ) ) ;
        
        % Print in both echo server window, the command window, and error
        % log
        EchoServer.Write( wstr )
        warning( wstr )
        
      end % invalid string
      
    % All remaining variables must be of double numeric type
    elseif  ~ isa( v.( n ) , 'double' )
      
      error( '%s must be of type double' , n )
      
    % Check numeric variable is within acceptable limits
    elseif  v.( n ) < lim.( n )( 1 )  ||  v.( n ) > lim.( n )( 2 )
      
      error( '%s must be within inclusive range [ %.3f , %.3f ]' , ...
        n , lim.( n ) )
      
    end % checks
    
  end % num vars
  
end % evarchk


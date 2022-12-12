
function  v = evarchk( Reward , BarOriginDeg , TravelDiameterDeg , ...
  BarWidthHightDeg , BarSpeedDegPerSec , BarRGB , FixTolDeg , ...
    BaselineMs , RewardMinMs , ScreenGamma , ItiMinMs , TdtHostPC , ...
      TdtExperiment , LaserCtrl , TdtChannels , SpikeBuffer , ...
        MuaStartIndex , MuaBuffer , VisualLatencyMs , StimRespSim , ...
          SynthRfXywDeg )
% 
% evarchk( <ARCADE editable variables> )
% 
% Performs error checking on each variable. Returns struct v where each
% input variable is assigned to a field with the same name.
% 
  
  % Define inclusive limits to each Numeric variable, or the set of valid
  % strings for a Text variable. Limit check is skipped if empty.
  lim.Reward = [ 0 , Inf ] ;
  lim.BarOriginDeg = [ -Inf , +Inf ] ;
  lim.TravelDiameterDeg = [ 0 , +Inf ] ;
  lim.BarWidthHightDeg = [ 0 , +Inf ] ;
  lim.BarSpeedDegPerSec = [ 0 , +Inf ] ;
  lim.BarRGB = [ 0 , 2 ^ 8 - 1 ] ;
  lim.FixTolDeg = [ 0 , +Inf ] ;
  lim.BaselineMs = [ 0 , +Inf ] ;
  lim.RewardMinMs = [ 0 , +Inf ] ;
  lim.ScreenGamma = [ 0 , +Inf ] ;
  lim.ItiMinMs = [ 0 , +Inf ] ;
  lim.TdtHostPC = { } ;
  lim.TdtExperiment = { } ;
  lim.LaserCtrl = { } ;
  lim.TdtChannels = [ 1 , 32 ] ;
  lim.SpikeBuffer = { } ;
  lim.MuaStartIndex = [ 1 , 32 ] ;
  lim.MuaBuffer = { } ;
  lim.VisualLatencyMs = [ 0 , +Inf ] ;
  lim.StimRespSim = { } ;
  lim.SynthRfXywDeg = [ -Inf , +Inf ] ;
  
  % Pack input into struct
  v.Reward = Reward ;
  v.BarOriginDeg = BarOriginDeg ;
  v.TravelDiameterDeg = TravelDiameterDeg ;
  v.BarWidthHightDeg = BarWidthHightDeg ;
  v.BarSpeedDegPerSec = BarSpeedDegPerSec ;
  v.BarRGB = BarRGB ;
  v.FixTolDeg = FixTolDeg ;
  v.BaselineMs = BaselineMs ;
  v.RewardMinMs = RewardMinMs ;
  v.ScreenGamma = ScreenGamma ;
  v.ItiMinMs = ItiMinMs ;
  v.TdtHostPC = TdtHostPC ;
  v.TdtExperiment = TdtExperiment ;
  v.LaserCtrl = LaserCtrl ;
  v.TdtChannels = TdtChannels ;
  v.SpikeBuffer = SpikeBuffer ;
  v.MuaStartIndex = MuaStartIndex ;
  v.MuaBuffer = MuaBuffer ;
  v.VisualLatencyMs = VisualLatencyMs ;
  v.StimRespSim = StimRespSim ;
  v.SynthRfXywDeg = SynthRfXywDeg ;
  
  % Numeric variables
  for  N = fieldnames( v )' ; n = N{ 1 } ;
    
    % Empty field signals that we skip checks on these vars
    if  isempty( lim.( n ) )
      
      continue
      
    % Check type. First see if variable is expected to be Text
    elseif  iscellstr( lim.( n ) )
      
      % Check that variable is classic string
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



function  new = testrffig( evar , C , motiondir )
% 
% new = testrffig( evar , C , motiondir )
% 
% Generates synthetic data for testing creatRFfig without running ARCADE. C
% is obtained from ofig.grp.data.C when ofig = creatRFfig. motiondir can be
% any direction from C.dir.
% 
% Each channel has a RF that is centered at a different position.
% 
  

  %%% CONSTANTS %%%
  
  % RF radius, degrees
  rfrad = 0.75 ;
  
  % MUA signal increase over baseline
  muasig = 2 ;
  
  % Spiking baseline and response levels, spikes per ms
  spkbase = 10 / 1e3 ;
  spkresp = 60 / 1e3 ;
  

  %%% Make data %%%
  
  % Unit direction vector
  v = [ cosd( motiondir ) ; sind( motiondir ) ] ;
  
  % Bar start point, in degrees
  xy0 = evar.TravelDiameterDeg / 2 * -v'  +  evar.BarOriginDeg ;
  
  % Noise
  new.spk.time = C.time ;
  new.mua.time = C.time ;
  new.spk.data = rand( C.N.time , C.N.chan ) ;
  new.mua.data = abs( randn( C.N.time , C.N.chan ) ) ;
  
  % Channels
  for  ch = 1 : C.N.chan
    
    % RF location index
    i = ceil( ch / ( C.N.chan + 1 ) * C.N.space ) ;
    
    % RF location
    rf = [ C.x( i ) , C.y( i ) ] ;
    
    % Distance to centre
    d = ( rf - xy0 ) * v ;
    
    % Response onset and offset times, milliseconds. Add visual latency.
    ton  = max( ( d - rfrad ) / C.degperms , 0 )  +  C.vislat ;
    toff = min( ( d + rfrad ) / C.degperms , C.N.msperbar )  +  C.vislat ;
    
    % Find time bins with RF response to bar
    i = C.time >= ton  &  C.time <= toff ;
    
    % Elevate MUA response
    new.mua.data( i , ch ) = new.mua.data( i , ch ) + muasig ;
    
    % Time bins with response spikes
    new.spk.data( i , ch ) = new.spk.data( i , ch ) <= spkresp ;
    
    % Invert time index vector
    i = ~ i ;
    
    % Baseline spiking
    new.spk.data( i , ch ) = new.spk.data( i , ch ) <= spkbase ;
    
  end
  
  % Find time bins without a spike on any channel
  i = all( new.spk.data == 0 , 2 ) ;
  
  % Eliminate time bins without spikes
  new.spk.time( i , : ) = [ ] ;
  new.spk.data( i , : ) = [ ] ;
  
end % testrffig


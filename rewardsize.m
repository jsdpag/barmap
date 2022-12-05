
function  y = rewardsize( e , p , s , n , m )
% 
% ms = rewardsize( e , p , s , n , m )
% 
% Calculate size of reward on upcoming trial. Counts x, the number of
% contiguous trials prior to the upcoming trial that all had error code e.
% p is a probabiliy value in range [0,1]. n is the minimum allowable
% reward. And m is the maximum allowable reward.
% 
% The minimum reward as a function of x is defined to be:
% 
%   nx = ( m - n ) * ( 2 ./ ( 1 + exp( -s .* x ) ) - 1 )  +  n ;
% 
% Such that the reward is calculated as:
%   
%   y = p * ( m - nx )  +  nx
%   
% If p increases with the difficulty of the upcoming trial then the reward
% size will vary according to both the past (x) and expected upcoming (p)
% performance.
% 
% The shifted, scaled logistic function ensures that the reward size will
% saturate following a string of trials with outcome e. Also, upcoming
% difficulty (p) will have the greatest impact on reward size when
% following no trial with outcome e.
% 
% In effect, y is a uniformly distributed random variable in the range nx
% to m. The effect of increasing x is to reduce the effect of p.
% 
% NOTE: Must call rewardsize in the task script.
% 
  
  % Performance on previous trials
  prevdata = getPreviousTrialData ;
  
  % Previous trials without the desired error code
  err = prevdata.trialError( 1 : end - 1 ) ~= e ;
  
  % Count contiguous previous trials with error e
  x = numel( err ) - find( err , 1 , 'last' ) ;
  
    % N is [ ] on first trial in session
    if  isempty( x ) , x = 0 ; end
  
  % Minimum reward given past performance
  nx = ( m - n ) * ( 2 ./ ( 1 + exp( -s .* x ) ) - 1 )  +  n ;
  
  % Compute reward size for upcoming trial
  y = p * ( m - nx )  +  nx ;
  
end % rewardsize


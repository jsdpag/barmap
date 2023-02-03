
function  onEntry_generic( a )
%
% onEntry_generic( a )
% 
% Generic onEntry_generic function for ARCADE State objects. a must be a
% struct returned by onEntry_args( ).
% 
% Jackson Smith - May 2022 - Fries Lab (ESI Frankfurt)
% 
  
  % Point to logical flags
  flg = a.flg ;
  
  % *_entry event marker
  if  flg.Marker_entry , eventmarker( a.Marker_entry ) ; end

  % Begin stimulus grouping
  if  flg.grpstim , groupStimuli( 'start' ) , end
    
    % Dynamic change to stimulus property values
    if  flg.StimProp
      for  i = 1 : flg.StimProp , set( a.StimProp{ : , i } ) ; end
    end
    
    % Flip stimulus visibility for ...
    
      % ... just one stimulus
      if  flg.Stim == 1
        
        a.Stim.visible = ~ a.Stim.visible ;
        
      % Multiple stimuli
      elseif  flg.Stim
        
        for  S = a.Stim , s = S{ 1 } ; s.visible = ~ s.visible ; end
        
      end % flip visibility

    % Change state of photodiode
    if  flg.Photodiode , photodiode( a.Photodiode ) , end
    
    % Change colour of screen background
    if  flg.Background , StimServer.SetBackgroundColor( a.Background ); end
  
  % Finished stimulus grouping
  if  flg.grpstim , groupStimuli( 'end' ) , end
  
  % Reset events
  if  flg.Reset == 1
    a.Reset.reset ;
  elseif  flg.Reset
    for  i = 1 : numel( a.Reset ) , a.Reset( i ).reset , end
  end
  
  % Trigger events
  if  flg.Trigger == 1
    a.Trigger.trigger ;
  elseif  flg.Trigger
    for  i = 1 : numel( a.Trigger ) , a.Trigger( i ).trigger , end
  end
  
  % Time zero is defined
  if  flg.TimeZero
    
    % Measure elapsed time in seconds
    t = toc( a.TimeZero.startTic ) ;
    
    % Time store provided
    if  flg.RunTimeVal , a.RunTimeVal.value = t ; end
    
    % Format time string.
    ts = sprintf( '%7.3f' , t ) ;
  
  % Low-res, absolute time stamp
  else , ts = datestr( now , 'HH:MM:SS' ) ;
  end
  
  % Reward subject
  if  flg.Reward
    
    % Issue reward
    reward( a.Reward ) ;
    
    % Build reward string
    rs = sprintf( '%8sReward %dms\n' , '' , a.Reward ) ;
    
  % No reward, reward string is empty
  else , rs = '' ;
  end
  
  % Print state name with time stamp
  EchoServer.Write( sprintf( '%s %s\n%s' , ts , a.State.name , rs ) ) ;
  
  % Register trial error code on current trial
  if  flg.TrialError
    
    trialerror( a.TrialError )
    
    % SynapseAPI is live, send a run-time note with the trial outcome
    if  a.synflg  &&  ~ a.syn.setParameterValue( 'RecordingNotes' , ...
        'Note' , sprintf( 'Outcome %s' , a.TrialError ) )
        
      error( 'Failed to deliver run-time note to Synapse: Outcome %s' , ...
        a.TrialError )
      
    end
  end % Trial error code
  
  % *_start event marker
  if  flg.Marker_start , eventmarker( a.Marker_start ) ; end
  
end % onEntry_generic


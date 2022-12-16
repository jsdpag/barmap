
function  waitforuser( tit , fs , fmt , varargin )
% 
% waitforuser( title , fontsize , formatstring , <fmt args> )
% 
% Create a message box and pause execution until the user hits the OK
% button. fontsize is the size of the message, in points. The remaining
% input arguments are fed directly to sprintf( formatstring , <fmt args> ).
% 
% Jackson Smith - December 2022 - Fries Lab (ESI Frankfurt)
  
  % Format message for user
  msg = sprintf( [ '\\fontsize{%f}' , fmt , '\nHit OK when ready.' ] , ...
    fs , varargin{ : } ) ;

  % Tells message box how to parse the message
  s = struct( 'WindowStyle' , 'non-modal' , 'Interpreter' , 'tex' ) ;
  
  % Prompt user
  waitfor( msgbox( msg , tit , 'none' , s ) )
  
end % waitforuser


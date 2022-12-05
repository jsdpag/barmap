%% Mondrian Mask for visual task
%  Mod by Jackson Smith based on original by Martina Pandinelli

% Create new images here
destFolder = 'C:\Toolbox\Mondrian' ;

% Screen parameters
scrn.dist = 80.0 ; % subject distance eyes to screen centre, in cm
scrn.diag = 55.88; % Diagonal length of screen in cm
scrn.wpix = 1680 ; % Monitor width in pixels
scrn.hpix = 1050 ; % Monitor height in pixels

% Set general parameters
deg2pix = ( scrn.dist * tand( 1 ) ) * ...
          ( sqrt( scrn.wpix ^ 2 + scrn.hpix ^ 2 ) / scrn.diag ) ;
nRect = 200000 ;
nRep = 997 ; % Number of images I get in the end

% set monitor parameters
monitorH = 1 : scrn.hpix ; % values in pixels
monitorW = 1 : scrn.wpix ;
rectH = ceil( ( 0.1 : 0.01 : 0.5 ) * deg2pix ) ; % Round up to next pixel
rectW = ceil( ( 0.1 : 0.01 : 0.5 ) * deg2pix ) ; 

% Allocate RGB image
rgb = zeros( scrn.hpix , scrn.wpix , 3 ) ;

% Seed random number generator on current time, in an attempt to minimise
% the changes of creating the same images as in any previous run
rng( 'shuffle' ) ;

% Create nRep random ISI images
for i = 1 : nRep
    
    % New figure
    f = figure ;
    f.Units = 'pixels' ;
    f.Position( 3 : 4 ) = [ scrn.wpix , scrn.hpix ] ;
    
    % New axes
    ax = gca ;
    ax.NextPlot = 'add' ; % draw on top of existing contents
%     ax.Position = [ 0 , 0 , scrn.wpix , scrn.hpix ] ; % More formatting
    ax.PlotBoxAspectRatio = [ scrn.wpix , scrn.hpix , 1 ] ;
    axis( [ 0 , scrn.wpix , 0 , scrn.hpix ] )
    axis off
    ax.Units = 'normalized' ;
    ax.Position = [ 0 , 0 , 1 , 1 ] ;
    
    % Create nRect randomly sampled rectangles
    for rec = 1 : nRect
      
        % Randomly sample rectangle parameters (H)eight, (W)idth, (X)-axis
        % location, (Y)-axis location, and RGB colour.
        rctngls.H = rectH( ceil( numel( rectH ) * rand ) ) ;
        rctngls.W = rectW( ceil( numel( rectW ) * rand ) ) ;
        rctngls.X = monitorW( ceil( numel( monitorW ) * rand ) ) ;
        rctngls.Y = monitorH( ceil( numel( monitorH ) * rand ) ) ;
        rctngls.color = rand( 1 , 3 ) ; 
        
        % Create subscript indices for rgb matrix, do no exceed size of
        % each dimension
        X = rctngls.X : min( rctngls.X + rctngls.W , monitorW( end ) ) ;
        Y = rctngls.Y : min( rctngls.Y + rctngls.H , monitorH( end ) ) ;
        
        % Add new rectangle to image in memory. Note that the image( )
        % function maps rows of the array to rows of pixels, hence the Y
        % subscript going into dim 1. Repeat for each RGB value.
        rgb( Y , X , 1 ) = rctngls.color( 1 ) ;
        rgb( Y , X , 2 ) = rctngls.color( 2 ) ;
        rgb( Y , X , 3 ) = rctngls.color( 3 ) ;
        
    end % make rects
    
    % Make sure that image is rendered
    image( rgb )
    drawnow
    
    % Make image file
    print( f , fullfile( destFolder , [ 'mask' , num2str( i ) ] ) , ...
        '-r0' , '-dpng' , '-opengl' )
    
    % Kill old figure
    close( f )
    
end % new images

function highlight_blocks(blocks, background, foreground)
    
    %
    if nargin == 1
        background = 'Yellow';
    end
    if nargin <= 2
        foreground = 'Red';
    end
    
    % Convert input from cell array of paths to handles (if needed).
    blocks = inputToNumeric(blocks);
    
    %
    for i = 1:length(blocks)
        block = blocks(i);
        
        if strcmp(get_param(block, 'Type'), 'block')
            set_param(block, 'BackgroundColor', background)
            set_param(block, 'ForegroundColor', foreground)
        end
    end
end
function [oldCoreachedObjects, newCoreachedObjects] = Coreach_Diff(oldModel, newModel, direction)
    % COREACH_DIFF Identifies blocks and lines in oldModel and newModel that
    % potentially impact the components changed between the models.
    % 
    % Inputs:
    %   oldModel    The original version of a model.
    %   newModel    The new version of a model.
    %   direction   Indicates direction of analysis. Default: 1 for upstream
    %               analysis (Coreach), 0 for downstream analysis (Reach).
    %
    % Outputs:
    %   oldCoreachedObjects Handles of blocks and lines in oldModel that 
    %                       potentially impact the changes.
    %   newCoreachedObjects Handles of blocks and lines in newModel that 
    %                       potentially impact the changes.
    % 
    
    if nargin < 3
        direction = 1; % Upstream trace (Coreach).
    end
    
    [oldCoreachedObjects, newCoreachedObjects] = Reach_Diff(oldModel, newModel, direction);
    
end
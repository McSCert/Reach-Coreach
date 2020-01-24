function [oldCoreachedObjects, newCoreachedObjects, diffTree] = Coreach_Diff(oldModel, newModel, highlight, direction, diffTree)
    % COREACH_DIFF Identifies blocks and lines in oldModel and newModel that
    % potentially impact the components changed between the models.
    % 
    % Inputs:
    %   oldModel    The original version of a model.
    %   newModel    The new version of a model.
    %   highlight   [Optional] Indicates whether or not to highlight the
    %               differences and impacts. Default: 1 to highlight differences
    %               with DarkGreen foreground and Red background and highlight
    %               impacts of those differences with Yellow foreground and Red
    %               background; use 0 for no highlighting.
    %   direction   [Optional] Indicates direction of analysis. Default: 1 for
    %               upstream analysis (Coreach), 0 for downstream analysis
    %               (Reach).
    %   diffTree    [Optional] Result of:
    %                   slxmlcomp.compare(oldModel,newModel)
    %               Only used to speed up results.
    %
    % Outputs:
    %   oldCoreachedObjects Handles of blocks and lines in oldModel that 
    %                       potentially impact the changes.
    %   newCoreachedObjects Handles of blocks and lines in newModel that 
    %                       potentially impact the changes.
    %   diffTree            Tree generated from:
    %                           slxmlcomp.compare(oldModel,newModel)
    %                       Can be passed back in on future calls using the same
    %                       models to speed up results.
    % 
    
    % Input handling.
    if nargin < 3
        highlight = 1;
    end
    if nargin < 4
        direction = 1; % Upstream trace (Coreach).
    end
    if nargin < 5
        % Get comparison tree.
        diffTree = slxmlcomp.compare(oldModel, newModel);
    end
    
    %
    [oldCoreachedObjects, newCoreachedObjects] = Reach_Diff(oldModel, newModel, highlight, direction, diffTree);
    
end
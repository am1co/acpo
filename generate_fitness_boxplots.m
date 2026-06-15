function generate_fitness_boxplots(data_dir)
    
    % Define target functions for each suite
    target_functions.CEC2017 = {'F1', 'F4', 'F11', 'F21'};
    target_functions.CEC2022 = {'F1', 'F2', 'F6', 'F10'};
    
    % List all CSV files in the data directory
    file_list = dir(fullfile(data_dir, '*.csv'));
    
    if isempty(file_list)
        warning('No CSV files found in %s', data_dir);
        return;
    end
    
    % Extract unique optimizers and suites from filenames
    optimizers = {};
    suites = {};
    
    for i = 1:length(file_list)
        filename = file_list(i).name;
        [optimizer, suite, ~] = parse_filename(filename);
        
        if ~ismember(optimizer, optimizers)
            optimizers{end+1} = optimizer;
        end
        if ~ismember(suite, suites)
            suites{end+1} = suite;
        end
    end
    
    % Sort optimizers by predefined groups
    optimizers = sort_optimizers_by_group(optimizers);
    
    % Create output directory if it doesn't exist
    output_dir = 'out/boxplots';
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end
    
    % Process each suite and target function
    for s = 1:length(suites)
        suite = suites{s};
        
        % Check if target functions exist for this suite
        if ~isfield(target_functions, suite)
            continue;
        end
        
        target_funcs = target_functions.(suite);
        
        % Create boxplots for each target function
        for f = 1:length(target_funcs)
            func = target_funcs{f};
            
            % Collect data from all optimizers for this function
            boxplot_data = {};
            valid_optimizers = {};
            
            for o = 1:length(optimizers)
                optimizer = optimizers{o};
                filename = sprintf('%s_%s_%s.csv', optimizer, suite, func);
                filepath = fullfile(data_dir, filename);
                
                if isfile(filepath)
                    % Read CSV file and extract last non-zero column
                    data = readmatrix(filepath);
                    if ~isempty(data)
                        % Extract final fitness values from last non-zero column
                        final_values = extract_last_nonzero_column(data);
                        if ~isempty(final_values)
                            boxplot_data{end+1} = final_values;
                            valid_optimizers{end+1} = optimizer;
                        end
                    end
                end
            end
            
            % Create boxplot if data is available
            if ~isempty(boxplot_data)
                create_boxplot(boxplot_data, valid_optimizers, suite, func, output_dir);
            end
        end
    end
end

function [optimizer, suite, func] = parse_filename(filename)
    % PARSE_FILENAME Extracts optimizer, suite, and function from filename
    %   Input: filename (string) in format <OptimizerName>_<Suite>_<Function>.csv
    %   Output: optimizer, suite, func (strings)
    
    % Remove .csv extension
    filename = filename(1:end-4);
    
    % Split by underscore
    parts = strsplit(filename, '_');
    
    if length(parts) < 3
        optimizer = '';
        suite = '';
        func = '';
        return;
    end
    
    % Last part is the function (e.g., 'F1')
    func = parts{end};
    
    % Second to last is the suite (e.g., 'CEC2017')
    suite = parts{end-1};
    
    % Everything else is the optimizer name (handles multi-word optimizer names)
    optimizer = strjoin(parts(1:end-2), '_');
end

function create_boxplot(data, optimizer_names, suite, func, output_dir)
    % CREATE_BOXPLOT Generates a single boxplot for the given data
    %   Input:
    %       data: cell array of fitness value vectors
    %       optimizer_names: cell array of optimizer names
    %       suite: benchmark suite name (e.g., 'CEC2017')
    %       func: function name (e.g., 'F1')
    %       output_dir: directory to save the figure (optional)
    
    % Create new figure
    figure('Position', [100, 100, 1000, 600]);
    
    % Prepare data for boxplot: convert cell array to padded matrix with grouping variable
    max_runs = 0;
    for i = 1:length(data)
        max_runs = max(max_runs, length(data{i}));
    end
    
    % Create padded matrix and grouping variable
    boxplot_matrix = nan(max_runs, length(data));
    all_data_flat = [];
    
    for i = 1:length(data)
        n_runs = length(data{i});
        boxplot_matrix(1:n_runs, i) = data{i}(:);
        all_data_flat = [all_data_flat; data{i}(:)];
    end
    
    % Create boxplot with grouping
    bp = boxplot(boxplot_matrix);
    
    % Set boxplot line width
    set(bp, 'LineWidth', 1.5);
    
    % Set x-axis labels to optimizer names
    % Convert underscores to spaces in optimizer names for display
    display_names = cellfun(@(x) strrep(x, '_', ' '), optimizer_names, 'UniformOutput', false);
    set(gca, 'XTickLabel', display_names);
    
    % Set labels and title
    xlabel('Algorithm', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Fitness Value', 'FontSize', 12, 'FontWeight', 'bold');
    title(sprintf('%s - %s', suite, func), 'FontSize', 14, 'FontWeight', 'bold');
    
    % Rotate x-axis labels to prevent overlapping
    ax = gca;
    ax.XTickLabelRotation = 45;
    
    % Improve layout
    grid on;
    grid minor;
    ax.GridAlpha = 0.15;
    
    % Set font properties
    ax.FontSize = 10;
    ax.FontName = 'Arial';
    
    % Tight layout
    drawnow;
    pause(0.1);  % Allow figure to render before adjusting
    
    % Auto-adjust layout to prevent label cutoff
    set(gca, 'LooseInset', get(gca, 'TightInset') + [0, 0.05, 0, 0]);
    
    % Apply scaling to handle outliers and make boxes visible
    % Pass grouped data instead of flattened to calculate IQR per-optimizer
    scaling_method = apply_axis_scaling(data);
    
    % Update y-axis label to reflect scaling method (only if non-linear)
    if strcmp(scaling_method, 'Linear')
        ylabel('Fitness Value', 'FontSize', 12, 'FontWeight', 'bold');
    else
        ylabel(sprintf('Fitness Value (%s)', scaling_method), 'FontSize', 12, 'FontWeight', 'bold');
    end
    
    % Save figure if output directory is provided
    if nargin >= 5 && ~isempty(output_dir)
        filename = sprintf('Boxplots_%s_%s.png', suite, func);
        filepath = fullfile(output_dir, filename);
        saveas(gcf, filepath);
        fprintf('Saved: %s\n', filepath);
    end
end

function scaling_method = apply_axis_scaling(data_cells)
    % Y-axis scaling to handle outliers
    % Now calculates limits based on individual algorithm variances to prevent cutoff
    
    % Extract all data into a flat array for global min/max checks
    all_data = [];
    for i = 1:length(data_cells)
        all_data = [all_data; data_cells{i}(:)];
    end
    all_data = all_data(~isnan(all_data));
    
    if isempty(all_data)
        scaling_method = 'Linear';
        return;
    end
    
    min_val = min(all_data);
    max_val = max(all_data);
    
    % If data is positive and spans at least 1 order of magnitude (10x difference)
    if min_val > 0 && (max_val / min_val) >= 10
        set(gca, 'YScale', 'log');
        scaling_method = 'Log Scale';
        
    else
        % Calculate safe limits by checking EVERY individual algorithm's box
        max_box_top = min_val; 
        min_box_bot = max_val;
        
        for i = 1:length(data_cells)
            group_data = data_cells{i}(~isnan(data_cells{i}));
            if ~isempty(group_data)
                q1 = quantile(group_data, 0.25);
                q3 = quantile(group_data, 0.75);
                iqr = q3 - q1;
                
                % Calculate the highest and lowest non-outlier whiskers for this specific group
                group_upper = q3 + 1.5 * iqr;
                group_lower = q1 - 1.5 * iqr;
                
                % Update the global safe boundaries
                max_box_top = max(max_box_top, group_upper);
                min_box_bot = min(min_box_bot, group_lower);
            end
        end
        
        % Add a 10% visual padding above the highest overall whisker
        y_range = max_box_top - min_box_bot;
        if y_range == 0
            y_range = max_box_top * 0.01; % Fallback if perfectly flat
        end
        
        lower_lim = max(min_val, min_box_bot - 0.1 * y_range);
        upper_lim = min(max_val, max_box_top + 0.2 * y_range);
        
        % Only apply the zoom if it actually crops extreme upper outliers
        if upper_lim < max_val * 0.98
            ylim([lower_lim, upper_lim]);
            scaling_method = 'Linear Zoom';
        else
            scaling_method = 'Linear';
        end
    end
end

function final_values = extract_last_nonzero_column(data)
    if isempty(data)
        final_values = [];
        return;
    end
    
    % Extract the last column
    final_values = data(:, end);
end

function parts = strsplit(str, delimiter)
    
    parts = {};
    current_pos = 1;
    
    while current_pos <= length(str)
        delimiter_pos = strfind(str(current_pos:end), delimiter);
        
        if isempty(delimiter_pos)
            % No more delimiters, add the rest
            parts{end+1} = str(current_pos:end);
            break;
        else
            % Add substring up to delimiter
            end_pos = current_pos + delimiter_pos(1) - 2;
            parts{end+1} = str(current_pos:end_pos);
            current_pos = end_pos + 1 + length(delimiter);
        end
    end
end

function sorted_optimizers = sort_optimizers_by_group(optimizers)
    % SORT_OPTIMIZERS_BY_GROUP Sorts optimizers into predefined groups
    %   Groups: Proposed/Baseline, Classical, Recent, CEC Winners
    %   Within each group, algorithms are sorted alphabetically
    
    % Define algorithm groups
    proposed_baseline = {'ACPO', 'CPO'};
    classical = {'ABC', 'PSO', 'SSA'};
    recent = {'GBO', 'MPA', 'SMA'};
    cec_winners = {'LSHADE', 'LSHADE_SPACMA', 'SHADE'};
    
    % Initialize sorted list
    sorted_optimizers = {};
    
    % Helper function to add group members that exist in optimizers
    for i = 1:length(proposed_baseline)
        for j = 1:length(optimizers)
            if strcmp(optimizers{j}, proposed_baseline{i})
                sorted_optimizers{end+1} = optimizers{j};
            end
        end
    end
    
    for i = 1:length(classical)
        for j = 1:length(optimizers)
            if strcmp(optimizers{j}, classical{i})
                sorted_optimizers{end+1} = optimizers{j};
            end
        end
    end
    
    for i = 1:length(recent)
        for j = 1:length(optimizers)
            if strcmp(optimizers{j}, recent{i})
                sorted_optimizers{end+1} = optimizers{j};
            end
        end
    end
    
    for i = 1:length(cec_winners)
        for j = 1:length(optimizers)
            if strcmp(optimizers{j}, cec_winners{i})
                sorted_optimizers{end+1} = optimizers{j};
            end
        end
    end
    
    % Add any remaining algorithms not in predefined groups
    for j = 1:length(optimizers)
        if ~ismember(optimizers{j}, sorted_optimizers)
            sorted_optimizers{end+1} = optimizers{j};
        end
    end
end

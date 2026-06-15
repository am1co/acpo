function generate_all_bar_graphs(csv_file)
    % Extracts metrics from a single CSV file
    % Generates: SD, Rank, and OE bar graphs with consistent color schemes
    
    % Check if CSV file is provided, otherwise use default path
    if nargin < 1
        csv_file = 'in/algo comparison/Algorithm_Comparison_Fitness.csv';
    end
    
    % Verify file exists
    if ~isfile(csv_file)
        error('CSV file not found: %s', csv_file);
    end
    
    % Create output directories if they don't exist
    output_dirs = {'out/sds/', 'out/rank/', 'out/oe/'};
    for i = 1:length(output_dirs)
        if ~isfolder(output_dirs{i})
            mkdir(output_dirs{i});
        end
    end
    
    fprintf('Parsing CSV file: %s\n', csv_file);
    
    % Parse the CSV file to extract all data
    [optimizer_names, functions, suite_data] = parse_fitness_csv(csv_file);
    
    if isempty(optimizer_names)
        error('Failed to parse CSV file');
    end
    
    fprintf('Found %d optimizers and %d functions\n', length(optimizer_names), size(suite_data, 1));
    
    % Extract metric data by suite
    % suite_data structure: each row is [func_name, suite, AF_vals, Rank_vals, RS_vals, SD_vals]
    % where vals are 1xN arrays for each optimizer
    
    % Get unique suites
    suites = unique({suite_data.suite});
    
    % Generate SD bar graphs
    fprintf('\n--- Generating SD Bar Graphs ---\n');
    generate_sd_bar_graphs_from_data(suite_data, optimizer_names, suites);
    
    % Generate Rank bar graphs
    fprintf('\n--- Generating Rank Bar Graphs ---\n');
    generate_rank_bar_graphs_from_data(suite_data, optimizer_names, suites);
    
    % Generate OE bar graphs
    fprintf('\n--- Generating OE Bar Graphs ---\n');
    generate_oe_bar_graphs_from_data(suite_data, optimizer_names, suites);
    
    fprintf('\nAll bar graph generation complete.\n');
end

%% Main parsing function
function [optimizer_names, functions, suite_data] = parse_fitness_csv(csv_file)
    % Parse the Algorithm_Comparison_Fitness.csv file
    % Format: Row 1 = optimizer names, Row 2 = metrics, Row 3 = header, Row 4+ = data
    
    try
        % Read raw cell array
        raw_data = readcell(csv_file, 'NumHeaderLines', 0);
        
        % Extract headers
        optimizer_row = raw_data(1, :);
        metric_row = raw_data(2, :);
        
        % Extract optimizer names and find metric column positions
        [optimizer_names, metric_indices] = extract_optimizers_and_metrics(optimizer_row, metric_row);
        
        if isempty(optimizer_names)
            error('Could not extract optimizer names from CSV');
        end
        
        % Parse data rows (starting from row 4)
        functions = {};
        suite_data = struct([]);
        row_count = 0;
        
        for row_idx = 4:size(raw_data, 1)
            % Get first column (function name)
            if row_idx > size(raw_data, 1) || 1 > size(raw_data, 2)
                continue;
            end
            
            func_name_cell = raw_data{row_idx, 1};
            
            % Skip empty rows
            if isempty(func_name_cell)
                continue;
            end
            
            func_name = string(func_name_cell);
            
            % Skip non-CEC rows (e.g., headers)
            if ~(contains(func_name, 'CEC', 'IgnoreCase', true))
                continue;
            end
            
            % Determine suite from function name
            if contains(func_name, 'CEC2017', 'IgnoreCase', true)
                suite = 'CEC2017';
            elseif contains(func_name, 'CEC2022', 'IgnoreCase', true)
                suite = 'CEC2022';
            else
                continue;
            end
            
            % Extract metric values
            af_vals = [];
            rank_vals = [];
            rs_vals = [];
            sd_vals = [];
            has_valid_data = false;
            
            for opt_idx = 1:length(optimizer_names)
                % Average Fitness
                af_col = metric_indices.af(opt_idx);
                af_val = get_numeric_value(raw_data, row_idx, af_col);
                af_vals = [af_vals, af_val];
                
                % Rank
                rank_col = metric_indices.rank(opt_idx);
                rank_val = get_numeric_value(raw_data, row_idx, rank_col);
                rank_vals = [rank_vals, rank_val];
                
                % Rank-Sum
                rs_col = metric_indices.rs(opt_idx);
                rs_val = get_numeric_value(raw_data, row_idx, rs_col);
                rs_vals = [rs_vals, rs_val];
                
                % Standard Deviation
                sd_col = metric_indices.sd(opt_idx);
                sd_val = get_numeric_value(raw_data, row_idx, sd_col);
                sd_vals = [sd_vals, sd_val];
                
                % Check if we have at least one valid data point
                if ~isnan(af_val) || ~isnan(rank_val) || ~isnan(sd_val)
                    has_valid_data = true;
                end
            end
            
            % Only add row if it has valid data
            if has_valid_data
                row_count = row_count + 1;
                functions{end+1} = char(func_name);
                
                entry = struct();
                entry.func_name = char(func_name);
                entry.suite = suite;
                entry.af = af_vals;
                entry.rank = rank_vals;
                entry.rs = rs_vals;
                entry.sd = sd_vals;
                
                if isempty(suite_data)
                    suite_data = entry;
                else
                    suite_data(end+1) = entry;
                end
            end
        end
        
        fprintf('  Parsed %d data rows successfully\n', row_count);
        
    catch ME
        fprintf('Error parsing CSV: %s\n', ME.message);
        optimizer_names = [];
        functions = [];
        suite_data = struct([]);
    end
end

%% Extract optimizers and metric column indices
function [optimizer_names, metric_indices] = extract_optimizers_and_metrics(optimizer_row, metric_row)
    % Extract optimizer names and find column indices for each metric
    
    optimizer_names = {};
    af_indices = [];
    rank_indices = [];
    rs_indices = [];
    sd_indices = [];
    
    % Process columns starting from index 2 (skip "Optimizer"/"Metric" column)
    for col_idx = 2:min(length(optimizer_row), length(metric_row))
        optimizer_name = string(strtrim(optimizer_row{col_idx}));
        metric_name = string(strtrim(metric_row{col_idx}));
        
        % Skip empty columns
        if strlength(optimizer_name) == 0 || strlength(metric_name) == 0
            continue;
        end
        
        % Check if we've seen this optimizer before
        if ~ismember(optimizer_name, optimizer_names)
            optimizer_names{end+1} = char(optimizer_name);
        end
        
        % Find which optimizer index this column belongs to
        opt_idx = find(strcmp(optimizer_names, char(optimizer_name)));
        
        % Categorize by metric
        if contains(metric_name, 'Average Fitness', 'IgnoreCase', true)
            af_indices(opt_idx) = col_idx;
        elseif contains(metric_name, 'Rank', 'IgnoreCase', true) && ~contains(metric_name, 'Rank-Sum', 'IgnoreCase', true)
            rank_indices(opt_idx) = col_idx;
        elseif contains(metric_name, 'Rank-Sum', 'IgnoreCase', true)
            rs_indices(opt_idx) = col_idx;
        elseif contains(metric_name, 'Standard Deviation', 'IgnoreCase', true)
            sd_indices(opt_idx) = col_idx;
        end
    end
    
    % Ensure all indices are properly sized
    n_opts = length(optimizer_names);
    if length(af_indices) < n_opts
        af_indices(n_opts) = 0;
    end
    if length(rank_indices) < n_opts
        rank_indices(n_opts) = 0;
    end
    if length(rs_indices) < n_opts
        rs_indices(n_opts) = 0;
    end
    if length(sd_indices) < n_opts
        sd_indices(n_opts) = 0;
    end
    
    metric_indices = struct();
    metric_indices.af = af_indices;
    metric_indices.rank = rank_indices;
    metric_indices.rs = rs_indices;
    metric_indices.sd = sd_indices;
end

%% Helper to extract numeric value from cell
function val = get_numeric_value(data, row, col)
    if col == 0 || col > size(data, 2)
        val = NaN;
        return;
    end
    
    cell_val = data{row, col};
    
    if isnumeric(cell_val)
        val = cell_val;
    elseif isstring(cell_val) || ischar(cell_val)
        try
            val = str2double(cell_val);
        catch
            val = NaN;
        end
    else
        val = NaN;
    end
end

%% SD Bar Graph Generation
function generate_sd_bar_graphs_from_data(suite_data, optimizer_names, suites)
    output_dir = 'out/sds/';
    
    for suite_idx = 1:length(suites)
        suite_name = suites{suite_idx};
        
        % Filter data for this suite
        suite_mask = strcmp({suite_data.suite}, suite_name);
        suite_subset = suite_data(suite_mask);
        
        if isempty(suite_subset)
            continue;
        end
        
        % Extract SD values
        sd_matrix = [];
        for i = 1:length(suite_subset)
            sd_matrix = [sd_matrix; suite_subset(i).sd];
        end
        
        % Generate the plot
        create_sd_bar_graph_with_colors(sd_matrix, optimizer_names, suite_name, output_dir);
    end
end

%% Rank Bar Graph Generation
function generate_rank_bar_graphs_from_data(suite_data, optimizer_names, suites)
    output_dir = 'out/rank/';
    
    for suite_idx = 1:length(suites)
        suite_name = suites{suite_idx};
        
        % Filter data for this suite
        suite_mask = strcmp({suite_data.suite}, suite_name);
        suite_subset = suite_data(suite_mask);
        
        if isempty(suite_subset)
            continue;
        end
        
        % Extract Rank values
        rank_matrix = [];
        for i = 1:length(suite_subset)
            rank_matrix = [rank_matrix; suite_subset(i).rank];
        end
        
        % Generate the plot
        create_rank_bar_graph_with_colors(rank_matrix, optimizer_names, suite_name, output_dir);
    end
end

%% OE Bar Graph Generation
function generate_oe_bar_graphs_from_data(suite_data, optimizer_names, suites)
    output_dir = 'out/oe/';
    
    % Hardcoded optimal fitness values
    F_optimal = struct(...
        'CEC2017', struct(...
            'F1', 100, 'F2', 200, 'F3', 300, 'F4', 400, 'F5', 500, ...
            'F6', 600, 'F7', 700, 'F8', 800, 'F9', 900, 'F10', 1000, ...
            'F11', 1100, 'F12', 1200, 'F13', 1300, 'F14', 1400, 'F15', 1500, ...
            'F16', 1600, 'F17', 1700, 'F18', 1800, 'F19', 1900, 'F20', 2000, ...
            'F21', 2100, 'F22', 2200, 'F23', 2300, 'F24', 2400, 'F25', 2500, ...
            'F26', 2600, 'F27', 2700, 'F28', 2800, 'F29', 2900, 'F30', 3000), ...
        'CEC2022', struct(...
            'F1', 300, 'F2', 400, 'F3', 600, 'F4', 800, 'F5', 900, ...
            'F6', 1800, 'F7', 2000, 'F8', 2200, 'F9', 2300, 'F10', 2400, ...
            'F11', 2600, 'F12', 2700));
    
    for suite_idx = 1:length(suites)
        suite_name = suites{suite_idx};
        
        % Filter data for this suite
        suite_mask = strcmp({suite_data.suite}, suite_name);
        suite_subset = suite_data(suite_mask);
        
        if isempty(suite_subset)
            continue;
        end
        
        % Calculate OE values from Average Fitness
        oe_matrix = [];
        F_opt_struct = F_optimal.(suite_name);
        
        for i = 1:length(suite_subset)
            func_name = suite_subset(i).func_name;
            
            % Extract function ID from name
            if contains(func_name, 'CEC2017', 'IgnoreCase', true)
                func_id = strrep(func_name, 'CEC2017_', '');
            else
                func_id = strrep(func_name, 'CEC2022_', '');
            end
            
            % Get optimal value
            if isfield(F_opt_struct, func_id)
                F_opt = F_opt_struct.(func_id);
                % OE = abs(F_opt - F_avg)
                oe_vals = abs(F_opt - suite_subset(i).af);
                oe_matrix = [oe_matrix; oe_vals];
            end
        end
        
        if ~isempty(oe_matrix)
            % Generate the plot
            create_oe_bar_graph_with_colors(oe_matrix, optimizer_names, suite_name, output_dir);
        end
    end
end

%% SD Bar Graph with Color Categories
function create_sd_bar_graph_with_colors(sd_matrix, optimizer_names, suite, output_dir)
    % Normalize SD values (Min-Max normalization per row)
    normalized_matrix = normalize_sd_matrix(sd_matrix);
    
    % Calculate mean normalized SD per algorithm
    mean_sd = mean(normalized_matrix, 1);
    
    % Sort algorithms by category and within categories
    [algorithms_sorted, indices, categories] = sort_algorithms_by_category(optimizer_names);
    mean_sd_sorted = mean_sd(indices);
    
    % Define color scheme: DARKER hues
    colors = define_colors_darker();
    
    % Create figure
    fig = figure('Visible', 'off', 'Units', 'normalized', 'Position', [0, 0, 1, 1]);
    ax = axes('Parent', fig);
    
    % Create color array based on categories
    bar_colors = get_color_array(categories, colors);
    
    % Create bars with individual colors
    hold(ax, 'on');
    for i = 1:length(mean_sd_sorted)
        bar(ax, i, mean_sd_sorted(i), 'FaceColor', bar_colors(i, :), 'EdgeColor', 'black', 'LineWidth', 1.5);
    end
    hold(ax, 'off');
    
    % Set X-axis labels and rotation
    display_names = cellfun(@(x) strrep(x, '_', ' '), algorithms_sorted, 'UniformOutput', false);
    set(ax, 'XTick', 1:length(display_names), 'XTickLabel', display_names, 'XTickLabelRotation', 45);
    
    % Set Y-axis properties
    max_sd = max(mean_sd_sorted);
    set(ax, 'YLim', [0, max_sd * 1.15], 'FontSize', 11, 'FontName', 'Arial');
    
    % Labels and title
    xlabel(ax, 'Algorithm', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold');
    ylabel(ax, 'Normalized Averaged SD', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold');
    title(ax, sprintf('%s - Standard Deviation', suite), 'FontSize', 14, 'FontName', 'Arial', 'FontWeight', 'bold');
    
    % Grid
    grid(ax, 'on');
    set(ax, 'GridLineStyle', '--', 'GridAlpha', 0.3, 'Layer', 'bottom');
    
    % Value labels on bars
    for i = 1:length(mean_sd_sorted)
        text(i, mean_sd_sorted(i) + (max_sd * 0.02), sprintf('%.4f', mean_sd_sorted(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 10, 'FontName', 'Arial', 'FontWeight', 'bold');
    end
    
    % Add legend
    add_category_legend(ax, colors);
    
    % Save figure
    set(fig, 'Position', [100, 100, 1200, 700]);
    output_filename = sprintf('Bar_SD_%s.png', suite);
    output_path = fullfile(output_dir, output_filename);
    
    try
        exportgraphics(fig, output_path, 'Resolution', 150);
    catch
        set(fig, 'PaperUnits', 'inches');
        set(fig, 'PaperSize', [10, 7]);
        set(fig, 'PaperPosition', [0, 0, 10, 7]);
        print(fig, output_path, '-dpng', '-r150');
    end
    
    fprintf('  Saved: %s\n', output_filename);
    close(fig);
end

%% Rank Bar Graph with Color Categories
function create_rank_bar_graph_with_colors(rank_matrix, optimizer_names, suite, output_dir)
    % Calculate averaged ranks
    averaged_ranks = mean(rank_matrix, 1);
    
    % Sort algorithms by category
    [algorithms_sorted, indices, categories] = sort_algorithms_by_category(optimizer_names);
    averaged_ranks_sorted = averaged_ranks(indices);
    
    % Define color scheme: PASTEL hues
    colors = define_colors_pastel();
    
    % Create figure
    fig = figure('Visible', 'off', 'Units', 'normalized', 'Position', [0, 0, 1, 1]);
    ax = axes('Parent', fig);
    
    % Create color array based on categories
    bar_colors = get_color_array(categories, colors);
    
    % Create bars
    hold(ax, 'on');
    for i = 1:length(averaged_ranks_sorted)
        bar(ax, i, averaged_ranks_sorted(i), 'FaceColor', bar_colors(i, :), 'EdgeColor', 'black', 'LineWidth', 1.5);
    end
    hold(ax, 'off');
    
    % Set X-axis labels
    display_names = cellfun(@(x) strrep(x, '_', ' '), algorithms_sorted, 'UniformOutput', false);
    set(ax, 'XTick', 1:length(display_names), 'XTickLabel', display_names, 'XTickLabelRotation', 45);
    
    % Set Y-axis properties
    max_rank = max(averaged_ranks_sorted);
    set(ax, 'YLim', [0, max_rank * 1.15], 'FontSize', 11, 'FontName', 'Arial');
    
    % Labels and title
    xlabel(ax, 'Algorithm', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold');
    ylabel(ax, 'Averaged Rank', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold');
    title(ax, sprintf('%s - Averaged Rank', suite), 'FontSize', 14, 'FontName', 'Arial', 'FontWeight', 'bold');
    
    % Grid
    grid(ax, 'on');
    set(ax, 'GridLineStyle', '--', 'GridAlpha', 0.3, 'Layer', 'bottom');
    
    % Value labels
    for i = 1:length(averaged_ranks_sorted)
        text(i, averaged_ranks_sorted(i) + (max_rank * 0.02), sprintf('%.4f', averaged_ranks_sorted(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 10, 'FontName', 'Arial', 'FontWeight', 'bold');
    end
    
    % Add legend
    add_category_legend(ax, colors);
    
    % Save figure
    set(fig, 'Position', [100, 100, 1200, 700]);
    output_filename = sprintf('Bar_Rank_%s.png', suite);
    output_path = fullfile(output_dir, output_filename);
    
    try
        exportgraphics(fig, output_path, 'Resolution', 150);
    catch
        set(fig, 'PaperUnits', 'inches');
        set(fig, 'PaperSize', [10, 7]);
        set(fig, 'PaperPosition', [0, 0, 10, 7]);
        print(fig, output_path, '-dpng', '-r150');
    end
    
    fprintf('  Saved: %s\n', output_filename);
    close(fig);
end

%% OE Bar Graph with Color Categories
function create_oe_bar_graph_with_colors(oe_matrix, optimizer_names, suite, output_dir)
    % Calculate mean OE per optimizer
    mean_oe = mean(oe_matrix, 1);
    
    % Normalize OE values (Min-Max)
    min_val = min(mean_oe);
    max_val = max(mean_oe);
    
    if max_val > min_val
        normalized_oe = (mean_oe - min_val) / (max_val - min_val);
    else
        normalized_oe = mean_oe;
    end
    
    % Sort algorithms by category
    [algorithms_sorted, indices, categories] = sort_algorithms_by_category(optimizer_names);
    normalized_oe_sorted = normalized_oe(indices);
    
    % Define color scheme: VIBRANT hues
    colors = define_colors_vibrant();
    
    % Create figure
    fig = figure('Visible', 'off', 'Units', 'normalized', 'Position', [0, 0, 1, 1]);
    ax = axes('Parent', fig);
    
    % Create color array based on categories
    bar_colors = get_color_array(categories, colors);
    
    % Create bars
    hold(ax, 'on');
    for i = 1:length(normalized_oe_sorted)
        bar(ax, i, normalized_oe_sorted(i), 'FaceColor', bar_colors(i, :), 'EdgeColor', 'black', 'LineWidth', 1.5);
    end
    hold(ax, 'off');
    
    % Set X-axis labels
    display_names = cellfun(@(x) strrep(x, '_', ' '), algorithms_sorted, 'UniformOutput', false);
    set(ax, 'XTick', 1:length(display_names), 'XTickLabel', display_names, 'XTickLabelRotation', 45);
    
    % Set Y-axis properties
    set(ax, 'YLim', [0, 1.15], 'FontSize', 11, 'FontName', 'Arial');
    
    % Labels and title
    xlabel(ax, 'Algorithm', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold');
    ylabel(ax, 'Normalized Averaged OE', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold');
    title(ax, sprintf('%s - Overall Effectiveness', suite), 'FontSize', 14, 'FontName', 'Arial', 'FontWeight', 'bold');
    
    % Grid
    grid(ax, 'on');
    set(ax, 'GridLineStyle', '--', 'GridAlpha', 0.3, 'Layer', 'bottom');
    
    % Value labels
    for i = 1:length(normalized_oe_sorted)
        text(i, normalized_oe_sorted(i) + 0.02, sprintf('%.4f', normalized_oe_sorted(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 10, 'FontName', 'Arial', 'FontWeight', 'bold');
    end
    
    % Add legend
    add_category_legend(ax, colors);
    
    % Save figure
    set(fig, 'Position', [100, 100, 1200, 700]);
    output_filename = sprintf('Bar_OE_%s.png', suite);
    output_path = fullfile(output_dir, output_filename);
    
    try
        exportgraphics(fig, output_path, 'Resolution', 150);
    catch
        set(fig, 'PaperUnits', 'inches');
        set(fig, 'PaperSize', [10, 7]);
        set(fig, 'PaperPosition', [0, 0, 10, 7]);
        print(fig, output_path, '-dpng', '-r150');
    end
    
    fprintf('  Saved: %s\n', output_filename);
    close(fig);
end

%% Color Definition Functions
function colors = define_colors_darker()
    % Darker hues for SD bar graphs
    colors = struct();
    colors.proposed = [0.0, 0.3, 0.7];      % Dark blue
    colors.classical = [0.7, 0.35, 0.0];    % Dark orange
    colors.recent = [0.0, 0.5, 0.0];        % Dark green
    colors.cec_winners = [0.6, 0.0, 0.4];   % Dark magenta
end

function colors = define_colors_pastel()
    % Pastel hues for Rank bar graphs
    colors = struct();
    colors.proposed = [0.6, 0.8, 1.0];      % Light blue
    colors.classical = [1.0, 0.8, 0.6];     % Light orange
    colors.recent = [0.6, 1.0, 0.6];        % Light green
    colors.cec_winners = [1.0, 0.6, 1.0];   % Light magenta
end

function colors = define_colors_vibrant()
    % Vibrant hues for OE bar graphs
    colors = struct();
    colors.proposed = [0.0, 0.5, 1.0];      % Bright blue
    colors.classical = [1.0, 0.6, 0.0];     % Bright orange
    colors.recent = [0.0, 1.0, 0.0];        % Bright green
    colors.cec_winners = [1.0, 0.0, 0.8];   % Bright magenta
end

%% Helper function to get color array from categories
function bar_colors = get_color_array(categories, colors)
    bar_colors = [];
    for i = 1:length(categories)
        cat = categories{i};
        bar_colors = [bar_colors; colors.(cat)];
    end
end

%% Add legend for categories
function add_category_legend(ax, colors)
    legend_handles = [];
    category_names = {'Proposed and Baseline', 'Classical', 'Recent', 'CEC Winners'};
    category_keys = {'proposed', 'classical', 'recent', 'cec_winners'};
    
    for i = 1:length(category_keys)
        cat_key = category_keys{i};
        color = colors.(cat_key);
        h = patch([0, 1, 1, 0], [0, 0, 1, 1], color, 'EdgeColor', 'black', ...
            'LineWidth', 1.5, 'Visible', 'off');
        legend_handles = [legend_handles, h];
    end
    
    legend(ax, legend_handles, category_names, 'Location', 'northeast', 'FontSize', 10);
end

%% Normalize SD matrix (Min-Max per row)
function normalized_matrix = normalize_sd_matrix(sd_matrix)
    [num_rows, num_cols] = size(sd_matrix);
    normalized_matrix = zeros(num_rows, num_cols);
    
    for i = 1:num_rows
        row = sd_matrix(i, :);
        
        % Replace NaN with row mean
        valid_vals = row(~isnan(row));
        if isempty(valid_vals)
            normalized_matrix(i, :) = 0;
            continue;
        end
        
        row_mean = mean(valid_vals);
        row(isnan(row)) = row_mean;
        
        % Normalize
        min_val = min(row);
        max_val = max(row);
        
        if max_val == min_val
            normalized_matrix(i, :) = 0;
        else
            normalized_matrix(i, :) = (row - min_val) / (max_val - min_val);
        end
    end
end

%% Sort algorithms by category
function [algorithms_sorted, indices, categories] = sort_algorithms_by_category(algorithms)
    algorithms_cell = algorithms;
    if ~iscell(algorithms_cell)
        algorithms_cell = cellfun(@char, algorithms_cell, 'UniformOutput', false);
    end
    
    % Map each algorithm to its category
    algorithm_categories = {};
    for i = 1:length(algorithms_cell)
        algorithm_categories{i} = get_algorithm_category(algorithms_cell{i});
    end
    
    % Sort by category: proposed, classical, recent, cec_winners
    category_order = {'proposed', 'classical', 'recent', 'cec_winners'};
    
    indices = [];
    categories = {};
    
    for cat_idx = 1:length(category_order)
        current_category = category_order{cat_idx};
        category_indices = find(strcmp(algorithm_categories, current_category));
        
        if ~isempty(category_indices)
            % Sort alphabetically within category
            [~, sort_order] = sort(algorithms_cell(category_indices));
            sorted_category_indices = category_indices(sort_order);
            
            indices = [indices, sorted_category_indices];
            for i = sorted_category_indices
                categories{end+1} = current_category;
            end
        end
    end
    
    algorithms_sorted = algorithms_cell(indices);
end

%% Get algorithm category
function category = get_algorithm_category(algorithm_name)
    name = lower(algorithm_name);
    
    if strcmp(name, 'acpo') || strcmp(name, 'cpo')
        category = 'proposed';
    elseif strcmp(name, 'ssa') || strcmp(name, 'abc') || strcmp(name, 'pso')
        category = 'classical';
    elseif strcmp(name, 'gbo') || strcmp(name, 'sma') || strcmp(name, 'mpa')
        category = 'recent';
    elseif strcmp(name, 'shade') || strcmp(name, 'lshade') || strcmp(name, 'l_shade') || ...
           strcmp(name, 'lshade_spacma') || strcmp(name, 'l_shade_spacma')
        category = 'cec_winners';
    else
        category = 'recent';
    end
end

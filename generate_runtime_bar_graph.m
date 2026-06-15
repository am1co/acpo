function generate_runtime_bar_graph(csv_file)
    
    if nargin < 1
        csv_file = 'in/algo comparison/Algorithm_Comparison_AvgTime.csv';
    end
    
    % Verify file exists
    if ~isfile(csv_file)
        error('CSV file not found: %s', csv_file);
    end
    
    % Create output directory if it doesn't exist
    output_dir = 'out/time/';
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end
    
    fprintf('Parsing CSV file: %s\n', csv_file);
    
    % Parse the CSV file to extract all data
    [optimizer_names, suite_data] = parse_runtime_csv(csv_file);
    
    if isempty(optimizer_names)
        error('Failed to parse CSV file');
    end
    
    fprintf('Found %d optimizers\n', length(optimizer_names));
    
    % Filter data for CEC2017 functions only
    cec2017_indices = [];
    for i = 1:length(suite_data)
        if contains(suite_data(i).func_name, 'CEC2017', 'IgnoreCase', true)
            cec2017_indices = [cec2017_indices, i];
        end
    end
    
    if isempty(cec2017_indices)
        error('No CEC2017 functions found in data');
    end
    
    fprintf('Found %d CEC2017 functions\n', length(cec2017_indices));
    
    % Calculate average runtime for each optimizer across CEC2017 functions only
    avg_runtimes = [];
    for opt_idx = 1:length(optimizer_names)
        times = [];
        for idx = cec2017_indices
            if ~isnan(suite_data(idx).runtime(opt_idx))
                times = [times, suite_data(idx).runtime(opt_idx)];
            end
        end
        if isempty(times)
            avg_runtimes = [avg_runtimes, NaN];
        else
            avg_runtimes = [avg_runtimes, mean(times)];
        end
    end
    
    % Sort algorithms by category
    [algorithms_sorted, indices, categories] = sort_algorithms_by_category(optimizer_names);
    avg_runtimes_sorted = avg_runtimes(indices);
    
    % Define color scheme: less saturated hues
    colors = define_colors_muted();
    
    % Create figure
    fig = figure('Visible', 'off', 'Units', 'normalized', 'Position', [0, 0, 1, 1]);
    ax = axes('Parent', fig);
    
    % Create color array based on categories
    bar_colors = get_color_array(categories, colors);
    
    % Create bars with individual colors
    hold(ax, 'on');
    for i = 1:length(avg_runtimes_sorted)
        bar(ax, i, avg_runtimes_sorted(i), 'FaceColor', bar_colors(i, :), 'EdgeColor', 'black', 'LineWidth', 1.5);
    end
    hold(ax, 'off');
    
    % Set X-axis labels and rotation
    display_names = cellfun(@(x) strrep(x, '_', ' '), algorithms_sorted, 'UniformOutput', false);
    set(ax, 'XTick', 1:length(display_names), 'XTickLabel', display_names, 'XTickLabelRotation', 45);
    
    % Set Y-axis properties
    max_time = max(avg_runtimes_sorted);
    set(ax, 'YLim', [0, max_time * 1.15], 'FontSize', 11, 'FontName', 'Arial');
    
    % Labels and title
    xlabel(ax, 'Algorithm', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold');
    ylabel(ax, 'Average Runtime (seconds)', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold');
    title(ax, 'Average Computational Runtime - CEC2017', 'FontSize', 14, 'FontName', 'Arial', 'FontWeight', 'bold');
    
    % Grid
    grid(ax, 'on');
    set(ax, 'GridLineStyle', '--', 'GridAlpha', 0.3, 'Layer', 'bottom');
    
    % Value labels on bars
    for i = 1:length(avg_runtimes_sorted)
        text(i, avg_runtimes_sorted(i) + (max_time * 0.02), sprintf('%.4f', avg_runtimes_sorted(i)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 10, 'FontName', 'Arial', 'FontWeight', 'bold');
    end
    
    % Add legend
    add_category_legend(ax, colors);
    
    % Save figure
    set(fig, 'Position', [100, 100, 1200, 700]);
    output_filename = 'Bar_Runtime_CEC2017.png';
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
    fprintf('Runtime bar graph generation complete.\n');
end

%% Main parsing function
function [optimizer_names, suite_data] = parse_runtime_csv(csv_file)
    % Parse the Algorithm_Comparison_AvgTime.csv file
    
    try
        % Read raw cell array
        raw_data = readcell(csv_file, 'NumHeaderLines', 0);
        
        % Extract headers
        optimizer_row = raw_data(1, :);
        
        % Extract optimizer names
        optimizer_names = {};
        runtime_indices = [];
        
        for col_idx = 2:min(length(optimizer_row), size(raw_data, 2))
            optimizer_name = string(strtrim(optimizer_row{col_idx}));
            
            % Skip empty columns
            if strlength(optimizer_name) == 0
                continue;
            end
            
            if ~ismember(optimizer_name, optimizer_names)
                optimizer_names{end+1} = char(optimizer_name);
                runtime_indices(length(optimizer_names)) = col_idx;
            end
        end
        
        if isempty(optimizer_names)
            error('Could not extract optimizer names from CSV');
        end
        
        % Parse data rows (starting from row 2)
        suite_data = struct([]);
        row_count = 0;
        
        for row_idx = 2:size(raw_data, 1)
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
            
            % Extract runtime values
            runtime_vals = [];
            has_valid_data = false;
            
            for opt_idx = 1:length(optimizer_names)
                col_idx = runtime_indices(opt_idx);
                if col_idx <= size(raw_data, 2)
                    val = get_numeric_value(raw_data, row_idx, col_idx);
                    runtime_vals = [runtime_vals, val];
                    if ~isnan(val)
                        has_valid_data = true;
                    end
                else
                    runtime_vals = [runtime_vals, NaN];
                end
            end
            
            % Only add row if it has valid data
            if has_valid_data
                row_count = row_count + 1;
                
                entry = struct();
                entry.func_name = char(func_name);
                entry.runtime = runtime_vals;
                
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
        suite_data = struct([]);
    end
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

%% Color Definition Functions (Muted/Less Saturated)
function colors = define_colors_muted()
    % Muted/less saturated hues for runtime bar graphs
    colors = struct();
    colors.proposed = [0.4, 0.55, 0.75];    % Muted blue
    colors.classical = [0.75, 0.55, 0.4];   % Muted orange
    colors.recent = [0.4, 0.7, 0.4];        % Muted green
    colors.cec_winners = [0.7, 0.4, 0.7];   % Muted magenta
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

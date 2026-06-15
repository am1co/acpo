function generate_dimensionality_analysis(data_dir)
    % Unified generator for high dimensionality analysis
    
    % Default input directory
    if nargin < 1
        data_dir = 'in/dimension/';
    end
    
    % Define output directory
    output_dir = 'out/dim/';
    
    % Create output directory if it doesn't exist
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end
    
    % Define optimal values for OE calculation
    optimal_values = createOptimalValuesMap();
    
    % Read CSV file with new format (Optimizer x Metrics layout)
    csv_filename = 'High_Dimensionality_Fitness.csv';
    csv_path = fullfile(data_dir, csv_filename);
    
    if ~isfile(csv_path)
        error('File not found: %s', csv_path);
    end
    
    % Read raw CSV to parse the complex header structure
    fid = fopen(csv_path, 'r');
    optimizer_row = fgetl(fid);
    metric_row = fgetl(fid);
    function_row = fgetl(fid);
    fclose(fid);
    
    % Parse optimizer names and metrics from header
    optimizer_names = strsplit(optimizer_row, ',');
    optimizer_names = optimizer_names(2:end);  % Remove first empty cell
    metric_names = strsplit(metric_row, ',');
    metric_names = metric_names(2:end);  % Remove first empty cell
    
    % Create mapping of optimizer columns
    [unique_optimizers, opt_map] = parseOptimizerMetrics(optimizer_names, metric_names);
    
    fprintf('CSV File: %s\n', csv_path);
    fprintf('Unique optimizers: %d\n', length(unique_optimizers));
    fprintf('Optimizers found: %s\n', strjoin(unique_optimizers, ', '));
    
    % Read data using readtable, starting from row 4
    opts = detectImportOptions(csv_path);
    opts.DataLines = [4, Inf];  % Start reading from row 4 (data rows)
    data_table = readtable(csv_path, opts);
    
    % Extract function names (first column)
    functions = string(data_table{:, 1});
    fprintf('Total functions: %d\n', length(functions));
    
    % Initialize storage for metrics
    n_optimizers = length(unique_optimizers);
    n_functions = length(functions);
    
    fitness_matrix = zeros(n_functions, n_optimizers);
    rank_matrix = zeros(n_functions, n_optimizers);
    sd_matrix = zeros(n_functions, n_optimizers);
    
    % Extract data for each optimizer and metric
    for opt_idx = 1:n_optimizers
        opt_name = unique_optimizers{opt_idx};
        mapping = opt_map(opt_name);
        
        % Get column indices for this optimizer's metrics (add 1 to account for Function column)
        fitness_col = mapping.fitness + 1;
        rank_col = mapping.rank + 1;
        sd_col = mapping.sd + 1;
        
        % Extract values from table
        fitness_matrix(:, opt_idx) = data_table{:, fitness_col};
        rank_matrix(:, opt_idx) = data_table{:, rank_col};
        sd_matrix(:, opt_idx) = data_table{:, sd_col};
    end
    
    fprintf('Data extraction complete\n');
    fprintf('Fitness matrix: %d x %d\n', size(fitness_matrix));
    fprintf('Rank matrix: %d x %d\n', size(rank_matrix));
    fprintf('SD matrix: %d x %d\n\n', size(sd_matrix));
    
    % Separate data by dimensionality
    dim30_mask = contains(functions, 'dim30', 'IgnoreCase', true);
    dim50_mask = contains(functions, 'dim50', 'IgnoreCase', true);
    
    % Process 30D data
    if any(dim30_mask)
        dim30_functions = functions(dim30_mask);
        dim30_fitness = fitness_matrix(dim30_mask, :);
        dim30_rank = rank_matrix(dim30_mask, :);
        dim30_sd = sd_matrix(dim30_mask, :);
        
        fprintf('Number of 30D functions: %d\n', length(dim30_functions));
        fprintf('Data points for 30D: %d\n', size(dim30_fitness, 1));
        fprintf('Fitness - Min: %.4f | Max: %.4f | Mean: %.4f\n', ...
            min(dim30_fitness(~isnan(dim30_fitness))), ...
            max(dim30_fitness(~isnan(dim30_fitness))), ...
            mean(dim30_fitness, 'all', 'omitnan'));
        fprintf('Rank - Min: %.4f | Max: %.4f | Mean: %.4f\n', ...
            min(dim30_rank(~isnan(dim30_rank))), ...
            max(dim30_rank(~isnan(dim30_rank))), ...
            mean(dim30_rank, 'all', 'omitnan'));
        fprintf('SD - Min: %.4f | Max: %.4f | Mean: %.4f\n', ...
            min(dim30_sd(~isnan(dim30_sd))), ...
            max(dim30_sd(~isnan(dim30_sd))), ...
            mean(dim30_sd, 'all', 'omitnan'));
        
        generateDimensionalityMetrics(dim30_functions, dim30_fitness, dim30_rank, ...
            dim30_sd, unique_optimizers, optimal_values, 30, output_dir);
    end
    
    % Process 50D data
    if any(dim50_mask)
        dim50_functions = functions(dim50_mask);
        dim50_fitness = fitness_matrix(dim50_mask, :);
        dim50_rank = rank_matrix(dim50_mask, :);
        dim50_sd = sd_matrix(dim50_mask, :);
        
        fprintf('Number of 50D functions: %d\n', length(dim50_functions));
        fprintf('Data points for 50D: %d\n', size(dim50_fitness, 1));
        fprintf('Fitness - Min: %.4f | Max: %.4f | Mean: %.4f\n', ...
            min(dim50_fitness(~isnan(dim50_fitness))), ...
            max(dim50_fitness(~isnan(dim50_fitness))), ...
            mean(dim50_fitness, 'all', 'omitnan'));
        fprintf('Rank - Min: %.4f | Max: %.4f | Mean: %.4f\n', ...
            min(dim50_rank(~isnan(dim50_rank))), ...
            max(dim50_rank(~isnan(dim50_rank))), ...
            mean(dim50_rank, 'all', 'omitnan'));
        fprintf('SD - Min: %.4f | Max: %.4f | Mean: %.4f\n', ...
            min(dim50_sd(~isnan(dim50_sd))), ...
            max(dim50_sd(~isnan(dim50_sd))), ...
            mean(dim50_sd, 'all', 'omitnan'));
        
        generateDimensionalityMetrics(dim50_functions, dim50_fitness, dim50_rank, ...
            dim50_sd, unique_optimizers, optimal_values, 50, output_dir);
    end
    
    fprintf('Dimensionality analysis complete. Output saved to: %s\n\n', output_dir);
end

%% HELPER FUNCTIONS

%% Parse optimizer names and metrics from header rows to create mapping
function [unique_optimizers, opt_map] = parseOptimizerMetrics(optimizer_names, metric_names)
    % Create mapping of optimizer columns
    opt_map = containers.Map();
    unique_optimizers = {};
    unique_idx = 1;
    col_idx = 1;
    
    for i = 1:length(optimizer_names)
        opt_name = strtrim(optimizer_names{i});
        metric_name = strtrim(metric_names{i});
        
        % Skip empty cells
        if isempty(opt_name) || isempty(metric_name)
            col_idx = col_idx + 1;
            continue;
        end
        
        % Check if this optimizer is new
        if ~isKey(opt_map, opt_name)
            unique_optimizers{unique_idx} = opt_name;
            opt_map(opt_name) = struct('fitness', [], 'rank', [], 'sd', []);
            unique_idx = unique_idx + 1;
        end
        
        % Store column index for this metric
        mapping = opt_map(opt_name);
        switch lower(metric_name)
            case 'average fitness'
                mapping.fitness = col_idx;
            case 'rank'
                mapping.rank = col_idx;
            case 'standard deviation'
                mapping.sd = col_idx;
        end
        opt_map(opt_name) = mapping;
        col_idx = col_idx + 1;
    end
    
    unique_optimizers = unique_optimizers';
end

%% Normalize column names to handle variations in CSV format
function colmap = normalizeColumnNames(actual_cols)
    colmap = containers.Map();
    
    % Create reverse mapping to original indices
    for i = 1:length(actual_cols)
        col_lower = lower(actual_cols(i));
        
        % Categorize columns
        if contains(col_lower, 'function')
            colmap('function') = i;
        elseif contains(col_lower, 'optimizer')
            colmap('optimizer') = i;
        elseif contains(col_lower, 'fitness') || contains(col_lower, 'averagefitness')
            colmap('average_fitness') = i;
        elseif contains(col_lower, 'standard') || contains(col_lower, 'stddev')
            colmap('standard_deviation') = i;
        elseif contains(col_lower, 'rank')
            colmap('rank') = i;
        end
    end
    
    % Verify all required columns are found
    required = {'function', 'optimizer', 'average_fitness', 'standard_deviation', 'rank'};
    for req_col = required
        if ~isKey(colmap, req_col{1})
            error('Required column not found: %s', req_col{1});
        end
    end
end

%% Create optimal values map for OE calculation
function optimal_values = createOptimalValuesMap()
    optimal_values = containers.Map();
    
    % CEC2017 optimal values
    cec2017_optima = struct(...
        'CEC2017_F1', 100, 'CEC2017_F2', 200, 'CEC2017_F3', 300, 'CEC2017_F4', 400, ...
        'CEC2017_F5', 500, 'CEC2017_F6', 600, 'CEC2017_F7', 700, 'CEC2017_F8', 800, ...
        'CEC2017_F9', 900, 'CEC2017_F10', 1000, 'CEC2017_F11', 1100, 'CEC2017_F12', 1200, ...
        'CEC2017_F13', 1300, 'CEC2017_F14', 1400, 'CEC2017_F15', 1500, 'CEC2017_F16', 1600, ...
        'CEC2017_F17', 1700, 'CEC2017_F18', 1800, 'CEC2017_F19', 1900, 'CEC2017_F20', 2000, ...
        'CEC2017_F21', 2100, 'CEC2017_F22', 2200, 'CEC2017_F23', 2300, 'CEC2017_F24', 2400, ...
        'CEC2017_F25', 2500, 'CEC2017_F26', 2600, 'CEC2017_F27', 2700, 'CEC2017_F28', 2800, ...
        'CEC2017_F29', 2900, 'CEC2017_F30', 3000);
    
    % CEC2022 optimal values
    cec2022_optima = struct(...
        'CEC2022_F1', 300, 'CEC2022_F2', 400, 'CEC2022_F3', 600, 'CEC2022_F4', 800, ...
        'CEC2022_F5', 900, 'CEC2022_F6', 1800, 'CEC2022_F7', 2000, 'CEC2022_F8', 2200, ...
        'CEC2022_F9', 2300, 'CEC2022_F10', 2400, 'CEC2022_F11', 2600, 'CEC2022_F12', 2700);
    
    % Store in containers.Map
    for fname = fieldnames(cec2017_optima)'
        key = fname{1};
        optimal_values(key) = cec2017_optima.(fname{1});
    end
    
    for fname = fieldnames(cec2022_optima)'
        key = fname{1};
        optimal_values(key) = cec2022_optima.(fname{1});
    end
end

%% Generate all three metrics for a given dimensionality
function generateDimensionalityMetrics(functions, fitness_matrix, rank_matrix, sd_matrix, ...
    unique_optimizers, optimal_values, dimension, output_dir)
    
    fprintf('\n--- Generating metrics for %dD ---\n', dimension);
    
    n_optimizers = length(unique_optimizers);
    n_functions = size(fitness_matrix, 1);
    
    fprintf('Matrix dimensions: %d functions x %d optimizers\n', n_functions, n_optimizers);
    
    % Extract base function names (remove dimensionality suffix)
    base_functions = strrep(functions, ['_dim' num2str(dimension)], '');
    
    % ========== GENERATE OE METRIC ==========
    fprintf('\n  [OE] Calculating Overall Effectiveness...\n');
    oe_values = calculateOverallEffectiveness(fitness_matrix, base_functions, ...
        optimal_values, unique_optimizers);
    
    fprintf('    Raw OE values per optimizer:\n');
    for opt_idx = 1:length(unique_optimizers)
        fprintf('      %s: %.4f\n', unique_optimizers{opt_idx}, oe_values(opt_idx));
    end
    
    % Normalize OE values
    min_oe = min(oe_values(~isinf(oe_values) & ~isnan(oe_values)));
    max_oe = max(oe_values(~isinf(oe_values) & ~isnan(oe_values)));
    if max_oe == min_oe
        normalized_oe = zeros(size(oe_values));
    else
        normalized_oe = (oe_values - min_oe) / (max_oe - min_oe);
    end
    
    fprintf('    OE normalization: min=%.4f, max=%.4f\n', min_oe, max_oe);
    fprintf('    Normalized OE values:\n');
    for opt_idx = 1:length(unique_optimizers)
        fprintf('      %s: %.4f\n', unique_optimizers{opt_idx}, normalized_oe(opt_idx));
    end
    
    [sorted_names, sorted_idx, sorted_cats] = sortAlgorithmsByCategory(unique_optimizers);
    sorted_oe = normalized_oe(sorted_idx);
    
    generateBarGraph(sorted_names, sorted_oe, 'OE', dimension, output_dir, [0, 1.1]);
    
    % ========== USE PROVIDED RANK METRIC ==========
    fprintf('\n  [RANK] Using provided rank data...\n');
    
    % Calculate average rank per optimizer across all functions
    averaged_ranks = mean(rank_matrix, 1, 'omitnan');
    
    fprintf('    Raw averaged rank values per optimizer:\n');
    for opt_idx = 1:length(unique_optimizers)
        fprintf('      %s: %.4f\n', unique_optimizers{opt_idx}, averaged_ranks(opt_idx));
    end
    
    [sorted_names, sorted_idx, sorted_cats] = sortAlgorithmsByCategory(unique_optimizers);
    sorted_rank = averaged_ranks(sorted_idx);
    max_rank = max(sorted_rank);
    
    fprintf('    Rank statistics: min=%.4f, max=%.4f\n', min(sorted_rank), max_rank);
    
    generateBarGraph(sorted_names, sorted_rank, 'Rank', dimension, output_dir, [0, max_rank * 1.15]);
    
    % ========== GENERATE STANDARD DEVIATION METRIC ==========
    fprintf('\n  [SD] Calculating Normalized Standard Deviations...\n');
    
    % Calculate normalized average SD
    norm_avg_sd = calculateNormalizedAverage(sd_matrix);
    
    fprintf('    Raw SD matrix statistics:\n');
    fprintf('      Min: %.4f | Max: %.4f | Mean: %.4f\n', ...
        min(sd_matrix(sd_matrix > 0)), ...
        max(sd_matrix(:)), ...
        mean(sd_matrix, 'all', 'omitnan'));
    
    fprintf('    Normalized averaged SD values per optimizer:\n');
    for opt_idx = 1:length(unique_optimizers)
        fprintf('      %s: %.4f\n', unique_optimizers{opt_idx}, norm_avg_sd(opt_idx));
    end
    
    [sorted_names, sorted_idx, sorted_cats] = sortAlgorithmsByCategory(unique_optimizers);
    sorted_sd = norm_avg_sd(sorted_idx);
    
    generateBarGraph(sorted_names, sorted_sd, 'SD', dimension, output_dir, [0, 1.1]);
    
    % ========== EXPORT CSV SUMMARY ==========
    fprintf('\n  Exporting CSV summary for %dD...\n', dimension);
    exportDimensionSummary(dimension, sorted_names, sorted_oe, sorted_rank, sorted_sd, output_dir);
    
    fprintf('\n--- %dD metrics generation complete ---\n\n', dimension);
end

%% Calculate Overall Effectiveness (OE)
function oe_values = calculateOverallEffectiveness(fitness_matrix, base_functions, ...
    optimal_values, optimizer_names)
    
    oe_values = zeros(1, length(optimizer_names));
    
    % Count functions matched to optimal values
    matched_functions = 0;
    
    for opt_idx = 1:length(optimizer_names)
        error_sum = 0;
        valid_count = 0;
        
        for func_idx = 1:length(base_functions)
            base_name = base_functions(func_idx);
            
            % Try to find optimal value
            if optimal_values.isKey(base_name)
                f_opt = optimal_values(base_name);
                f_avg = fitness_matrix(func_idx, opt_idx);
                
                if ~isnan(f_avg) && f_avg > 0
                    error_sum = error_sum + abs(f_opt - f_avg);
                    valid_count = valid_count + 1;
                    matched_functions = func_idx;  % Track last matched
                end
            end
        end
        
        if valid_count > 0
            oe_values(opt_idx) = error_sum / valid_count;
        else
            oe_values(opt_idx) = NaN;
        end
    end
    
    if matched_functions > 0
        fprintf('      (Matched %d functions to optimal values)\n', matched_functions);
    end
end

%% Calculate Normalized Average (min-max normalization per row, then mean per column)
function normalized_avg = calculateNormalizedAverage(data_matrix)
    
    if isempty(data_matrix) || size(data_matrix, 1) == 0
        normalized_avg = [];
        return;
    end
    
    normalized_data = zeros(size(data_matrix));
    
    % Apply min-max normalization row-wise
    for row_idx = 1:size(data_matrix, 1)
        row = data_matrix(row_idx, :);
        
        row_min = min(row(~isnan(row)));
        row_max = max(row(~isnan(row)));
        
        if row_max == row_min
            normalized_data(row_idx, :) = zeros(size(row));
        else
            normalized_data(row_idx, :) = (row - row_min) / (row_max - row_min);
        end
    end
    
    % Calculate mean of each column
    normalized_avg = mean(normalized_data, 1, 'omitnan');
end

%% Generate bar graph for a metric with category-based coloring
function generateBarGraph(optimizer_names, metric_values, metric_name, dimension, output_dir, y_limits)
    
    % Get color scheme based on metric type
    switch metric_name
        case 'OE'
            colors = defineColorsVibrant();
            output_suffix = 'OE';
            y_label = 'Normalized OE';
        case 'Rank'
            colors = defineColorsPastel();
            output_suffix = 'Rank_Dimensionality';
            y_label = 'Averaged Rank';
        case 'SD'
            colors = defineColorsDarker();
            output_suffix = 'SD';
            y_label = 'Normalized Averaged SD';
        otherwise
            colors = defineColorsDarker();
            output_suffix = metric_name;
            y_label = metric_name;
    end
    
    % Sort algorithms by category and get category assignments
    [algorithms_sorted, sort_indices, categories] = sortAlgorithmsByCategory(optimizer_names);
    metric_sorted = metric_values(sort_indices);
    
    % Create color array based on categories
    bar_colors = getColorArray(categories, colors);
    
    % Create figure
    fig = figure('Visible', 'off', 'Units', 'normalized', 'Position', [0, 0, 1, 1]);
    ax = axes('Parent', fig);
    
    % Create bars with individual colors
    hold(ax, 'on');
    for i = 1:length(metric_sorted)
        bar(ax, i, metric_sorted(i), 'FaceColor', bar_colors(i, :), 'EdgeColor', 'black', 'LineWidth', 1.5);
    end
    hold(ax, 'off');
    
    % Set X-axis
    display_names = cellfun(@(x) strrep(x, '_', ' '), algorithms_sorted, 'UniformOutput', false);
    set(ax, 'XTick', 1:length(display_names), 'XTickLabel', display_names, ...
        'XTickLabelRotation', 45);
    
    % Set Y-axis
    set(ax, 'YLim', y_limits, 'FontSize', 11, 'FontName', 'Arial');
    
    % Labels and title
    xlabel(ax, 'Algorithm', 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold');
    ylabel(ax, y_label, 'FontSize', 12, 'FontName', 'Arial', 'FontWeight', 'bold');
    title(ax, sprintf('High Dimensionality - %d Dims %s', dimension, metric_name), ...
        'FontSize', 14, 'FontName', 'Arial', 'FontWeight', 'bold');
    
    % Add grid
    grid(ax, 'on');
    set(ax, 'GridLineStyle', '--', 'GridAlpha', 0.3, 'Layer', 'bottom');
    
    % Add text labels on bars
    for idx = 1:length(metric_sorted)
        text(idx, metric_sorted(idx) + (diff(y_limits) * 0.02), ...
            sprintf('%.4f', metric_sorted(idx)), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontSize', 10, 'FontName', 'Arial', 'FontWeight', 'bold');
    end
    
    % Add legend for categories
    addCategoryLegend(ax, colors);
    
    % Set figure size
    set(fig, 'Position', [100, 100, 1200, 700]);
    
    % Save figure
    output_filename = sprintf('Bar_%s_Dim%d.png', output_suffix, dimension);
    output_path = fullfile(output_dir, output_filename);
    
    try
        exportgraphics(fig, output_path, 'Resolution', 150);
    catch
        set(fig, 'PaperUnits', 'inches');
        set(fig, 'PaperSize', [10, 7]);
        set(fig, 'PaperPosition', [0, 0, 10, 7]);
        print(fig, output_path, '-dpng', '-r150');
    end
    
    fprintf('    Saved: %s\n', output_filename);
    close(fig);
end

%% Sort optimizers by category (Proposed, Classical, Recent, CEC Winners) with alphabetical within category
function [algorithms_sorted, sort_indices, categories] = sortAlgorithmsByCategory(optimizer_names)
    
    % Convert to cell array if needed
    if isstring(optimizer_names)
        algorithms_cell = cellstr(optimizer_names);
    elseif iscell(optimizer_names)
        algorithms_cell = optimizer_names;
    else
        algorithms_cell = cellstr(optimizer_names);
    end
    
    % Map each algorithm to its category
    algorithm_categories = {};
    for i = 1:length(algorithms_cell)
        algorithm_categories{i} = getAlgorithmCategory(algorithms_cell{i});
    end
    
    % Sort by category: proposed, classical, recent, cec_winners
    category_order = {'proposed', 'classical', 'recent', 'cec_winners'};
    
    sort_indices = [];
    categories = {};
    
    for cat_idx = 1:length(category_order)
        current_category = category_order{cat_idx};
        category_indices = find(strcmp(algorithm_categories, current_category));
        
        if ~isempty(category_indices)
            % Sort alphabetically within category
            [~, sort_order] = sort(algorithms_cell(category_indices));
            sorted_category_indices = category_indices(sort_order);
            
            sort_indices = [sort_indices, sorted_category_indices];
            for i = sorted_category_indices
                categories{end+1} = current_category;
            end
        end
    end
    
    algorithms_sorted = algorithms_cell(sort_indices);
end

%% Get algorithm category
function category = getAlgorithmCategory(algorithm_name)
    name = lower(algorithm_name);
    
    if strcmp(name, 'acpo') || strcmp(name, 'cpo')
        category = 'proposed';
    elseif strcmp(name, 'ssa') || strcmp(name, 'abc') || strcmp(name, 'pso')
        category = 'classical';
    elseif strcmp(name, 'gbo') || strcmp(name, 'sma') || strcmp(name, 'mpa')
        category = 'recent';
    elseif strcmp(name, 'shade') || strcmp(name, 'l_shade') || strcmp(name, 'l_shade_spacma')
        category = 'cec_winners';
    else
        category = 'recent';
    end
end

%% Color definition functions
function colors = defineColorsDarker()
    % Darker hues for SD bar graphs
    colors = struct();
    colors.proposed = [0.0, 0.3, 0.7];      % Dark blue
    colors.classical = [0.7, 0.35, 0.0];    % Dark orange
    colors.recent = [0.0, 0.5, 0.0];        % Dark green
    colors.cec_winners = [0.6, 0.0, 0.4];   % Dark magenta
end

function colors = defineColorsPastel()
    % Pastel hues for Rank bar graphs
    colors = struct();
    colors.proposed = [0.6, 0.8, 1.0];      % Light blue
    colors.classical = [1.0, 0.8, 0.6];     % Light orange
    colors.recent = [0.6, 1.0, 0.6];        % Light green
    colors.cec_winners = [1.0, 0.6, 1.0];   % Light magenta
end

function colors = defineColorsVibrant()
    % Vibrant hues for OE bar graphs
    colors = struct();
    colors.proposed = [0.0, 0.5, 1.0];      % Bright blue
    colors.classical = [1.0, 0.6, 0.0];     % Bright orange
    colors.recent = [0.0, 1.0, 0.0];        % Bright green
    colors.cec_winners = [1.0, 0.0, 0.8];   % Bright magenta
end

%% Get color array from categories
function bar_colors = getColorArray(categories, colors)
    bar_colors = [];
    for i = 1:length(categories)
        cat = categories{i};
        bar_colors = [bar_colors; colors.(cat)];
    end
end

%% Add category legend
function addCategoryLegend(ax, colors)
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
    
    legend(ax, legend_handles, category_names, 'Location', 'northwest', 'FontSize', 10);
end

%% Export dimension summary to CSV
function exportDimensionSummary(dimension, optimizer_names, oe_vals, rank_vals, sd_vals, output_dir)
    
    output_filename = sprintf('Summary_Dim%d.csv', dimension);
    output_path = fullfile(output_dir, output_filename);
    
    fid = fopen(output_path, 'w');
    if fid == -1
        error('Cannot open file for writing: %s', output_path);
    end
    
    % Write header
    fprintf(fid, 'Optimizer,OE,Rank,SD\n');
    
    % Write data rows
    for idx = 1:length(optimizer_names)
        fprintf(fid, '%s,%.4f,%.4f,%.4f\n', ...
            optimizer_names{idx}, oe_vals(idx), rank_vals(idx), sd_vals(idx));
    end
    
    fclose(fid);
    fprintf('    Saved: %s\n', output_filename);
end

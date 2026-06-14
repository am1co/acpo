% Configurable parameters
RUN_NO = 30;  % Number of independent runs per optimizer
convergence_data_base = "E:\ACPO_Convergence_Curves_Raw\";  % Base path for convergence curves
opt = -Inf;   % Optimal value (for stopping criterion)

% Optimizer list for comparison
optimizers = {'CPO'};

% Problem configuration cell array
% Format: {name, lb, ub, dim, data_to_load, fn_name, result_filename, default_CP_no, default_Tmax}
problems = {
    'welded_beam',          [0.125,0.1,0.1,0.125],          [5,10,10,5],              4,  '',        'welded_beam',          "test_results\welded_beam_test_results.csv",           40, 50000;
    'pressure_vessel',      [0.0625,0.0625,10,10],          [99,99,200,200],          4,  '',        'pressure_vessel',      "test_results\pressure_vessel_test_results.csv",       40, 50000;
    'ten_bar_truss',        ones(1,10)*0.1,                 ones(1,10)*33.5,          10, 'Data10',   'ten_bar_truss',        "test_results\ten_bar_truss_test_results.csv",         40, 50000;
    'twentyfive_bar_truss', ones(1,25)*0.01,                ones(1,25)*3.4,           25, 'Data25',   'twentyfive_bar_truss', "test_results\twentyfive_bar_truss_test_results.csv",   40, 50000;
    'f942_bar_truss',       ones(1,59)*0.1,                 ones(1,59)*200,           59, '',        'f942_bar_truss',        "test_results\f942_bar_truss_test_results.csv",        40,  25000;
};

%% Main problem loop
for i = 1:size(problems, 1)
    % Extract problem configuration
    prob_name = problems{i, 1};
    lb = problems{i, 2};
    ub = problems{i, 3};
    dim = problems{i, 4};
    data_to_load = problems{i, 5};
    fn_name = problems{i, 6};
    result_filename = problems{i, 7};
    CP_no = problems{i, 8};
    Tmax = problems{i, 9};
    
    % Setup problem folder path
    engProbsFolderPath = fullfile(pwd, 'engineering_probs', prob_name);
    addpath(engProbsFolderPath);
    
    % Create function handle (with optional data parameter)
    if ~strcmp(data_to_load, '')
        eval([data_to_load ' = ' data_to_load ';']);  % Load Data10 or Data25 into workspace
        data_var = eval(data_to_load);  % Capture the loaded data
        fobj = @(x) feval(fn_name, x, data_var);  % Create function handle with captured data
    else
        fobj = @(x) feval(fn_name, x);
    end
    
    % Create convergence curves folder for this problem
    convergence_data_folder = fullfile(convergence_data_base, prob_name);
    if ~isfolder(convergence_data_folder)
        mkdir(convergence_data_folder);
    end
    
    % Build dynamic result table structure based on dimension
    [varNames, varTypes] = buildResultTable(dim, prob_name);
    resultsTable = table('Size', [0, length(varNames)], 'VariableTypes', varTypes, 'VariableNames', varNames);
    writetable(resultsTable, result_filename);  % Initialize CSV
    
    %% Run ACPO baseline
    optimizer = "ACPO";
    display_name = createDisplayName(prob_name);
    disp(optimizer + " Optimizing " + display_name)
    
    fitnessACPO = zeros(1, RUN_NO);
    positionsACPO = zeros(RUN_NO, dim);
    Convergence_curve = zeros(RUN_NO, Tmax);
    run_times = zeros(1, RUN_NO);
    
    parfor j=1:RUN_NO 
        t_start = tic;

        [Best_score, Best_pos, Convergence_curve(j,:)] = ACPO(CP_no, Tmax, lb, ub, dim, fobj, opt);
        fitnessACPO(1, j) = Best_score;
        positionsACPO(j, :) = Best_pos;

        run_times(j) = toc(t_start);
    end
    
    % Find best position across all runs
    [~, best_idx] = min(fitnessACPO);
    best_position = positionsACPO(best_idx, :);
    
    % Record ACPO results
    p = NaN;  % Baseline value
    resultRow = buildResultRow(prob_name, dim, optimizer, best_position, min(fitnessACPO), mean(fitnessACPO), std(fitnessACPO), p, mean(run_times));
    writetable(resultRow, result_filename, 'WriteMode', 'Append');
    
    % Save ACPO convergence curves
    file_name = char(optimizer) + "_" + prob_name + ".csv";
    full_path = fullfile(convergence_data_folder, file_name);
    writematrix(Convergence_curve, full_path);
    
    %% Loop through comparison optimizers
    for opt_idx = 1:length(optimizers)
        optimizer = string(optimizers{opt_idx});
        disp(optimizer + " Optimizing " + display_name)
        
        fitness = zeros(1, RUN_NO);
        positions = zeros(RUN_NO, dim);
        Convergence_curve = zeros(RUN_NO, Tmax);
        run_times = zeros(1, RUN_NO);
        
        parfor j=1:RUN_NO 
            t_start = tic;

            [Best_score, Best_pos, Convergence_curve(j,:)] = feval(optimizer, CP_no, Tmax, lb, ub, dim, fobj, opt);
            fitness(1, j) = Best_score;
            positions(j, :) = Best_pos;

            run_times(j) = toc(t_start);
        end
        
        % Find best position across all runs
        [~, best_idx] = min(fitness);
        best_position = positions(best_idx, :);
        
        % Compute rank-sum p-value vs ACPO baseline
        p = ranksum(fitnessACPO(1,:), fitness(1,:));
        
        % Record results
        resultRow = buildResultRow(prob_name, dim, optimizer, best_position, min(fitness), mean(fitness), std(fitness), p, mean(run_times));
        writetable(resultRow, result_filename, 'WriteMode', 'Append');
        
        % Save convergence curves
        file_name = char(optimizer) + "_" + prob_name + ".csv";
        full_path = fullfile(convergence_data_folder, file_name);
        writematrix(Convergence_curve, full_path);
    end
    
    % Cleanup for this problem
    rmpath(engProbsFolderPath);
end


%% Helper Functions

function [varNames, varTypes] = buildResultTable(dim, ~)
    % Build dynamic result table structure based on problem dimension
    varNames = {'Function', 'Optimizer'};
    varTypes = {'string', 'string'};
    
    % Add x_ columns for decision variables (dim <= 25 to keep tables manageable)
    if dim <= 25
        for j = 1:dim
            varNames = [varNames, sprintf('x_%d', j)];
            varTypes = [varTypes, 'double'];
        end
    end
    
    % Always add Best, stats, rank-sum, time
    varNames = [varNames, {'Best', 'Average Fitness', 'Standard Deviation', 'Rank-Sum', 'Average Time'}];
    varTypes = [varTypes, {'double', 'double', 'double', 'double', 'double'}];
end

function resultRow = buildResultRow(prob_name, dim, optimizer, best_position, ...
                                     best_fitness, avg_fitness, std_fitness, p_value, avg_time)
    % Build a result table row with the appropriate number of decision variable columns
    
    % Convert string data to proper types
    if isstring(prob_name)
        prob_str = prob_name;
    else
        prob_str = string(prob_name);
    end
    
    if isstring(optimizer)
        opt_str = optimizer;
    else
        opt_str = string(optimizer);
    end
    
    % Create cell array of data starting with Problem and Optimizer
    cellData = {prob_str, opt_str};
    
    % Add decision variable values if dim <= 25
    if dim <= 25
        cellData = [cellData, num2cell(best_position)];
    end
    
    % Add fitness and stats
    cellData = [cellData, {best_fitness, avg_fitness, std_fitness, p_value, avg_time}];
    
    % Create table with appropriate variable names
    [varNames, ~] = buildResultTable(dim, prob_name);
    resultRow = table(cellData{:}, 'VariableNames', varNames);
end

function display_name = createDisplayName(prob_name)
    % Convert problem name to display format
    switch prob_name
        case 'welded_beam'
            display_name = "Welded Beam Design Problem";
        case 'pressure_vessel'
            display_name = "Pressure Vessel Design Problem";
        case 'ten_bar_truss'
            display_name = "10-Bar Truss Design Problem";
        case 'twentyfive_bar_truss'
            display_name = "25-Bar Truss Design Problem";
        case 'f942_bar_truss'
            display_name = "942-Bar Truss Design Problem";
        otherwise
            display_name = string(prob_name);
    end
end
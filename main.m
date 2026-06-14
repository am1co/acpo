clear
clc
CP_no=120; % Number of search agents (crested porcupines)
RUN_NO=30; % Number of independent runs
dim=10;

resultsTable = table('Size', [0, 6], ...
                     'VariableTypes', {'string', 'string', 'int32', 'double', 'double',  'double'}, ...
                     'VariableNames', {'Benchmark', 'Optimizer', 'Function ID', 'Average Fitness', 'Standard Deviation', 'Average Time'});
writetable(resultsTable, "test_results.csv");

cec = 2;

%% Manage function selection%%
if cec==1 %% CEC-2017
    fhd=str2func('cec17_func');
    benchmark_name="CEC2017";
    optimal_values = [100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 1900, 2000, 2100, 2200, 2300, 2400, 2500, 2600, 2700, 2800, 2900, 3000];
    lb=-100*ones(1,dim);
    ub=100*ones(1,dim);
    Tmax=10000*dim; % Maximum number of Function evaluations
elseif cec==2 %% CEC-2022
    fhd=str2func('cec22_func');
    benchmark_name="CEC2022";
    optimal_values = [300, 400, 600, 800, 900, 1800, 2000, 2200, 2300, 2400, 2600, 2700];
    lb=-100*ones(1,dim);
    ub=100*ones(1,dim);
    if dim == 10
        Tmax = 200000;
    elseif dim == 20
        Tmax = 1000000;
    else
        Tmax = 1000000;
    end
end

for i=1:30
    if cec==1 && i==2
        continue;
    elseif cec==2 && i>12
        break
    end

    opt = double(optimal_values(i));
    fobj = @(x) fhd(x, i);
   
    %% Run ACPO and record results
    optimizer = "ACPO";
    disp(optimizer + " Optimizing " + benchmark_name + " Function ID " + num2str(i))
    tic;
    fitnessACPO = zeros(1, RUN_NO);
    Convergence_curve_ACPO = zeros(RUN_NO, Tmax);
    run_times = zeros(1, RUN_NO);
    parfor j=1:RUN_NO 
        t_start = tic;
        [Best_score,Best_pos,Convergence_curve_ACPO(j,:)]=ACPO(CP_no,Tmax,lb,ub,dim,fobj,opt);
        run_times(j) = toc(t_start);
        fitnessACPO(1,j)=Best_score;
    end
    time=toc;
    resultRow = table(benchmark_name, optimizer, i, mean(fitnessACPO(1,:)), std(fitnessACPO(1,:)), mean(run_times));
    writetable(resultRow, "test_results.csv", 'WriteMode', 'Append' )

    figure(i)
    conv_mean = mean(Convergence_curve_ACPO, 1);
    h=semilogy(conv_mean);
    h.MarkerIndices = 1000:20000:min(Tmax, length(conv_mean));
    xlabel('Function Evaluation');
    ylabel('Average Best Fitness obtained so-far');
    axis tight
    grid off
    box on
    legend({'ACPO'});
end

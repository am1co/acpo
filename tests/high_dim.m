CP_no=120; % Number of search agents (crested porcupines)
RUN_NO=30; % Number of independent runs
%dim=[30, 50];
test_result_filename = "test_results\High_Dimensionality_test_results.csv";
convergence_data_folder = "E:\ACPO_Convergence_Curves_Raw\High_Dimensionality";
if ~isfolder(convergence_data_folder)
    mkdir(convergence_data_folder); 
end

resultsTable = table('Size', [0, 6], ...
                     'VariableTypes', {'string', 'string', 'double', 'double', 'double', 'double'}, ...
                     'VariableNames', {'Function', 'Optimizer', 'Average Fitness', 'Standard Deviation', 'Rank-Sum', 'Average Time'});
writetable(resultsTable, test_result_filename); %creates or overwrites file

optimizers = {'CPO'};

cec = 1;
for dim=[30, 50]
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
        %% Manage function selection%%
        if cec==1 && i==2
            continue;
        elseif cec==2 && i>12
            break
        end

        opt = double(optimal_values(i));
        fobj = @(x) fhd(x, i);
        fobj_name = benchmark_name + "_F" + num2str(i) + "_dim" + num2str(dim);
        
        %% Run ACPO and record results
        optimizer = "ACPO";
        disp(optimizer + " Optimizing " + fobj_name)
        fitnessACPO = zeros(1, RUN_NO);
        Convergence_curve = zeros(RUN_NO, Tmax);
        run_times = zeros(1, RUN_NO);
        parfor j=1:RUN_NO 
            t_start = tic;

            [Best_score,Best_pos,Convergence_curve(j,:)]=ACPO(CP_no,Tmax,lb,ub,dim,fobj,opt);
            fitnessACPO(1,j)=Best_score;

            run_times(j) = toc(t_start);
        end
        p = NaN; %this run is the baseline val for rank sum
        resultRow = table(fobj_name, optimizer, mean(fitnessACPO(1,:)), std(fitnessACPO(1,:)), p, mean(run_times));
        writetable(resultRow, test_result_filename, 'WriteMode', 'Append' )

        file_name = optimizer+'_'+fobj_name+'.csv'; 

        full_path = fullfile(convergence_data_folder, file_name);
        writematrix(Convergence_curve, full_path);

        for optim = optimizers
            optimizer = string(optim{:});
            %ALGO = str2func(optimizer);
            disp(optimizer + " Optimizing " + fobj_name)
            fitness = zeros(1, RUN_NO);
            Convergence_curve = zeros(RUN_NO, Tmax);
            run_times = zeros(1, RUN_NO);
            parfor j=1:RUN_NO 
                t_start = tic;

                [Best_score,Best_pos,Convergence_curve(j,:)]=feval(optimizer,CP_no,Tmax,lb,ub,dim,fobj,opt);
                fitness(1,j)=Best_score;

                run_times(j) = toc(t_start);
            end
            p = ranksum(fitnessACPO(1,:),fitness(1,:)); 
            resultRow = table(fobj_name, optimizer, mean(fitness(1,:)), std(fitness(1,:)), p, mean(run_times));
            writetable(resultRow, test_result_filename, 'WriteMode', 'Append' )
                
            file_name = optimizer+'_'+fobj_name+'.csv'; 

            full_path = fullfile(convergence_data_folder, file_name);
            writematrix(Convergence_curve, full_path);
        
        end
    end
end
function [Gb_Fit,Gb_Sol,Conv_curve]=ACPO(Pop_size,Tmax,lb,ub,dim,fobj,opt)
arguments
    Pop_size
    Tmax
    lb
    ub
    dim
    fobj
    opt = inf
end

%%-------------------Controlling parameters--------------------------%%
N=Pop_size; %% Is the initial population size.
N_min=3;
T=1; %% The number of cycles

%%---------------Initialization----------------------%%
% CPO Variables
Conv_curve = zeros(1,Tmax); % Variable to store best fitness value for every iteration
X = initialization(Pop_size,dim,ub,lb); % Initialize the positions of crested porcupines
t = 0; % Function evaluation counter
fitness=zeros(1,Pop_size); % Variable for storing fitness valuea of search agents


% Thompson Sampling variables
K = 2; % Available variation operators
alpha_params = ones(1, K); % Beta distribution success parameters
beta_params = ones(1, K); % Beta distribution failure parameters
global_max_fitness_improvement = 0; % Scalar variable for storing worst fitness improvement in current memory window

% ADWIN variables
active_counts = zeros(1, K); % Tracks the number of valid buckets in each K dimension
delta = 0.1; % Constant for threshold calculation
M = 5; % Maximum number of same-capacity buckets before merging
MAX_BUCKETS = int32(ceil(M*log2((Tmax/M)+1))); % Upper limit of buckets per operator.
buckets = zeros(MAX_BUCKETS, 4, K); % Buckets stored as a 3d array

%%---------------------Initial Evaluation-----------------------%%
for i=1:Pop_size
    fitness(i)=fobj(X(i,:)');
end
% Update the best-so-far solution
[Gb_Fit,index]=min(fitness);
Gb_Sol=X(index,:);
Xp=X; % A new array to store the personal best position for each crested porcupine


%%---------------------Optimization Loop-----------------------%%
while t<=Tmax && Gb_Fit~=opt
    r2=rand;
    f_worst = max(fitness(1:Pop_size));
    for i=1:Pop_size
        U1=rand(1,dim)>rand;
        if rand<rand %% Exploration phase
            exploit = false;
            if rand<rand %% First defense mechanism
                %% Calculate y_t
                y=(X(i,:)+X(randi(Pop_size),:))/2;
                X(i,:)=X(i,:)+(randn).*abs(2*rand*Gb_Sol-y);
            else %% Second defense mechanism
                y=(X(i,:)+X(randi(Pop_size),:))/2;
                X(i,:)=(U1).*X(i,:)+(1-U1).*(y+rand*(X(randi(Pop_size),:)-X(randi(Pop_size),:)));
            end
        else
            exploit = true;

            % Sample from the Beta distribution for each operator
            theta_samples = betarnd(alpha_params, beta_params);
            [~, selected_op] = max(theta_samples);

            Yt=2*rand*(1-t/(Tmax))^(t/(Tmax));
            U2=2*(rand(1,dim)<0.5)-1; % format for equation that folows paper
            S=rand*U2;

            if selected_op == 1 %% Third defense mechanism
                %%
                St=exp(fitness(i)/(sum(fitness)+eps)); % plus eps to avoid division by zero
                S=S.*Yt.*St;
                X(i,:)= (1-U1).*X(i,:)+U1.*(X(randi(Pop_size),:)+St*(X(randi(Pop_size),:)-X(randi(Pop_size),:))-S);

            elseif selected_op == 2 %% Fourth defense mechanism
                Mt=exp(fitness(i)/(sum(fitness)+eps));
                vt=X(i,:);
                Vtp=X(randi(Pop_size),:);
                Ft=rand(1,dim).*(Mt*(-vt+Vtp));
                S=S.*Yt.*Ft;
                alpha = 1-((fitness(i)-f_worst) / (Gb_Fit - f_worst + eps));
                X(i,:)= (Gb_Sol+(alpha*(1-r2)+r2)*(U2.*Gb_Sol-X(i,:)))-S;
            end
        end
        %% Return the search agents that exceed the search space's bounds
        X(i,:) = max(X(i,:), lb);
        X(i,:) = min(X(i,:), ub);

        % Calculate the fitness value of the newly generated solution
        nF=fobj(X(i,:)');

        %%---------------------ADWIN2 Subroutine-----------------------%%
        if exploit
            fitness_improvement = max(0, fitness(i) - nF);
            
            global_max_changed = false;
            if fitness_improvement > global_max_fitness_improvement
                global_max_fitness_improvement = fitness_improvement;
                global_max_changed = true;
            end

            % --- Insertion ---
            c = active_counts(selected_op);
            if c >= MAX_BUCKETS
                error('ADWIN2: MAX_BUCKETS exceeded. Increase the MAX_BUCKETS parameter.');
            end
            
            % Shift existing valid buckets down by 1 row to make room at the top
            if c > 0
                buckets(2:c+1, :, selected_op) = buckets(1:c, :, selected_op);
            end
            % Insert the new observation
            buckets(1, :, selected_op) = [1, fitness_improvement, fitness_improvement, fitness_improvement^2];
            c = c + 1;

            % --- Compression (Merging) ---
            b_idx = 1;
            while b_idx <= c
                cap = buckets(b_idx, 1, selected_op);
                end_idx = b_idx;
                
                % Find contiguous blocks of the same capacity
                while end_idx < c && buckets(end_idx + 1, 1, selected_op) == cap
                    end_idx = end_idx + 1;
                end
                
                if (end_idx - b_idx + 1) > M
                    % Merge the two oldest buckets of this capacity
                    idx1 = end_idx - 1;
                    idx2 = end_idx;
                    
                    merged_cap = buckets(idx1, 1, selected_op) + buckets(idx2, 1, selected_op);
                    merged_sum = buckets(idx1, 2, selected_op) + buckets(idx2, 2, selected_op);
                    merged_max = max(buckets(idx1, 3, selected_op), buckets(idx2, 3, selected_op));
                    merged_square_sum = buckets(idx1, 4, selected_op) + buckets(idx2, 4, selected_op);
                    
                    % Overwrite idx1 with merged data
                    buckets(idx1, :, selected_op) = [merged_cap, merged_sum, merged_max, merged_square_sum];
                    
                    % Shift the remaining array up to overwrite idx2
                    if idx2 < c
                        buckets(idx2:c-1, :, selected_op) = buckets(idx2+1:c, :, selected_op);
                    end
                    c = c - 1; 
                    % Loop re-evaluates at the same b_idx
                else
                    b_idx = end_idx + 1;
                end
            end
            
            % --- Drift Detection ---
            drift_detected = false;
            while c >= 2
                % Extract only the active portion to vectorize the statistics
                B_active = buckets(1:c, :, selected_op);
                n_total = sum(B_active(:, 1));
                sum_total = sum(B_active(:, 2));
                squared_sum_total = sum(B_active(:, 4));
                overall_mean = sum_total./n_total;
                
                n0_arr = cumsum(B_active(1:end-1, 1));
                sum0_arr = cumsum(B_active(1:end-1, 2));
                
                n1_arr = n_total - n0_arr;
                sum1_arr = sum_total - sum0_arr;
                
                raw_vari = (squared_sum_total./n_total) - (overall_mean.^2);
                raw_vari = max(0, raw_vari);

                if global_max_fitness_improvement > 0
                    mu0_arr = (sum0_arr ./ n0_arr) / global_max_fitness_improvement;
                    mu1_arr = (sum1_arr ./ n1_arr) / global_max_fitness_improvement;
                    scaled_vari = raw_vari / (global_max_fitness_improvement^2);
                else
                    mu0_arr = sum0_arr ./ n0_arr;
                    mu1_arr = sum1_arr ./ n1_arr;
                    scaled_vari = raw_vari;
                end
                
                m_arr = (1./n0_arr + 1./n1_arr).^(-1);
                delta_prime = delta/log(n_total);
                epsilon_cut_arr = sqrt((2./m_arr).*scaled_vari.*log(2/delta_prime))+((2/(3.*m_arr))*log(2/delta_prime));
                if any(abs(mu0_arr - mu1_arr) >= epsilon_cut_arr)
                    drift_detected = true;
                    % Drop the oldest bucket by simply ignoring the last valid row
                    c = c - 1; 
                else
                    break;
                end
            end
            
            % Save the final active count for this operator
            active_counts(selected_op) = c;

            % --- The Global Reset Protocol ---
            if drift_detected
                % Find the new global minimum window capacity across all operators
                w_t = inf;
                for k = 1:K
                    if active_counts(k) > 0
                        cap_k = sum(buckets(1:active_counts(k), 1, k));
                        if cap_k < w_t
                            w_t = cap_k;
                        end
                    else
                        w_t = 0;
                    end
                end

                global_max_fitness_improvement = 0;

                % Drop oldest buckets to match w_t and recalculate the global max
                for k = 1:K
                    c_k = active_counts(k);
                    if c_k > 0
                        cum_caps = cumsum(buckets(1:c_k, 1, k));
                        keep_idx = find(cum_caps <= w_t, 1, 'last');
                        
                        if isempty(keep_idx)
                            active_counts(k) = 0;
                        else
                            active_counts(k) = keep_idx;
                        end
                    end

                    % Update global_max from the newly trimmed windows
                    if active_counts(k) > 0
                        bucket_max = max(buckets(1:active_counts(k), 3, k));
                        if bucket_max > global_max_fitness_improvement
                            global_max_fitness_improvement = bucket_max;
                        end
                    end
                end
            end

            % --- Posterior Updates ---
            if drift_detected || global_max_changed
                for k = 1:K
                    c_k = active_counts(k);
                    if c_k > 0
                        if global_max_fitness_improvement > 0
                            scaled_sum = sum(buckets(1:c_k, 2, k)) / global_max_fitness_improvement;
                        else
                            scaled_sum = 0;
                        end
                        alpha_params(k) = 1 + scaled_sum;
                        beta_params(k) = 1 + sum(buckets(1:c_k, 1, k)) - scaled_sum;
                    else
                        alpha_params(k) = 1;
                        beta_params(k) = 1;
                    end
                end
            else
                % Standard Bayesian update
                if global_max_fitness_improvement > 0
                    scaled_reward = fitness_improvement / global_max_fitness_improvement;
                else
                    scaled_reward = 0;
                end
                alpha_params(selected_op) = alpha_params(selected_op) + scaled_reward;
                beta_params(selected_op) = beta_params(selected_op) + (1 - scaled_reward);
            end
        end

        %% update Global & Personal best solution
        if fitness(i)<nF
            X(i,:)=Xp(i,:); % Update local best solution
        else
            Xp(i,:)=X(i,:);
            fitness(i)=nF;
            %% update Global best solution
            if fitness(i)<=Gb_Fit
                Gb_Sol=X(i,:); % Update global best solution
                Gb_Fit=fitness(i);
            end
        end

        t=t+1; % Move to the next generation
        if t>Tmax
            break
        end
        Conv_curve(t)=Gb_Fit;

    end
    Pop_size=fix(N_min+(N-N_min)*(1-(rem(t,Tmax/T)/(Tmax/T))));

end

if t < Tmax
    Conv_curve(t+1:end) = Gb_Fit;
end

end


function Positions=initialization(SearchAgents_no,dim,ub,lb)

Boundary_no= length(ub); % numnber of boundaries

% If the boundaries of all variables are equal and user enter a signle
% number for both ub and lb
if Boundary_no==1
     Positions=rand(SearchAgents_no,dim).*(ub-lb)+lb;
end

% If each variable has a different lb and ub
if Boundary_no>1
    for i=1:dim
        ub_i=ub(i);
        lb_i=lb(i);
         Positions(:,i)=rand(SearchAgents_no,1).*(ub_i-lb_i)+lb_i;      
    end
end
end
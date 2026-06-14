function J = welded_beam(x)
% Calculates the fitness (Cost + Penalty) for the Welded Beam problem.
%
% Input:  x = [h, l, t, b] (1x4 vector)
% Output: J = Total Cost (including penalties for violations)


    %% Calculate Pure Objective (Cost)
    % f(X) from the problem description
    cost = (1.10471 * (x(1)^2) * x(2)) + (0.04811 * x(3) * x(4) * (14.0 + x(2)));

    %% Define Constants
    P = 6000; 
    L = 14; 
    E = 30e6; 
    G = 12e6;
    tau_max = 13600; 
    sigma_max = 30000; 
    delta_max = 0.25;

    %% Calculate Stresses and Physics
    % Shear Stress (tau) terms
    tau_prime = P / (sqrt(2) * x(1) * x(2));
    M = P * (L + (x(2) / 2));
    R = sqrt((x(2)^2 / 4) + ((x(1) + x(3)) / 2)^2);
    
    % Polar Moment of Inertia (J_polar)
    J_polar = 2 * ((sqrt(2) * x(1) * x(2)) * ((x(2)^2 / 4) + (((x(1) + x(3)) / 2)^2)));
    
    tau_double_prime = (M * R) / J_polar;
    tau_val = sqrt((tau_prime^2) + (2*tau_prime*tau_double_prime*(x(2)/(2*R))) + (tau_double_prime^2));

    % Bending Stress (sigma)
    sigma_val = (6 * P * L) / (x(4) * x(3)^2);

    % Deflection (delta)
    delta_val = (6 * P * L^3) / (E * (x(3)^2) * x(4));

    % Buckling Load (Pc)
    pc_part1 = (4.0134 * E * sqrt(((x(3)^2) * (x(4)^6)) / 36)) / (L^2);
    pc_part2 = 1 - (x(3) / (2 * L)) * sqrt(E / (4 * G));
    Pc_val = pc_part1 * pc_part2;

    %% Evaluate Constraints (g <= 0)
    % If the result is > 0, the constraint is violated.
    g = zeros(7, 1);
    
    g(1) = tau_val - tau_max;         % Shear
    g(2) = sigma_val - sigma_max;     % Bending
    g(3) = delta_val - delta_max;     % Deflection
    g(4) = x(1) - x(4);                     % Geometry (x1 - x4)
    g(5) = P - Pc_val;                % Buckling
    g(6) = 0.125 - x(1);                 % Geometry (Min weld size)
    g(7) = cost - 5.0;                % Budget Constraint (from your image)

    if any(g > 0)
        J = 1e15;  % Assign high value so the algorithm rejects it
    else
        J = cost; % Assign the actual cost
    end
end
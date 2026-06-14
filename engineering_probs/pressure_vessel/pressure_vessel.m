function J = pressure_vessel(x)

    % f(x) from the problem description
    cost = 0.6224*x(1)*x(3)*x(4)+1.7781*x(3)*x(1)^2+3.1661*x(1)^2*x(4)+19.84*x(1)^2*x(3);

    g = zeros(4, 1);
    
    g(1) = -x(1) + (0.0193*x(3));
    g(2) = -x(3) + (0.00954*x(3));
    g(3) = -(pi*x(4)*(x(3)^2))-((4/3)*(x(3)^3))+1296000;
    g(4) = x(4) - 240;

    %death penalty
    if any(g > 0)
        J = 1e15;  % Assign high value so the algorithm rejects it
    else
        J = cost; % Assign the actual cost
    end
end
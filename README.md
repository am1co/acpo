# An Adaptive Crested Porcupine Optimizer (ACPO) via Thompson-ADWIN Operator Selection, Dynamic Convergence Rate Scaling, and Linear Population Size Reduction

A special problem submitted to the Department of Mathematics and Computer Science, College of Science, The University of the Philippines Baguio, Baguio City as partial fulfillment of the requirements for the degree of Bachelor of Science in Computer Science

## Created and Developed by: 
- Cyrus Kael Abiera
- Alexis Harriet Cardenas

## Project Overivew
This thesis introduces the Adaptive Crested Porcupine Optimizer (ACPO), an enhanced metaheuristic optimization algorithm. The original Crested Porcupine Optimizer (CPO) is highly effective for solving complex, optimization problems but is relies on static, predefined control parameters. ACPO eliminates the need for manual hyperparameter tuning by integrating dynamic, self-adjusting mechanisms that adapt to the optimization landscape on the fly.

## Key Adaptive Mechanisms
The ACPO framework improves upon the original CPO through three core modifications:
1. Thompson Sampling & Adaptive Windowing (TS-ADWIN2): A dynamic Multi-Armed Bandit framework that governs the transition between the algorithm's exploration and exploitation phases, eliminating the need for the static tradeoff parameter ($T_f$).
2. Dynamic Convergence Rate Scaling: Utilizes a complemented fitness-based min-max formulation to autonomously tune the convergence rate parameter ($\alpha$) based on the relative performance of each search agent.
3. Linear Population Size Reduction (LPSR): Simplifies the original Cyclic Population Reduction mechanism by setting the cycle parameter to $T=1$ and mathematically deriving a new, fixed optimal minimum population size of $N_{min}=3$.

## Evaluation
ACPO was benchmarked against the original CPO, classical metaheuristics, and state-of-the-art algorithms using the IEEE CEC 2017 and CEC 2022 benchmark suites, including high-dimensionality (30D and 50D) problems. The algorithm was also applied to engineering design problems (e.g., Welded Beam, Pressure Vessel, and Multi-bar Truss designs). 

## Results
Wilcoxon rank-sum tests confirmed that ACPO achieved statistically significant improvements in fitness, stability, and scalability compared to its competitors, with the LPSR technique identified as the primary driver of performance improvements. Furthermore, ACPO success fully managed practical constraints in engineering applications. However, there was an observed increase in computational runtime due to the algorithmic computations of ADWIN2. Due to its superior accuracy and robustness across benchmarks and engineering problems, ACPO establishes itself as a reliable adaptive optimization framework.

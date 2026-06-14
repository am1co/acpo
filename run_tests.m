clear
clc

algoFolderPath = fullfile(pwd, 'optimizers');
addpath(algoFolderPath);
testsFolderPath = fullfile(pwd, 'tests');
addpath(testsFolderPath);

disp('Running Test: Algorithm Functionality');
algo_functionality;
clear
disp('Running Test: CPO Comparison');
cpo_comp;
clear
disp('Running Test: Algorithm Comparisons');
algo_comp;
clear
disp('Running Test: High Dimensionality');
high_dim;
clear
disp('Running Test: Engineering Problems');
eng_probs;
clear

rmpath(algoFolderPath);
rmpath(testsFolderPath);
%% ========================================================================
%  VISUALIZATION RESULTS - CENTRALIZED VISUALIZATION SUITE
%  ========================================================================

clear all;
close all;
clc;

% Set up paths
csv_file = 'in/algo comparison/Algorithm_Comparison_Fitness.csv';
time_csv_file = 'in/time/Algorithm_Comparison_AvgTime.csv';
boxplot_dir = 'in/conv_curves/';
dimension_dir = 'in/dimension/';

% generate_all_bar_graphs(csv_file);

% generate_fitness_boxplots(boxplot_dir);
% generate_runtime_bar_graph(time_csv_file);

generate_dimensionality_analysis(dimension_dir);
disp('Visualization suite execution complete.');
disp('Check generated figures for results.');


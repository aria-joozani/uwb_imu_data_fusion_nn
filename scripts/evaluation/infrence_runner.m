


clc; close all; clear all;
projectRoot = setup_project();
load(fullfile(projectRoot, 'config', 'legacy', 'trials.mat'));
data = trials{1};
net = '2';
inference;

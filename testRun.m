% Run training and testing from scratch using settings from train.m and
% predict.m

clear


%% Delete existing features

del = dir('*.mat');
nFiles = numel(del);
for f = 1:nFiles
    delete(del(f).name)
end


%% Run
st = tic;

% Run feature gen and training 
train
% Run feature gen and predicition
predict

et = toc(st);


%% Report

disp(['Test run time taken: ' num2str(et), ' s'])


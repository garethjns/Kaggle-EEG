% Run training and testing from scratch using settings from train.m and
% predict.m

clear


%% Delete existing features and models
% If models or features already exist, create a folder and "delete" them in
% to it

del = dir('*.mat');

if numel(del)>1
    % Folder name
    d = string(datetime).replace(':','_').replace('-','_').char();
    mkdir(d)
    
    % Move files
    nFiles = numel(del);
    for f = 1:nFiles
        movefile(del(f).name, [d, '\', del(f).name])
    end
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


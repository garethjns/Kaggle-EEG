function params = setParams(params)

% HW params
params.Fs = 400;
% Number of channels
params.nChans = 16;

% Subjects to include
params.trainSubs = {'1', '2', '3'};
nSubs = numel(params.trainSubs);
params.testSubs = {'1', '2', '3'};

% OK Check params
% Marks files as OK in fileList if proportion of zeros is below this
% threshold
% Not used anymore
params.OKThresh = 0.5; 

% Feature extraction params
params.HillsBands.Range = 1:47;

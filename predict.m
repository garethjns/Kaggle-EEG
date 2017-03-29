%% Test - general models
%
% Version 61
% Loads trained models from params.ModelPath
% Loads and prcoesses test data from params.paths
% Predicts outcomes and saves submission file
%
% Bugs and notes:
% Feature names still being joined incorrectly but leaving as is for now to
% work with submitted models
% use structure not being saved in seizureModels so is re-set here

startTime = tic;


%% Set path to test data
% Set paths and prepare parameters

% params.paths = 'S:\EEG Data Mini\';
params.paths.dataDir = 'S:\EEG Data\New\';
params.paths.ModelPath = 'trainedModelsCompactTest.mat';

params.master = 61; % Version
params.nSubs = 3;

% Other params
% Edit in function
params = setParams(params);
params.plotOn = 0;

warning('off', 'MATLAB:table:RowsAddedExistingVars')


%% Load trained models
% Load the trained models from params.ModelPath

a = load(params.paths.ModelPath);
% Models may be names *Compact, or not
% Rename to RBTg and SVMg
flds = string(fieldnames(a));
RBTg = a.(flds(flds.contains('RBT')).char());
SVMg = a.(flds(flds.contains('SVM')).char());
clear a flds


%% Process test set
% Sequentially Load the test set data from params.paths, extract features,
% and join epochs of different lengths

params.tt = 'Test';

% Features to use
% Need to save this in serizureModel during training
clear use
use.hillsBandsLog2D = 0;
use.hillsBandsLogAv = 1;
use.maxHills2D = 1;
use.maxHillsAv = 1;
use.summ32D = 1;
use.summ3Av = 1;
use.bandsLin2D = 1;
use.bandsLinAv = 1;
use.maxBands2D = 1;
use.maxBandsAv = 1;
use.mCorrsT = 1;
use.mCorrsF = 1;

% Create features object for test
disp('Creating basic features')

% Epoch window sizes to use
% Needs to match models used, but isn't saved in models at the moment so
% reset here
params.divS = [240, 160, 80];

% Create object
featuresTest = featuresObject(params, use);

% Compile available features
featuresTest = featuresTest.compileFeatures();


%% Predict new data
% Make predictions from each seizureModel for each epoch and reduce to 
% predictions for each segment (ie., each file in test set as test set 
% segments are all individual 10 minute files).

% Predict for each epoch
% Using seizureModel.predict()
preds.Epochs.RBTg = RBTg.predict(featuresTest.dataSet);
preds.Epochs.SVMg = SVMg.predict(featuresTest.dataSet);

% Compress predictions nEpochs -> nFiles (nSegs)
% Take predictions for all epochs, reduces these down to length of fileList
% Total number of epochs
nEps = height(featuresTest.dataSet);
% Number of epochs per subSeg
eps = featuresTest.SSL.Of(1);

% Convert SubSegID to 1:height(fileList)
accArray = reshape(repmat((1:nEps/eps),eps,1), 1, nEps)';

% Use to accumulate values and average
fns = fieldnames(preds.Epochs);
for f = 1:numel(fns)
    fn = fns{f};
    preds.Segs.(fn) = accumarray(accArray, preds.Epochs.(fn))/eps;
end
clear accArray


%% Save submission files
% Create submission file for each model and the ensembeled version

note = '';

% From individual models
% saveSub([note,'SVMGen'], featuresTest.fileLists, preds.Segs.SVMg, params)
% saveSub([note,'RBTGen'], featuresTest.fileLists, preds.Segs.RBTg, params)

% Combined sub: SVMg and RBTg
saveSub([note,'SVMgRBTg'], featuresTest.fileLists, ...
    nanmean([zscore2(preds.Segs.RBTg),zscore2(preds.Segs.SVMg)],2), ...
    params)

endTime = toc(startTime);
disp(['Testing time taken: ', num2str(endTime), ' s'])

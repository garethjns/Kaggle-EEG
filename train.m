%% Training
% Train SVM and RBT general models from original Kaggle data
% 'Name' and 'use' bugs not fixed yet

startTime = tic;


%% Set path to test data
% Set paths and prepare parameters

% Use training data from here
params.paths.dataDir = 'S:\EEG Data\New\'; 

% Use these paths to create training set from original Kaggle data
params.paths.or = 'S:\EEG Data\Original\';
% Path to new training and test sets
params.paths.new = params.paths.dataDir;
params.paths.ModelPath = 'trainedModelsCompactTest.mat';

params.master = 61; % Version
params.nSubs = 3;

% Other params
% Edit in function
params = setParams(params);
params.plotOn = 0;
params.modParams.plotOn = false;
params.redoCopy = 0;

warning('off', 'MATLAB:table:RowsAddedExistingVars')


%% Prepare raw data
% Create new training directory from original Kaggle data as per list of
% safe files.
% Creates singles.mat needed for this set

if params.redoCopy
    copyTestLeakToTrain(params.paths)
end

%% Process training set

params.tt = 'Train';

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
params.divS = [600, 400, 240, 160, 80];

% Create object
featuresTrain = featuresObject(params, use);

% Compile available features
featuresTrain = featuresTrain.compileFeatures();


%% Run training

% Set model and cv parameters
% CV
params.cvParams.cvMode = 'Custom';
params.cvParams.k = 6;
params.cvParams.evalProp = 0.2;
params.cvParams.overSample = 0.05;
params.cvParmas.seed = 2222;
% Both models
params.modParams.keepIdx = featuresTrain.keepIdx;
params.modParams.prior = 'Empirical';
params.modParams.hyper = 0;
params.modParams.standardize = true;
params.modParams.seed = 1111;
% SVM
params.modParams.polyOrder = 2;
params.modParams.BC = 1000;
% RBT
params.modParams.nLearners = 100;
params.modParams.LearnRate = 1;
params.modParams.MaxNumSplits = 20;

% Run train function
[SVMg, RBTg] = trainModels(featuresTrain, params);


%% Assess CV AUC and save to disk

% Run compare models
disp(['SVM: general model AUC: ', num2str(SVMg.AUCScore)])
disp(['RBT: general model AUC: ', num2str(RBTg.AUCScore)])

% Save compact models to disk (params.paths.ModelPath)
SVMgCompact = SVMg.shrink();
RBTgCompact = RBTg.shrink();
save(params.paths.ModelPath, 'SVMgCompact', 'RBTgCompact')

% Report time taken
endTime = toc(startTime);
disp(['Training time taken: ', num2str(endTime), ' s'])
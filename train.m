%% Set path to test data
% Set paths and prepare parameters

% params.paths = 'S:\EEG Data Mini\';
params.paths.dataDir = 'S:\EEG Data\'; 
params.paths.or = [params.paths.dataDir, 'Original\'];
% Path to new training and test sets
params.paths.new = [params.paths.dataDir, 'New\'];
params.paths.ModelPath = 'trainedModelsCompact.mat';

rng(1000) % Probably does nothing here
startTime = tic;

params.master = 61; % Version
params.nSubs = 3;

% Other params
% Edit in function
params = setParams(params);

warning('off', 'MATLAB:table:RowsAddedExistingVars')


%% Prepare raw data
% Create new training directory from original Kaggle data as per list of
% safe files.
% Creates singles.mat needed for this set

copyTestLeakToTrain(params.paths)


%% Process training set

params.tt = 'train';

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
params.divS = [240, 160, 80];

% Create object
featuresTrain = featuresObject(params, use);

% Compile available features
featuresTrain = featuresTrain.compileFeatures();


%% Run training

% Set model parameters

% Run train function

% Run compare models

% Save models to disk (params.paths.ModelPath)
function [SVMg, RBTg] = trainModels(features, params)


%% General SVM

disp('Training all subjects SVM')

% Create CV object
cv = cvPart(features.fileLists, features.SSL, ...
    params.cvParams);

% Create model object
params.modParams.type = 'SVM';
SVMg = seizureModel(params.modParams, cv);

% Train model
SVMg = SVMg.train(features.dataSet, [], 'General');

% Assess model
SVMg = SVMg.assessMod(features.dataSet);
% And plot if on
if params.modParams.plotOn
    SVMg.plotAUCs('General model');
end


%% Increment seeds

params.cvParmas.seed = params.cvParmas.seed+100;
params.modParams.seed = params.modParams.seed+100;
 

%% General RBT

disp('Training all subjects RBT')

% Create cv object with new seed
cv = cvPart(features.fileLists, features.SSL, ...
    params.cvParams);

% Create model object
params.modParams.type = 'RBT';
RBTg = seizureModel(params.modParams, cv);

% Train model
RBTg = RBTg.train(features.dataSet, [], 'General');

% Assess model
RBTg = RBTg.assessMod(features.dataSet);
% And plot if on
if params.modParams.plotOn
    RBTg.plotAUCs('General model');
end

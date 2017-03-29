classdef seizureModel
    properties
        featureType = string('Untrained')
        params % Initial params supplied
        seed = rng;
        cv % cvPartition object for reference
        trained % Model for each k fold
        trainedData % Data used for training
        AUCs % AUC for each k model
        meanAUC % Overall AUC
        AUCScore % Mean AUC, quick access
        hyper = 0;
        modParams % nLearners, box constraint etc - test implementation
        keepIdx % From features -> modParams
        prior % Expected Y==1 Prop
    end
    
    properties (SetAccess = immutable)
        type = string('SVM')
        modelFcn = @obj.trainSVM
        k % Number of folds
        cvType
    end
    
    methods
        function obj = seizureModel(params, cvp)
            
            obj.params = params;
            obj.cv = cvp;
            % Set type of model - SVM default
            if isfield(params, 'type')
                obj.type = string(params.type);
            end
            
            % Set seed, if specified
            if isfield(params, 'seed')
                obj.seed = params.seed;
            end
            rng(obj.seed)
            rng(obj.seed)
            
            % Set keepIdx
            obj.keepIdx = params.keepIdx;
            
            % What type of cv object provided?
            if isa(cvp, 'cvpartition')
                % Matlab CV object
                obj.cvType = string('MATLAB');
                obj.k = obj.cv.NumTestSets;
            else % Assume cvPart - segment aware
                obj.cvType = string('Custom');
                obj.k = obj.cv.k;
            end
            
            
            % Set any supplied model parameters
            if isfield(params, 'BC')
                obj.modParams.BC = params.BC;
            end
            if isfield(params, 'nLearners')
                obj.modParams.nLearners = params.nLearners;
            end
            if isfield(params, 'LearnRate')
                obj.modParams.LearnRate = params.LearnRate;
            end
            if isfield(params, 'MaxNumSplits')
                obj.modParams.MaxNumSplits = params.MaxNumSplits;
            end
            if isfield(params, 'prior')
                % Set method
                obj.prior = params.prior;
            end
            if isfield(params, 'standardize')
               obj.modParams.standardize = params.standardize;
            else
                obj.modParams.standardize = true;
            end
            
            % Set model function
            switch obj.type
                case 'SVM'
                    % NB: Methods must be static to use as function handles
                    obj.modelFcn = @obj.trainSVM;
                case 'RBT'
                    obj.modelFcn = @obj.trainRBT;
            end
        end
        
        function obj = set.prior(obj, pri)
            if ~strcmp(pri, 'Empirical')
                pri = [pri, 1-pri];
            end
            
            obj.prior = pri;
        end
        
        function obj = train(obj, feas, labels, subsRef)
            
            % Set model type
            feaNames = string(feas.Properties.VariableNames);
            
            if any(feaNames.contains('Subject'))
                if numel(unique(feas.Subject)) == 1
                    s1 = 'Single';
                elseif numel(unique(feas.Subject)) > 1
                    s1 = 'Hybrid';
                end
            else
                % No subject column so need to be told subsRef
                if numel(unique(subsRef)) == 1
                    s1 = 'Single';
                elseif numel(unique(subsRef)) > 1
                    s1 = 'General';
                end
            end
            
            if any(feaNames.contains('Grads'))
                if sum(feaNames.contains('Grads')) == width(feas)/2
                    s2 = 'FullGrads';
                else
                    s2 = 'PartialGrads';
                end
            else
                s2 = 'NoGrads';
            end
            
            obj.featureType = string({s1,s2});
            
            % Set any single, general, hybrid specific options
            switch obj.featureType{1}
                case 'Single'
                    obj.modParams.ScoreTransform = 'none';
                otherwise
                    obj.modParams.ScoreTransform = 'none';
            end
            
            % Train
            switch obj.cvType
                case 'MATLAB'
                    obj = trainMatlabCV(obj, feas, labels);
                case 'Custom'
                    % Labels not required
                    obj = trainCustomCV(obj, feas);
            end
        end
        
        function obj = trainCustomCV(obj, feas)
            % Train the type of model requested, for each k
            % Using features in feas
            % If cv is MATLAB, labels also required
            % If custom, it can get from cv object.
            
            % Do training
            for ki = 1:obj.k
                % Get just the data required for this fold
                data = obj.cv.getData(ki, feas, obj.keepIdx);
                % Get labels from cv object
                dataList = obj.cv.listData(ki, obj.keepIdx);
                labels = dataList.Class;
                
                % This disp doesn't disp as expected
                disp(['Training ', obj.type, ' ', num2str(ki), ...
                    ' of ', num2str(obj.k)])
                
                % Save fold data
                obj.trained{ki} = obj.modelFcn(obj, data, labels);
                obj.trainedData{1,ki} = data;
                obj.trainedData{2,ki} = labels;
            end
        end
        
        function obj = trainMatlabCV(obj, feas, labels)
            % Send all data and let MATLAB handle cv
            mods = obj.modelFcn(obj, feas, labels);
            
            % Save models in trained
            obj.trained = mods;
        end
        
        function obj = assessMod(obj, feas, labels)
            switch obj.cvType + obj.hyper
                case 'MATLAB0'
                    % Just use kfold predict?
                    [~, P] = obj.trained.kfoldPredict;
                    [AUC.X, AUC.Y, ~, AUC.AUC] = ...
                        perfcurve(table2array(labels), P(:,2), 1);
                    obj.AUCs{1,1} = AUC;
                    obj.AUCScore = AUC.AUC;
                case 'MATLAB1'
                    % No kfold predict?
                    cv = obj.trained.crossval;
                    [~, P] = cv.kfoldPredict;
                    [AUC.X, AUC.Y, ~, AUC.AUC] = ...
                        perfcurve(table2array(labels), P(:,2), 1);
                    obj.AUCs{1,1} = AUC;
                    obj.AUCScore = AUC.AUC;
                case {'Custom0', 'Custom1'}
                    % Return model assessment, labels and data not required
                    aucs = NaN(1, obj.k, 'single');
                    % obj.meanAUC.X = NaN(1,obj.k,'single'); % Not full preallocation
                    % obj.meanAUC.Y = NaN(1,obj.k,'single'); % Removed for now
                    for ki = 1:obj.k
                        % Get data from cv object and features
                        data = ...
                            obj.cv.getEvalData(ki, feas, obj.keepIdx);
                        % Get labels from cv object
                        dataList = ....
                            obj.cv.listEvalData(ki, obj.keepIdx);
                        labels = dataList.Class;
                        
                        % Predict this data (using model method, not
                        % seizureObject.predict() which applies
                        % standardisation for RBTs if on
                        % Therefore, need to standardise here first if on
                        switch obj.type + obj.modParams.standardize
                            case 'RBTtrue'
                                data{:,:} = ...
                                    zscore2(table2array(data));
                        end
                        
                        [~, P] = obj.trained{ki}.predict(data);
                        
                        [AUC.X, AUC.Y, ~, AUC.AUC] = ...
                            perfcurve(labels, P(:,2), 1);
                        
                        % Store AUC details
                        obj.AUCs{1,ki} = AUC;
                        % Store to calcualte AUCScore field
                        aucs(1,ki) = AUC.AUC;
                        % Store to calculate average AUC
                        % Removed for now - not always same length (due to
                        % keepIdx?)
                        % obj.meanAUC.X = obj.meanAUC.X + AUC.X;
                        % obj.meanAUC.Y = obj.meanAUC.Y + AUC.Y;
                    end
                    
                    obj.AUCScore = mean(aucs,2);
                    % obj.meanAUC.X = meanAUC.X/obj.k;
                    % obj.meanAUC.Y = meanAUC.Y/obj.k;
            end
            
        end
        
        function h = plotAUCs(obj, str)
            h = figure; hold on
            nPlots = numel(obj.AUCs);
            
            % Plot for each fold
            leg = cell(nPlots, 1);
            for ki = 1:nPlots
                plot(obj.AUCs{1,ki}.X, obj.AUCs{1,ki}.Y)
                leg{ki} = num2str(obj.AUCs{1,ki}.AUC);
            end
            legend(leg)
            title([str, ' ', obj.type, ...
                ' Mean AUC ', num2str(obj.AUCScore)])
            drawnow 
        end
        
        function [preds, allP, allY] = predict(obj, newData)
            % Predict new data
            
            % If this is a RBT and standardise is on, need to do this
            % manually
            switch obj.type + obj.modParams.standardize
                case 'RBTtrue'
                    newData{:,:} = zscore2(table2array(newData));
            end
            
            % Make prediction
            allP = NaN(size(newData,1), obj.k, 'single');
            allY = NaN(size(newData,1), obj.k, 'single');
            for ki = 1:obj.k
                disp(['Predicting from fold: ', ...
                    num2str(ki), '/', num2str(obj.k)])
                [allY(:,ki), P] = ...
                    obj.trained{1,ki}.predict(newData);
                allP(:,ki) = P(:,2);
            end
            
            preds = mean(allP,2);
            
        end
        
        function obj = shrink(obj)
            % Delete trainedData field to shrink size
            obj.trainedData = cell(1, obj.k);
            
            % Also run through trained models and .compact
            nMods = numel(obj.trained);
            for m = 1:nMods
                obj.trained{m} = obj.trained{m}.compact;
            end
        end
        
        
        
        function h = featureImportance(obj)
            
            % No predictorImportance available for SVMs
            switch obj.type
                case 'SVM'
                    disp('Can''t run on SVM :(')
                    return
            end
            
            % Get names of features
            names = string(obj.trained{1,1}.X.Properties.VariableNames);
            nF = numel(names);
            % Calculate mean importance
            fImp = NaN(obj.k, nF);
            for ki = 1:obj.k
               fImp(ki,:) = predictorImportance(obj.trained{1,ki});
            end
            
            % Plot all and sorted version
            x = 1:nF;
            yMean = mean(fImp);
            yStd = std(fImp);
            
            [yMeanSor, sorIdx] = sort(yMean, 'descend');
            yStdSor = yStd(sorIdx);
            namesSor = names(sorIdx);
            
            h = figure;
            subplot(2,1,1)
            errorbar(x, yMean, yStd)
            title('All features')
            xlabel('Index of feature')
            ylabel('Mean importance')
            subplot(2,1,2)
            errorbar(x(1:20), yMeanSor(1:20), yStdSor(1:20))
            a = gca;
            % Add shortened names to xaxis
            a.XTick = 1:20;
            a.XTickLabel = namesSor(1:20).extractBetween(1, 15);
            a.XTickLabelRotation = -45;
            title('Top 20 features')
            ylabel('Mean importance')
            
        end
    end
    
    methods (Static)
        function SVM = trainSVM(obj, data, labels)
            
            % Setup prior
            switch obj.cvType + obj.hyper
                case 'MATLAB0'
                    % No hyperparamter optimisation - CV object goes to fit
                    % function
                    SVM = fitcsvm(data, ...
                        labels, ...
                        'CacheSize', 'maximal', ...
                        'KernelFunction', 'polynomial', ...
                        'PolyNomialOrder', obj.params.polyOrder, ...
                        'KernelScale', 'auto', ...
                        'NumPrint', 100, ...
                        'Prior', 'empirical', ...
                        'ScoreTransform', obj.modParams.ScoreTransform, ...
                        'Standardize', obj.modParams.standardize, ...
                        'Verbose', 0, ...
                        'CVPartition', obj.cv);
                case 'MATLAB1'
                    % Hyperparameter optimisation - CV object goes to
                    % hyperparams options structre. Presumably uses same
                    % params for all k folds?
                    opts = struct('CVpartition', obj.cv);
                    SVM = fitcsvm(data, ...
                        labels, ...
                        'CacheSize', 'maximal', ...
                        'KernelFunction', 'polynomial', ...
                        'PolyNomialOrder', obj.params.polyOrder, ...
                        'KernelScale', 'auto', ...
                        'NumPrint', 100, ...
                        'Prior', 'empirical', ...
                        'ScoreTransform', obj.modParams.ScoreTransform, ...
                        'Standardize', obj.modParams.standardize, ...
                        'Verbose', 0, ...
                        'OptimizeHyperparameters', 'auto', ...
                        'HyperparameterOptimizationOptions', opts ...
                        );
                case 'Custom0'
                    % No hyperparameter optimisation. No cv object passed
                    % to fit function - this is called separately for each
                    % k fold
                    SVM = fitcsvm(data, ...
                        labels, ...
                        'CacheSize', 'maximal', ...
                        'KernelFunction', 'polynomial', ...
                        'PolyNomialOrder', obj.params.polyOrder, ...
                        'KernelScale', 'auto', ...
                        'NumPrint', 100, ...
                        ... 'Prior', 'empirical',
                        'Prior', obj.prior, ...
                        'ScoreTransform', obj.modParams.ScoreTransform, ...
                        'Standardize', obj.modParams.standardize, ...
                        'Verbose', 0, ...
                        'BoxConstraint', obj.modParams.BC);
                case 'Custom1'
                    % No cv object passed
                    % to fit function - this is called separately for each
                    % k fold. Hyperparameter optimsation on - means
                    % different parameters for each kfold - is this a
                    % sensible approach??
                    close all force
                    SVM = fitcsvm(data, ...
                        labels, ...
                        'CacheSize', 'maximal', ...
                        'KernelFunction', 'polynomial', ...
                        'PolyNomialOrder', obj.params.polyOrder, ...
                        'KernelScale', 'auto', ...
                        'NumPrint', 100, ...
                        'Prior', 'empirical', ...
                        'ScoreTransform', obj.modParams.ScoreTransform, ...
                        'Standardize', obj.modParams.standardize, ...
                        'Verbose', 0, ...
                        'OptimizeHyperparameters', 'auto' ...
                        );
            end
        end
        
        function RBT = trainRBT(obj, data, labels)
            % Prepare weak learner
            treeLearner = templateTree(...
                'MaxNumSplits', obj.modParams.MaxNumSplits ... Default in CL is 20
                );
            
            % Standardise if on (needs to be manual for RBT)
            switch obj.modParams.standardize
                case true
                    trData = array2table(zscore2(data{:,:}));
                    trData.Properties.VariableNames = ...
                        data.Properties.VariableNames;
                case false
                    trData = data;
            end
            
            % Train
            switch obj.cvType + obj.hyper
                case 'MATLAB0'
                    RBT = fitensemble(trData, ...
                        labels, ...
                        'RUSBoost', ... model
                        30, ... n weak learners
                        treeLearner, ... type(s) of weak learners
                        'LearnRate', 0.1, ...
                        'CVPartition', obj.cv, ...
                        'ScoreTransform', obj.modParams.ScoreTransform, ...
                        ... 'leanrate', 0.1, ... 0.1 default learn rate in CLA
                        'nprint', 100);
                case 'MATLAB1'
                    opts = struct('CVpartition', obj.cv);
                    RBT = fitensemble(trData, ...
                        labels, ...
                        'RUSBoost', ... model
                        30, ... n weak learners
                        treeLearner, ... type(s) of weak learners
                        'LearnRate', 0.1, ...
                        'CVPartition', obj.cv, ...
                        'ScoreTransform', obj.modParams.ScoreTransform, ...
                        ... 'leanrate', 0.1, ... 0.1 default learn rate in CLA
                        'nprint', 100, ...
                        'OptimizeHyperparameters', 'auto', ...
                        'HyperparameterOptimizationOptions', opts ...
                        );
                case 'Custom0'
                    RBT = fitcensemble(trData, ...
                        labels, ...
                        'Method', 'RUSBoost', ... model
                        'NumLearningCycles', obj.modParams.nLearners, ... n weak learners
                        'Learners', treeLearner, ... type(s) of weak learners
                        'LearnRate', obj.modParams.LearnRate, ...
                        'ScoreTransform', obj.modParams.ScoreTransform, ...
                        'Prior', obj.prior, ...
                        'nprint', 100);
                case 'Custom1'
                    % Needs checking
                    RBT = fitcensemble(trData, ...
                        labels, ...
                        'Method', 'RUSBoost', ... model
                        'NumLearningCycles', obj.modParams.nLearners, ... n weak learners
                        'Learners', treeLearner, ... type(s) of weak learners
                        'LearnRate', obj.modParams.LearnRate, ...
                        'ScoreTransform', obj.modParams.ScoreTransform, ...
                        'Prior', obj.prior, ...
                        'OptimizeHyperparameters', ....
                        {'NumLearningCycle', 'LearnRate'}, ...,  'MinLeafSize'} ...
                        'nprint', 100);
            end
        end
        
        [bandsLin2D, bandsLinAv, ...
    mB2D, mBAv, ...
    names2D, namesAv, ...
    namesmB2D, namesmBAv] = extractBandsLin(data, params)


    end
end

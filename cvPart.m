classdef cvPart
    properties
        params % Original paramters
        fileList % List of seizure files
        subSegList % List of subdivided segements
        nPick % Rows picked of each class, limited by available data props
        smClass % Size of the limiting class
        evalProp = 0.2 % Prop to hold back for validation
        overSample = 0 % Prop to over sample biggest class
        k = 5 % Number of folds
        posRows % Row numbers used in fold for class==1
        negRows % Row numbers used in fold for class==0
        segsPos % Unique segemns from these rows
        segsNeg
        nSegsPos % Number of unique segments available in total
        nSegsNeg
        idxPos % Full idx to get data from subSegList
        idxNeg
        seed = [] % Random seed 
    end
    
    methods
        function obj = cvPart(fileList, subSegList, params)
            
            % Set defualt params if not supplied
            % There was a bug here, param seed wasn't being set
            % For now, using seed 111111 for all cvParts
            % Means different data on each fold, but with same number of
            % folds different models will get the same data
            if isfield(params, 'seed')
                % Exchange these lines to make seed settable
                % obj.seed = params.seed;
                obj.seed = 111111;
            else % No seed specified
                obj.seed = rng('shuffle');
            end
            % Set seed
            rng(obj.seed);
            rng(obj.seed);
            obj.seed = rng;
            
            if isfield(params, 'evalProp') 
                obj.evalProp = params.evalProp;
            end
            if isfield(params, 'k'); obj.k = params.k; end
            if isfield(params, 'overSample')
                obj.overSample = params.overSample;
            end
            
            obj.params = params;
            
            % Set initial values
            obj.fileList = fileList;
            obj.subSegList = subSegList;
            obj.k = params.k;
            obj.evalProp = params.evalProp;
            
            % Preallocate
            obj = blank(obj);
            % Get indexes
            obj = getIdx(obj);
        end
        
        function obj = blank(obj)
            % Find unique segments for each class
            unqSegsNeg = ...
                unique(obj.subSegList.SegID(obj.subSegList.Class==0));
            unqSegsPos = ...
                unique(obj.subSegList.SegID(obj.subSegList.Class==1));
            obj.nSegsNeg = numel(unqSegsNeg);
            obj.nSegsPos = numel(unqSegsPos);
            
            % Get height of subSegList, will be used a few times
            % idx to get data will always be this long
            hSSL = height(obj.subSegList);
            
            % How many segements can be selected?
            obj.smClass = min(obj.nSegsNeg, obj.nSegsPos);
            
            nSm = obj.smClass*(1-obj.evalProp);
            if ~obj.overSample
                % Limit by smallest class and use same for both
                obj.nPick = [nSm, ...% Pos,
                    nSm]; % Neg
            else
                % Sample larger class by overSample proportion
                % Eg. neg class larger
                % nPick(1) = nPick + nPick*1*oProp
                obj.nPick = [...
                    nSm + nSm*(obj.nSegsNeg<obj.nSegsPos)...
                    *obj.overSample, ...% Pos,
                    nSm + nSm*(obj.nSegsPos<obj.nSegsNeg)...
                    *obj.overSample]; % Neg
            end
            obj.nPick = round(obj.nPick);
            
            % Limit nPick to nSegs available
            nLims = [obj.nSegsPos, obj.nSegsNeg];
            if any(obj.nPick>nLims)
                disp('Warning: Sampling all data from at least one class!')
                obj.nPick(obj.nPick>nLims) = nLims(obj.nPick>nLims);
            end

            % Prepare cvPart
            obj.posRows = NaN(obj.nPick(1), obj.k);
            obj.negRows = NaN(obj.nPick(2), obj.k);
            obj.segsPos = cell(1, obj.k);
            obj.segsNeg = cell(1, obj.k);
            obj.idxPos = NaN(hSSL, obj.k);
            obj.idxNeg = NaN(hSSL, obj.k);
        end
        
        function obj = getIdx(obj)
            unqSegsNeg = ...
                unique(obj.subSegList.SegID(obj.subSegList.Class==0));
            unqSegsPos = ...
                unique(obj.subSegList.SegID(obj.subSegList.Class==1));
            
            % Pick nPick segments from each class, k times
            for ki = 1:obj.k
                
                % List of rows corresponding to unique IDs
                obj.posRows(:,ki) = randperm(obj.nSegsPos, obj.nPick(1));
                obj.negRows(:,ki) = randperm(obj.nSegsNeg, obj.nPick(2));
                
                % Segements in these rows
                obj.segsPos{1,ki} = unqSegsPos(obj.posRows(:,ki));
                obj.segsNeg{1,ki} = unqSegsNeg(obj.negRows(:,ki));
                
                % Idx to get all data from these segements from subSegList
                obj.idxPos(:,ki) = zeros(height(obj.subSegList), 1);
                obj.idxNeg(:,ki) = zeros(height(obj.subSegList), 1);
                % Get idx of each segment - is there a way to do this
                % without looping??
                for i = 1:obj.nPick(1)
                    obj.idxPos(:,ki) = ...
                        obj.idxPos(:,ki) + single(obj.subSegList.SegID ...
                        == obj.segsPos{1,ki}(i));
                end
                for i = 1:obj.nPick(2)
                obj.idxNeg(:,ki) = ...
                        obj.idxNeg(:,ki) + single(obj.subSegList.SegID ...
                        == obj.segsNeg{1,ki}(i));
                end
                obj.idxPos(:,ki) = logical(obj.idxPos(:,ki));
                obj.idxNeg(:,ki) = logical(obj.idxNeg(:,ki));
            end
        end
        
        function dataList = listData(obj, k, keepIdx)
            % Return list of rows from subSegList for fold k
            
            % dataList = [obj.subSegList(obj.idxNeg(:,k) & keepIdx, :); ...
            %    obj.subSegList(obj.idxPos(:,k) & keepIdx, :)];
            
            dataList = obj.subSegList(any([obj.idxNeg(:,k), ...
                obj.idxPos(:,k)],2) ...
                & keepIdx, :);
        end
        
        function data = getData(obj, k, feas, keepIdx)
            % Return rows to use for fold k for training, from features
            % table
            % These correspond to rows listed in listData(obj, k)
            % May need to modify if feas is table
            
            data = feas(any([obj.idxNeg(:,k), ...
                obj.idxPos(:,k)],2) ...
                & keepIdx, :);
        end
        
        % listEvalData and getEvalData work but need updating to similar
        % structure as getData and listData - OKLim not used anymore
        function dataList = listEvalData(obj, k, okLim)
            % Return list of rows from subSegList not in fold k
            
            if nargin<3
                % Assume return all data, ignoring OK check for segs
                okLim = 0;
            end
            
            if okLim
                % If on, use OK field
                % Might return slightly less data than expected
                keepIdx = obj.subSegList.OK==1;
            else
                % Else, use regardless of OK field
                keepIdx = true(height(obj.subSegList),1);
            end
            
            dataList = obj.subSegList(~any([obj.idxNeg(:,k), ...
                obj.idxPos(:,k)],2) ...
                & keepIdx, :);
        end
        
        function data = getEvalData(obj, k, feas, okLim)
            % Return rows not in fold k for evaluation, from features
            % table
            % These correspond to rows listed in listData(obj, k)
            % May need to modify if feas is table
            
            if nargin<4
                % Assume return all data, ignoring OK check for segs
                okLim = 0;
            end
            
            if okLim
                % If on, use OK field
                % Might return slightly less data than expected
                keepIdx = obj.subSegList.OK==1;
            else
                % Else, use regardless of OK field
                keepIdx = true(height(obj.subSegList),1);
            end
            
            data = feas(~any([obj.idxNeg(:,k), ...
                obj.idxPos(:,k)],2) ...
                & keepIdx, :);
        end
        
        function obj = reRoll(obj)
            % Rest and get new idx
            p = obj.params;
            p.seed = rng;
            
            obj = cvPart(obj.fileList, obj.subSegList, p);
        end
    end
end
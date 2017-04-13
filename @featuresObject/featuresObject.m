classdef featuresObject
    % Version 2: Individual object for train and test
    % Working from M50 - removing unneeded code
    % - Anything unique to first test/train sets
    % - Grads
    % Moving in external functions - compile features and get filelists
    
    properties
        tt = 'Test' % Train or Test
        type = string('Uncompiled');
        params
        gradsParams = []
        use
        useGrads % Now vector, see set.useGrads
        fileLists
        feaNames
        labels % Training labels
        keepIdx % New keepIdx (no NaN rows)
        applyNewSafeIdx = 1;
        dataSet
        subSegLists % Not used
        divS
        files % Cell: train, test x divS
        SSL % Cell: train, test
        hybrid = 0 % Add subject numbers to general model?
        path % Path to main data directory
    end
    
    methods
        function obj = featuresObject(params, use)
            
            if isfield(params, 'tt')
                obj.tt = params.tt;
            end
            
            if isfield(params, 'divS')
                obj.params = params;
                % Get list of divS to use
                % set method sorts
                obj.divS = params.divS;
            else
                obj.params = 'Auto';
                obj = obj.findDivS;
            end
            
            if isfield(params, 'applyNewSafeIdx')
                obj.applyNewSafeIdx = params.applyNewSafeIdx;
            end
            
            % Check hybrid mode
            if isfield(params, 'hybrid')
                obj.hybrid = params.hybrid;
            end
            
            % Set paths
            obj.path = params.paths;
            
            % Save file lists and use
            obj = setFileLists(obj, {});
            obj.use = use;
            
            
            % Run compile now?
            % obj = compileFeatures(obj);
        end
        
        function obj = set.divS(obj, divS)
            obj.divS = sort(divS, 'descend');
        end
        
        function obj = compileFeatures(obj)
            
            % Check the requested files are available
            obj.files = ...
                obj.checkFiles();
            
            % Load files
            nD = numel(obj.divS);
            for d = 1:nD
                fn = ['divS', num2str(obj.divS(d))];
                
                disp(['Loading ', fn])
                
                data = load(obj.files{1,d});
                
                allData.(fn).SSL = data.subSegList;
                
                % Compile this data
                % Moved external function to static
                [allData.(fn).dataSet, obj.feaNames] = ...
                    obj.comboFeatures(data.feas, ...
                    data.subSegList, obj.use);
            end
            clear data
            
            % Join available data
            if nD>1
                % Create new table
                nt = [];
                for d = 1:nD-1
                    
                    % Join next (d+1) to this (d)
                    d1 = ['divS', num2str(obj.divS(d))];
                    d2 = ['divS', num2str(obj.divS(d+1))];
                    disp(['Joining ', d2 ' to ', d1])
                    
                    % Create join keys
                    % Use pedantic key generation (from M41)
                    % First get list of unique files without using unique
                    % (it sorts)
                    disp('Keygen:')
                    fns = string(allData.(d1).SSL.Files);
                    toDel = zeros(numel(fns),1);
                    for f = 2:numel(fns)
                        % If this row is same as above row, mark to delete
                        toDel(f) = fns(f).contains(fns(f-1));
                    end
                    unqFiles = fns(~toDel);
                    % Now, for this list of files, generate keys
                    % This is slow
                    k1 = [];
                    k2 = [];
                    nFiles = numel(unqFiles);
                    for f = 1:nFiles
                        
                        k1Idx = ...
                            string(allData.(d1).SSL.Files)...
                            .contains(unqFiles(f));
                        nK1 = sum(k1Idx);
                        
                        k2Idx = ...
                            string(allData.(d2).SSL.Files)...
                            .contains(unqFiles(f));
                        nK2 = sum(k2Idx);
                        
                        nextIdx = length(k1)+1;
                        
                        k1Add = nextIdx : (nextIdx-1)+nK1;
                        k2Add = round(linspace(k1Add(1),k1Add(end), nK2));
                        
                        k1 = [k1; k1Add']; %#ok<AGROW> % Can't preallocate
                        k2 = [k2; k2Add']; %#ok<AGROW>
                        if ~mod(f,1000)
                            disp([num2str(f), '/' num2str(nFiles)])
                        end
                    end
                    
                    % Join
                    % Simplify syntax for now (add test/train loop?)
                    % Need to drop subSegID col, and append divs to col names
                    if d==1
                        jd1 = allData.(d1).dataSet(:,2:end);
                    else
                        jd1 = nt;
                    end
                    jd1.Properties.VariableNames = ...
                        cellstr(string(jd1.Properties.VariableNames) + d1);
                    jd1.jk = k1;
                    jd2 = allData.(d2).dataSet(:,2:end);
                    jd2.Properties.VariableNames = ...
                        cellstr(string(jd2.Properties.VariableNames) + d2);
                    jd2.jk = k2;
                    
                    nt = join(jd2, jd1);
                    % Remove key
                    nt.jk = [];
                    
                    clear jd1 jd2
                    
                end
            else % Just 1 divS, no joining
                % But remember to drop subSegID
                nt = ...
                    allData.(['divS', num2str(obj.divS)]).dataSet(:,2:end);
            end
            
            % Save to object
            obj.dataSet = nt;
            obj.feaNames = nt.Properties.VariableNames;
            
            % Labels should be last divS
            labs = allData.(['divS', num2str(obj.divS(end))]).SSL.Class;
            obj.labels = labs;
            
            % Also save final subSegList
            obj.SSL = allData.(['divS', num2str(obj.divS(end))]).SSL;
            
            % Set feature type
            obj = setType(obj);
            
            % Set safeIdx (if training)
            switch obj.tt
                case {'train', 'Train'}
                    obj = setSafeIdx(obj);
                case {'test', 'Test'}
                    % Set keepIdx
                    obj = setkeepIdx(obj);
            end
            
            % Add subject numbers to sets if hybrid
            if obj.hybrid
                obj = addSubs(obj);
            end
            
        end
        
        function obj = addSubs(obj)
            switch obj.dataSet.Properties.VariableNames{1}
                case 'Subject'
                    % Subject already added, do nothing
                otherwise
                    obj.dataSet = ...
                        [obj.SSL{1}(:, 'Subject'), obj.dataSet];
            end
        end
        
        function obj = setType(obj)
            % General/Single/Hybrid | NoGrads/Grads/PartialGrads
            % eg. Hybrid.PartialGrads
            % Model will inherit type
            
            if numel(unique(obj.SSL.Subject))>1 && obj.hybrid == 1
                s1 = 'Hybrid';
            else
                % Features will contain all 3 subs
                % Set model object to single later if needed
                obj.hybrid = 0;
                s1 = 'General';
            end
            
            if all(obj.useGrads)
                s2 = 'Grads';
            elseif any(obj.useGrads) && numel(obj.useGrads)>1
                s2 = 'PartialGrads';
            elseif ~all(obj.useGrads)
                s2 = 'NoGrads';
            end
            
            obj.type = string({s1, s2});
            
        end
        
        % Set file lists
        function obj = setFileLists(obj, fileLists)
            if isempty(fileLists)
                obj.fileLists = ...
                    getFileLists(obj);
            else
                obj.fileLists = fileLists;
            end
        end
        
        % Get file lists - static functions (were external)
        function [fileList, labels] = ...
                getFileLists(obj)
            % NB: Labels not being returned - readd for training
            
            switch obj.tt
                case {'train', 'Train'}
                    [fileList] = ...
                        obj.genFileListSomeSingles({'1','2','3'}, ...
                        obj.tt, obj.path);
                case {'test', 'Test'}
                    [fileList] = ...
                        obj.genFileListNoConcat({'1','2','3'}, ...
                        obj.tt, obj.path);
            end
        end
        
        % Not a set method
        function obj = setkeepIdx(obj)
            % Sets keepIdx
            
            % Set newKeepIdx
            keepIdx1 = obj.newKeepIdx(obj.dataSet);
            
            obj.keepIdx = keepIdx1;
        end
        
        % Load and apply safe idx from second release of data
        function obj = setSafeIdx(obj)
            if obj.applyNewSafeIdx
                
                % Load csv
                % Contains all training data and affected test data
                safe = readtable('train_and_test_data_labels_safe.csv');
                
                % Drop refernces to test data
                flStr = string(obj.fileLists.File);
                safeStr = string(safe.image);
                trIdx = safeStr.contains(flStr);
                safe = safe(trIdx, :);
                % Remove class column for safety
                safe.class = [];
                % Rename key variable
                safe.Properties.VariableNames{1} = 'File';
                
                % Readd the new files in the training set (with modified
                % names)
                % Files in fileList
                str = string(obj.fileLists.File);
                % But not in safeStr
                missingIdx = ~str.contains(safeStr);
                % Add thses to safe, along with safe tag
                nAdd = sum(missingIdx);
                add = table(cellstr(str(missingIdx)), ones(nAdd,1));
                add.Properties.VariableNames{1} = 'File';
                add.Properties.VariableNames{2} = 'safe';
                
                % NB: Union drops dupes, but there shouldn't be any
                safe = union(safe, add);
                
                % Join
                % To fileList
                nt = join(obj.fileLists, safe);
                
                % Order as fileList?
                % plot(nt.SubSegID); hold on; plot(obj.fileLists.SubSegID)
                if ~all(nt.SubSegID == obj.fileLists.SubSegID)
                    keyboard
                else
                    obj.fileLists = nt;
                end
                
                % Join
                % To biggest subSegList
                % (.File is called .Files here)
                safe.Properties.VariableNames{1} = 'Files';
                nSSL = join(obj.SSL, safe);
                
                % Order as fileList?
                % plot(nSSL.SubSegID); hold on; plot(obj.SSL.SubSegID)
                if ~all(nSSL.SubSegID == obj.SSL.SubSegID)
                    keyboard
                else
                    obj.SSL = nSSL;
                end
                
                % Set newKeepIdx
                keepIdx2 = nSSL.safe;
                
            else
                % Don't apply new safeIdx
                keepIdx2 = true(height(obj.SSL,1));
            end
            
            % Get oklist from training data and combine
            keepIdx1 = obj.newKeepIdx(obj.dataSet);
            
            obj.keepIdx = keepIdx1 & keepIdx2;
        end
        
        function divS = findDivS(obj)
            % Find available features files
            files = dir(['*', obj.tt, 'divS*_*.mat']); %#ok<*PROP>
            nFiles = numel(files);
            
            divS = NaN(1, nFiles);
            for f = 1:nFiles
                s = string(files(f).name);
                divS(f) = s.extractAfter('divS').extractBefore('_').double;
            end
        end
        
        function files = checkFiles(obj)
            nD = numel(obj.divS);
            files = cell(1, nD);
            
            
            for d = 1:nD
                % Check
                fn = [obj.tt, '_divS', num2str(obj.divS(d)), ...
                    '.mat'];
                fn = dir(fn);
                
                if exist(fn.name, 'file')
                    % Exists
                    files{1,d} = fn.name;
                else
                    % Run generation
                    files{1,d} = [obj.tt, '_divS', num2str(obj.divS(d)), ...
                        '.mat'];
                    
                    obj.params.divS = obj.divS(d);
                    obj.params.fn = files{1,d};
                    
                    [~, ~, ~] = ... Outputs unused here
                        obj.redivideSegmentsConcatSome(obj.fileLists, ...
                        obj.params, obj.tt);
                    
                end
            end
        end
    end
    
    methods (Static)
        function [allData, feaNames] = ...
                comboFeatures(feas, ...
                subSegList, use)
            % Compile data tables from feature structures
            
            fld = fieldnames(feas.data);
            allData = NaN(size(feas.data.(fld{1}),1), 0, 'single');
            feaNames = cell(1,0);
            
            fns = fieldnames(use);
            nF = numel(fns);
            for f = 1:nF
                if use.(fns{f})
                    
                    % Collect selected data
                    allData = [allData, feas.data.(fns{f})]; %#ok<AGROW>
                    
                    % Collect names
                    feaNames = [feaNames, feas.names.(fns{f})]; %#ok<AGROW>
                end
            end
            
            % Make sure feaNames doesn't contain spaces
            feaNames = strrep(feaNames, ' ', '_');
            % Add SubSegID to use as key later
            feaNames = ['SubSegID', feaNames];
            
            % Temp bodge to allow for non-multiples (M40)
            % There may be additional row of allTrain (rounding error?)
            aUse = 1:height(subSegList);
            
            allData = ...
                array2table(...
                [subSegList.SubSegID, double(allData(aUse,:))]);
            allData.Properties.VariableNames = cellstr(feaNames);
            
        end
        
        function keepIdx = newKeepIdx(data)
            % All data is prcessed
            % All zero windows will return NaNs for some features
            keepIdx = all(~isnan(data{:,:}),2);
        end
        
        function [fullFileList] = genFileListSomeSingles(subs, str, paths)
            warning('off', 'MATLAB:table:RowsAddedExistingVars')
            
            vars = {...
                NaN, 'Subject', 'Subject'; ...
                NaN, 'ID', ''; ...
                NaN, 'Class', ''; ...
                NaN, 'Segment', 'The 10 min segment this is from'; ...
                NaN, 'nInSegment', 'n within segment'; ...
                NaN, 'SegID', 'n within segment'; ...
                NaN, 'SubSegID', 'n within segment'; ...
                cell(1), 'Filename', ''; ...
                cell(1), 'File', ''; ...
                NaN, 'n', 'total n'; ...
                };
            
            fullFileList = table(vars{:,1});
            fullFileList.Properties.VariableNames = vars(:,2);
            fullFileList.Properties.VariableDescriptions = vars(:,3);
            
            nSubs = numel(subs);
            % Generate file list
            tn = 0;
            for s = 1:nSubs
                % Create sub table for this subject
                fileList = table(vars{:,1});
                fileList.Properties.VariableNames = vars(:,2);
                fileList.Properties.VariableDescriptions = vars(:,3);
                
                sDir = [paths.dataDir, str, '_', subs{s}, '\'];
                
                % files = dir([sDir, subs{s}, '*']);
                files = dir([sDir, '*.mat']);
                nFilesSub = length(files);
                r = 0;
                for n = 1:nFilesSub
                    tn=tn+1;
                    fn = [sDir, files(n).name];
                    disp(['Importing file: ', fn, '(', num2str(n), ...
                        '/', num2str(nFilesSub), ')']);
                    
                    switch str
                        case {'train', 'Train'}
                            Y = str2double(fn(end-4));
                            IDIdx = strfind(files(n).name, '_');
                            ID = files(n).name(IDIdx(1)+1:IDIdx(2)-1);
                            ID = str2double(ID);
                            % ID duplicated between 0 and 1s
                            % Add 6000 to 1 segement IDs
                            % (More than max of each subject, may still be duplicate IDs
                            % between subjects)
                            if Y==1
                                ID = ID+6000;
                            end
                            
                        otherwise % Test
                            Y = NaN;
                            IDIdx1 = strfind(files(n).name, '_');
                            IDIdx2 = strfind(files(n).name, '.');
                            ID = files(n).name(IDIdx1+1:IDIdx2-1);
                            ID = str2double(ID);
                    end
                    
                    r = r+1;
                    fileList.Subject(r,1) = s;
                    fileList.Filename{r,1} = fn;
                    fileList.File{r,1} = files(n).name;
                    fileList.Class(r,1) = Y;
                    fileList.ID(r,1) = ID;
                    % fileList.n(r,1) = tn;
                end
                
                % Subject has been added, sort by ID and label segements
                fileList = sortrows(fileList, 'ID', 'ascend');
                
                % In some files,
                % The are 6 files for each segment
                % In others, they are singles
                % Load list of singles for this subject
                singles = load(['singles', num2str(s), '.mat']);
                
                exSinglesIdx = ~string(fileList.File).contains(singles.safe4);
                nFilesSubEx = sum(exSinglesIdx);
                % Label the grouped data
                fileList.Segment(find(exSinglesIdx)) = ...
                    reshape(repmat((1:nFilesSubEx/6)', 1, 6)',nFilesSubEx,1); %#ok<FNDSB>
                fileList.nInSegment(find(exSinglesIdx)) = repmat((1:6)', ...
                    nFilesSubEx/6, 1); %#ok<FNDSB>
                
                % Now label the remaing as single segments
                fileList.Segment(find(~exSinglesIdx)) = ...
                    max(fileList.Segment)+1:...
                    (numel(singles.safe4)+ max(fileList.Segment)); %#ok<FNDSB>
                fileList.nInSegment(find(~exSinglesIdx)) = 1; %#ok<FNDSB>
                
                % Append to full table
                fullFileList = [fullFileList; fileList]; %#ok<AGROW>
                clear fileList
            end
            
            % Remove empty first row
            fullFileList(1,:) = [];
            fullFileList.n(:,1) = 1:tn;
            segID = cellstr([num2str(fullFileList.Subject), ...
                repmat('000', height(fullFileList),1), ...
                num2str(fullFileList.Segment)]);
            subSegID = cellstr([num2str(fullFileList.Subject), ...
                repmat('000', height(fullFileList),1), ...
                num2str(fullFileList.Segment), ...
                num2str(fullFileList.nInSegment)]);
            
            
            cellstr([segID{:}, ...
                ]);
            
            % FFS
            for s = 1:height(fullFileList)
                segID{s} = str2double(strrep(segID{s}, ' ', '0'));
                subSegID{s} = str2double(strrep(subSegID{s}, ' ', '0'));
            end
            fullFileList.SegID = cell2mat(segID);
            fullFileList.SubSegID = cell2mat(subSegID);
            % plot(fullFileListTrain.ID); hold on; plot(fullFileListTrain.Segment)
        end
        
        function [fullFileList] = genFileListNoConcat(subs, str, paths)
            warning('off', 'MATLAB:table:RowsAddedExistingVars')
            
            vars = {...
                NaN, 'Subject', 'Subject'; ...
                NaN, 'ID', ''; ...
                NaN, 'Class', ''; ...
                NaN, 'Segment', 'The 10 min segment this is from'; ...
                NaN, 'nInSegment', 'n within segment'; ...
                NaN, 'SegID', 'n within segment'; ...
                NaN, 'SubSegID', 'n within segment'; ...
                cell(1), 'Filename', ''; ...
                cell(1), 'File', ''; ...
                NaN, 'n', 'total n'; ...
                };
            
            fullFileList = table(vars{:,1});
            fullFileList.Properties.VariableNames = vars(:,2);
            fullFileList.Properties.VariableDescriptions = vars(:,3);
            
            nSubs = numel(subs);
            % Generate file list
            tn = 0;
            for s = 1:nSubs
                % Create sub table for this subject
                fileList = table(vars{:,1});
                fileList.Properties.VariableNames = vars(:,2);
                fileList.Properties.VariableDescriptions = vars(:,3);
                
                sDir = [paths.dataDir, str, '_', subs{s}, '_New\'];
                
                % files = dir([sDir, subs{s}, '*']);
                files = dir([sDir, '*.mat']);
                nFilesSub = length(files);
                r = 0;
                for n = 1:nFilesSub
                    tn=tn+1;
                    fn = [sDir, files(n).name];
                    disp(['Importing file: ', fn, ...
                        '(', num2str(n), '/', num2str(nFilesSub), ')']);
                    
                    switch str
                        case {'train', 'Train'}
                            Y = str2double(fn(end-4));
                            IDIdx = strfind(files(n).name, '_');
                            ID = files(n).name(IDIdx(1)+1:IDIdx(2)-1);
                            ID = str2double(ID);
                            % ID duplicated between 0 and 1s
                            % Add 6000 to 1
                            % segement IDs (More than max of each subject,
                            % may still be duplicate IDs between subjects)
                            if Y==1
                                ID = ID+6000;
                            end
                            
                        otherwise % Test
                            Y = NaN;
                            IDIdx1 = strfind(files(n).name, '_');
                            IDIdx2 = strfind(files(n).name, '.');
                            ID = files(n).name(IDIdx1+1:IDIdx2-1);
                            ID = str2double(ID);
                    end
                    
                    r = r+1;
                    fileList.Subject(r,1) = s;
                    fileList.Filename{r,1} = fn;
                    fileList.File{r,1} = files(n).name;
                    fileList.Class(r,1) = Y;
                    fileList.ID(r,1) = ID;
                    % fileList.n(r,1) = tn;
                end
                
                % Subject has been added, sort by ID and label segements
                fileList = sortrows(fileList, 'ID', 'ascend');
                % The are 6 files for each segment
                % fileList.Segment = reshape(repmat((1:nFilesSub/6)', 1, 6)',nFilesSub,1);
                % New for master 33: Each file is individual segment
                fileList.Segment = (1:height(fileList))';
                fileList.nInSegment = repmat(1, nFilesSub, 1);
                
                % Append to full table
                fullFileList = [fullFileList; fileList]; %#ok<AGROW>
                clear fileList
            end
            
            % Remove empty first row
            fullFileList(1,:) = [];
            fullFileList.n(:,1) = 1:tn;
            segID = cellstr([num2str(fullFileList.Subject), ...
                repmat('000', height(fullFileList),1), ...
                num2str(fullFileList.Segment)]);
            subSegID = cellstr([num2str(fullFileList.Subject), ...
                repmat('000', height(fullFileList),1), ...
                num2str(fullFileList.Segment), ...
                num2str(fullFileList.nInSegment)]);
            
            
            cellstr([segID{:}, ...
                ]);
            
            % FFS
            for s = 1:height(fullFileList)
                segID{s} = str2double(strrep(segID{s}, ' ', '0'));
                subSegID{s} = str2double(strrep(subSegID{s}, ' ', '0'));
            end
            fullFileList.SegID = cell2mat(segID);
            fullFileList.SubSegID = cell2mat(subSegID);
            % plot(fullFileListTrain.ID); hold on; plot(fullFileListTrain.Segment)
        end
        
        function [subSegList, fileList, feas] = ...
                redivideSegmentsConcatSome(fileList, params, str)
            % Divide and OK check
            warning('off', 'MATLAB:table:RowsAddedExistingVars')
            
            % Unpack params
            divS = params.divS;
            OKThresh = 0.5;
            params.plotOn = 0;
            
            % First check it's necessary to run
            fn = params.fn;
            vars = {'feas', 'subSegList'};
            if exist(fn, 'file') && ~params.force
                disp('Reloading')
                load(fn, vars{:});
            else
                
                % Prepare table
                vars2 = {...
                    NaN, 'Subject', 'Subject'; ...
                    NaN, 'ID', ''; ...
                    NaN, 'Class', ''; ...
                    NaN, 'Segment', 'The 10 min segment this is from'; ...
                    NaN, 'nInSegment', 'n within segment'; ...
                    NaN, 'SegID', 'n within segment'; ...
                    NaN, 'SubSegID', 'n within segment'; ...
                    cell(1), 'Filenames', ''; ...
                    cell(1), 'Files', ''; ...
                    NaN, 'n', 'total n'; ...
                    NaN, 'SubN', 'n in whole segment'; ...
                    NaN, 'Of', 'total epochs in 6-file concatonated segment. Should always be the same!'; ...
                    NaN, 'Lengh', 'Length of subSeg in S'; ...
                    NaN, 'Prop0', 'Proportion of zeros'; ...
                    true, 'OK', 'Passed OK Check?'; ...
                    };
                
                subSegList = table(vars2{:,1});
                subSegList.Properties.VariableNames = vars2(:,2);
                subSegList.Properties.VariableDescriptions = vars2(:,3);
                
                % Set lengths
                % unqSub = unique(fileList.Subject);
                % nSub = numel(unqSub);
                unqSeg = unique(fileList.SegID);
                nSeg = numel(unqSeg);
                % unqSubSeg = unique(fileList.SubSegID);
                % nSubSeg = numel(unqSubSeg);
                
                % Known parameters - fixed, not discovered or varied.
                fs = 400;
                dl = 240000;
                nChans = 16;
                % nInSeg = 1; % Master33: Now dynamic
                
                % Consistent paraemters
                divPts = divS*fs;
                % nDivs = floor((dl*nInSeg)/divPts);
                % cut = dl*nInSeg - nDivs*divPts;
                % Changed master33
                %     if nDivs>6
                %         from = reshape(repmat(1:6, nDivs/6, 1), nDivs, 1);
                %     else
                %         from = (1:6)';
                %     end
                % from = ones(nDivs,1)
                
                % totalToDo = height(fileList);
                
                % Features processed here
                % tRows = height(fileList)/nInSeg*nDivs;
                % tRows = height(fileList)*ceil((10*60)/divS);
                
                % Count singles and blocks of 6 here
                % Concatonate .Subject and .ID as chars
                ac = string([num2str(fileList.Subject), num2str(fileList.Segment)]);
                % Convert to string and .replace any spaces, return as doubles
                ac = ac.replace(' ' ,'').double();
                % Use this as accarray index on ones
                counts = accumarray(ac, ones(height(fileList),1));
                
                n1s = sum(counts == 1);
                n6s = sum(counts == 6);
                
                row1s = n1s*ceil((10*60*1)/divS);
                row6s = n6s*ceil((10*60*6)/divS);
                
                tRows = row1s + row6s;
                
                feas.data.hillsBandsLogAv = NaN(tRows, ...
                    numel(params.HillsBands.Range), 'single');
                feas.data.hillsBandsLog2D = NaN(tRows, ...
                    numel(params.HillsBands.Range)*16, 'single');
                feas.data.maxHills2D = NaN(tRows, ...
                    16, 'single');
                feas.data.maxHillsAv = NaN(tRows, ...
                    1, 'single');
                feas.data.summ32D = NaN(tRows, ...
                    8*nChans, 'single');
                feas.data.summ3Av = NaN(tRows, ...
                    8, 'single');
                feas.data.bandsLin2D = NaN(tRows, ...
                    11*16, 'single');
                feas.data.bandsLinAv = NaN(tRows, ...
                    11, 'single');
                feas.data.maxBands2D = NaN(tRows, ...
                    16, 'single');
                feas.data.maxBandsAv = NaN(tRows, ...
                    1, 'single');
                feas.data.mCorrsT = NaN(tRows, ...
                    4*16, 'single');
                feas.data.mCorrsF = NaN(tRows, ...
                    3*16, 'single');
                
                sslRow = 0;
                finalFeaRow = 0;
                % for s = 1:nSeg % For each unique segment
                for s = 1:nSeg % For each file individually
                    % Get ID
                    sn = unqSeg(s);
                    
                    % Get index of files
                    segIdx = fileList.SegID == sn;
                    
                    % Get subFileList structure just for this segment
                    % Might be one file, might be 6
                    subFileList = fileList(segIdx,:);
                    
                    % Moved here to make dynamic
                    nInSeg = height(subFileList);
                    nDivs = floor((dl*nInSeg)/divPts);
                    cut = dl*nInSeg - nDivs*divPts;
                    
                    
                    if cut>0
                        % If cut is >0 there are unused values at end
                        % Add one more window achnored to end to fill these values
                        fillWindow = true;
                        
                        % Also add 1 to nDivs, but not yet
                    else
                        fillWindow = false;
                    end
                    
                    from = round(linspace(1,height(subFileList),nDivs))'; % Estimated for non-multiples of length
                    % Previous - didn't work witn non-multiples eg divS = 400
                    % from = reshape(repmat(subFileList.nInSegment', ...
                    %    nDivs/nInSeg, 1), nDivs, 1);
                    
                    % Load and concatonate the data in the segement
                    % If there's more than one file
                    data1 = NaN(dl*nInSeg, nChans, 'single');
                    files = subFileList.File';
                    filenames = subFileList.Filename';
                    nFiles = numel(files);
                    sIdx = 1;
                    eIdx = 240000;
                    for ss = 1:nFiles
                        a = load(filenames{ss});
                        if nInSeg==1
                            disp(['Not-Concatonating ', filenames{ss}])
                        else
                            disp(['Concatonating ', filenames{ss}])
                        end
                        data1(sIdx:eIdx,:) = a.dataStruct.data;
                        
                        sIdx = sIdx + 240000;
                        eIdx = eIdx + 240000;
                    end
                    clear a
                    
                    % Do preprocessing here
                    
                    % Epoch
                    % Cut off any less than full bins, from start
                    % data = data(1+cut:end,:);
                    % Can increase data here by using sliding window instead
                    
                    % Epoch - M40
                    % Now cutting end off, and if any is cut, adding this to process as
                    % start cut off (below)
                    data = data1(1:end-cut,:);
                    
                    
                    % Idiot check
                    % dataEp = reshape(data', 16, divPts, nDivs);
                    % dataEp = permute(dataEp, [2, 1, 3]);
                    % figure
                    % subplot(2,1,1), plot(data(1:4000, 1:6))
                    % subplot(2,1,2), plot(dataEp(:, 1:6, 1))
                    % figure
                    % subplot(2,1,1), plot(data(4001:8000, 1:6))
                    % subplot(2,1,2), plot(dataEp(:, 1:6, 2))
                    data = reshape(data', 16, divPts, nDivs);
                    data = permute(data, [2, 1, 3]);
                    
                    if fillWindow
                        % Add the end cut off window to data
                        % fw = data1(1+cut:end,:);
                        fw = data1(end-(divPts-1):end,:);
                        fw = reshape(fw', 16, divPts, 1);
                        fw = permute(fw, [2, 1, 3]);
                        
                        % Set new nDivs here and add window to process to 3rd dim of
                        % data
                        nDivs = nDivs+1;
                        data(:,:,nDivs) = fw;
                        % Also remake from
                        from = round(linspace(1,height(subFileList),nDivs))';
                    end
                    
                    
                    % For each of the new epochs, do OK check and add to table
                    nInSegment = 0;
                    for n = 1:nDivs
                        sslRow = sslRow + 1;
                        nInSegment = nInSegment+1;
                        % Get the index (of the 6 rows from fileList) that this data came
                        % from
                        frIdx = from(n);
                        
                        % Copy in columns from subFilefileList
                        nc = width(subFileList);
                        for c = 1:nc
                            subSegList(sslRow, c) = subFileList(frIdx, c);
                        end
                        
                        % OK Check
                        prop0 = sum(sum(data(:,:,n)==0)) / (divPts*nChans);
                        chk = prop0 < OKThresh;
                        
                        % Add additional information
                        subSegList.SubN(sslRow,1) = n;
                        subSegList.Of(sslRow,1) = nDivs;
                        subSegList.Length(sslRow,1) = divS;
                        subSegList.Prop0(sslRow,1) = prop0;
                        subSegList.OK(sslRow,1) = chk;
                        subSegList.nInSegment(sslRow,1) = nInSegment;
                        
                    end
                    
                    disp('Computing Hills bands feature')
                    feaRow = finalFeaRow;
                    for n = 1:nDivs
                        feaRow = feaRow+1;
                        [feas.data.hillsBandsLog2D(feaRow, :), ...
                            feas.data.hillsBandsLogAv(feaRow, :), ...
                            feas.data.maxHills2D(feaRow, :), ...
                            feas.data.maxHillsAv(feaRow, :), ...
                            feas.names.hillsBandsLog2D, ...
                            feas.names.hillsBandsLogAv, ...
                            feas.names.maxHills2D, ...
                            feas.names.maxHillsAv] = ...
                            featuresObject.extractHillBands(data(:,:,n), ...
                            params);
                    end
                    
                    disp('Computing summary stats features')
                    feaRow = finalFeaRow;
                    for n = 1:nDivs
                        feaRow = feaRow+1;
                        [feas.data.summ32D(feaRow, :), ...
                            feas.data.summ3Av(feaRow, :), ...
                            feas.names.summ32D, ...
                            feas.names.summ3Av] = ...
                            featuresObject.extractSumm3(data(:,:,n), ...
                            params);
                    end
                    
                    disp('Computing bandsLin feature')
                    feaRow = finalFeaRow;
                    for n = 1:nDivs
                        feaRow = feaRow+1;
                        [feas.data.bandsLin2D(feaRow, :), ...
                            feas.data.bandsLinAv(feaRow, :), ...
                            feas.data.maxBands2D(feaRow, :), ...
                            feas.data.maxBandsAv(feaRow, :), ...
                            feas.names.bandsLin2D, ...
                            feas.names.bandsLinAv, ...
                            feas.names.maxBands2D, ...
                            feas.names.maxBandsAv] = ...
                            featuresObject.extractBandsLin(data(:,:,n), ...
                            params);
                    end
                    
                    disp('Computing channel correlations T feature')
                    feaRow = finalFeaRow;
                    for n = 1:nDivs
                        feaRow = feaRow+1;
                        [feas.data.mCorrsT(feaRow, :), ...
                            feas.names.mCorrsT] = ...
                            featuresObject.extractChannelCorrelationT(data(:,:,n), ...
                            params);
                    end
                    
                    disp('Computing channel correlations F feature')
                    feaRow = finalFeaRow;
                    for n = 1:nDivs
                        feaRow = feaRow+1;
                        [feas.data.mCorrsF(feaRow, :), ...
                            feas.names.mCorrsF] = ...
                            featuresObject.extractChannelCorrelationF(data(:,:,n), ...
                            params);
                    end
                    
                    finalFeaRow = feaRow;
                    
                    disp([str, ' Done: ', num2str(s), '/', num2str(nSeg), ...
                        '(', num2str(s/nSeg*100), '%)'])
                    
                end
                
                
                % Reapply subSegID
                subSegList.SubSegID = ...
                    str2double(strrep(cellstr([num2str(subSegList.SegID), ...
                    num2str(subSegList.nInSegment)]), ' ', '0'));
                
                save(fn, vars{:}, '-v7.3')
            end
        end
        
        [bandsLin2D, bandsLinAv, ...
            mB2D, mBAv, ...
            names2D, namesAv, ...
            namesmB2D, namesmBAv] = extractBandsLin(data, params)
        
        [mCorrsF2D, names2D] = ...
            extractChannelCorrelationF(data, params)
        
        [mCorrsT2D, names2D] = ...
            extractChannelCorrelationT(data, params)
        
        [HBLog2D, HBLogAv, ...
            mB2D, mBAv, ...
            names2D, namesAv, ...
            namesmB2D, namesmBAv] = ...
            extractHillBands(data, params)
        
        [summ32D, summ3Av, names32D, names3Av] = extractSumm3(data, params)
        
    end
end

function copyTestLeakToTrain(paths)
% Create new training set
% Move old, leaked test data to new training set

% Load list of safe files
safe = readtable('train_and_test_data_labels_safe.csv');

% Convert to string
safe1 = string(safe{:,1});
% Drop training files in list
safe1 = safe1(6043:end,1);

% Generate new files names (all are class 1)
safe2 = safe1.insertBefore('.mat', '_1');

% Copy from original train/test on desktop to training folders
for s = 1:3
    dTrain = [paths.new, 'train_', num2str(s), '\'];
    
    % First copy original training set in to new training set
    dOldTrain = [paths.or, 'train_', num2str(s), '\']; 
    
    disp(['Copying original training set, subject: ', num2str(s)]); 
    copyfile(dOldTrain, dTrain)
    
    % Then merge in files from original test set
    dOldTest = [paths.or, 'test_', num2str(s), '\'];
    
    % Get subset of new names
    s2ss = safe1(safe1.startsWith([num2str(s), '_']));
    safe3 = safe2(safe2.startsWith([num2str(s), '_']));
    
    % Get names of current train files
    names = dir([dTrain, '*.mat']);
    nn = numel(names);
    % Sigh
    nCell = cell(1,nn);
    for n = 1:nn
        nCell{n} = names(n).name;
    end
    % Rejoin 21st century
    names = string(nCell);
    nums = double(names.extractBetween('_', '_'));
    nums = sort(nums, 'Ascend');
    nSubTrain = nums(end);
    
    % Change safe3 names to > nSubTain+1
    % Try just adding nSubTrain first
    % nSubUse = nSubTrain;
    % Or, just use a set number?
    nSubUse = 4000;
    newNums = double(safe3.extractBetween('_', '_'))+nSubUse;
    % Replace in these new numbers
    safe4 = string;
    for n = 1:numel(safe3)
        safe4(n,1) = ...
            safe3(n).replace(safe3(n).extractBetween('_', '_'), ...
            string(newNums(n)));
    end
    % NB: Looping because this line bugs
    % safe4 = safe3.replace(safe3.extractBetween('_', '_'), string(newNums));
    
    disp(['Subject ', num2str(s), ', current: ', num2str(nSubTrain), ...
        ', using: ', num2str(nSubUse)])
    
    % Now ready to copy?
    nFiles = numel(safe4);
    for n = 1:nFiles
        cFrom = [dOldTest, s2ss(n)];
        cTo =  [dTrain, safe4(n)];
        
        copyfile(char(cFrom.join('')), char(cTo.join('')))
        disp([char(cFrom.join('')), ' to ', char(cTo.join(''))])
    end
    
    save(['Singles', num2str(s), '.mat'], 'safe4')
    
end

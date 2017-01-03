function compareModels(SVMs, SVMg, RBTs, RBTg, params)

nSubs = numel(SVMs);

% Calculate weighted mean of individual model AUCs
st = NaN(2,nSubs,2);
for s = 1:nSubs
    switch SVMs{s}.cvType
        case 'MATLAB'
            st(:,s,1) = [SVMs{s}.AUCScore; SVMs{s}.cv.NumObservations];
        case 'Custom'
            st(:,s,1) = [SVMs{s}.AUCScore; height(SVMs{s}.trainedData{1})];
    end
    
    switch RBTs{s}.cvType
        case 'MATLAB'
            st(:,s,2) = [RBTs{s}.AUCScore; RBTs{s}.cv.NumObservations];
        case 'Custom'
            st(:,s,2) = [RBTs{s}.AUCScore; height(RBTs{s}.trainedData{1})];
    end
    
end

mAUC = sum(st(1,:,:).*st(2,:,:),2) ./ sum(st(2,:,:));

% disp(params)
disp(['SVM: Mean individual AUC: ', num2str(mAUC(1,1,1)), ...
    ' vs general model AUC: ', num2str(SVMg.AUCScore)])
disp(['RBT: Mean individual AUC: ', num2str(mAUC(1,1,2)), ...
    ' vs general model AUC: ', num2str(RBTg.AUCScore)])

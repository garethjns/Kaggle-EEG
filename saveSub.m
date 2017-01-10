function saveSub(str, fileListTest, preds, params)

fn = ['Master', num2str(params.master), str, '.csv'];

if params.plotOn
    figure
    histogram(preds)
    title(fn)
end

fileListTest.Class(:,1) = preds;
tmp = [fileListTest(:,'File'), fileListTest(:,'Class')];
disp(['Saving: ', fn])
writetable(tmp, fn)
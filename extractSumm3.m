function [summ32D, summ3Av, names32D, names3Av] = extractSumm3(data, params)

nChans = size(data,2);

nFs = 8;
summ32D = NaN(nFs,nChans);

summ32D(1,:) = mean(abs(data));
summ32D(2,:) = mean(data);
summ32D(3,:) = std(data);
summ32D(4,:) = rms(data);

summ32D(5,:) = rms(diff(data));
summ32D(6,:) = rms(diff(diff(data)));

summ32D(7,:) = kurtosis(data);
summ32D(8,:) = skewness(data);

summ3Av = mean(summ32D,2)';
summ32D = reshape(summ32D, 1, nChans*8);

names3Av = cellstr([repmat('summ3Av_', nFs, 1), ...
    num2str((1:nFs)')])';

names32D = cellstr([repmat('summ3Av_', nFs*16, 1), ...
    repmat(num2str((1:nFs)'), 16,1), ...
    repmat('_c', nFs*16,1), ...
    num2str(reshape(repmat((1:16),nFs,1),nFs*16,1))])';
names32D = strrep(names32D, ' ', '');
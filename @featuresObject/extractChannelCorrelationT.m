function [mCorrsT2D, names2D] = ...
    extractChannelCorrelationT(data, params)

nChans = 16;

corrs = corr(data);
mCorrsT2D(1,:) = mean(corrs);
mCorrsT2D(2,:) = std(corrs);
mCorrsT2D(3,:) = sum(corrs);
mCorrsT2D(4,:) = sum(abs(corrs));

mCorrsT2D = reshape(mCorrsT2D, 1, nChans*4);

names2D = cellstr([repmat('mCorrsT_s', nChans*4,1), ...
    num2str(reshape(repmat((1:4), nChans , 1)', nChans*4, 1)), ...
    repmat('_c', nChans*4,1), ...
    num2str(reshape(repmat((1:nChans), 4, 1), nChans*4,1))])';

names2D = strrep(names2D, ' ', '' );
function [mCorrsF2D, names2D] = ...
    extractChannelCorrelationF(data, params)


nChans = 16;

% FFT first
fftData = NaN(size(data,1)/2+1, nChans, 'single');
for c = 1:nChans
    Fs = 400;
    T = 1/Fs;
    L = size(data,1); % dataStruct.nSamplesSegment / dataStruct.iEEGsamplingRate;
    t = (0:L-1)*T;
    
    Y = fft(data(:,c));
    
    P2 = abs(Y/L);
    P1 = P2(1:L/2+1);
    P1(2:end-1) = 2*P1(2:end-1);
    
    f = Fs*(0:(L/2))/L;
    
    fftData(:,c) = P1;
end

if params.plotOn
    plot(f,fftData)
    title('Single-Sided Amplitude Spectrum of X(t)')
    xlabel('f (Hz)')
    ylabel('|P1(f)|')
end

corrs = corr(fftData);
nStats = 3;
mCorrsF2D(1,:) = mean(corrs);
mCorrsF2D(2,:) = std(corrs);
mCorrsF2D(3,:) = sum(corrs);

mCorrsF2D = reshape(mCorrsF2D, 1, nChans*nStats);

names2D = cellstr([repmat('mCorrsF_s', nChans*nStats,1), ...
    num2str(reshape(repmat((1:nStats), nChans , 1)', nChans*nStats, 1)), ...
    repmat('_c', nChans*nStats,1), ...
    num2str(reshape(repmat((1:nChans), nStats, 1), nChans*nStats,1))])';

names2D = strrep(names2D, ' ', '' );
function [bandsLin2D, bandsLinAv, ...
    mB2D, mBAv, ...
    names2D, namesAv, ...
    namesmB2D, namesmBAv] = extractBandsLin(data, params)
% Do FFT over whole segement and return average bin power
% Later maybe add time divisions

% Delta: 1-3Hz
% Theta: 4-7Hz
% Alpha1: 8-9Hz
% Alpha2: 10-12Hz
% Beta1: 13-17Hz
% Beta2: 18-30Hz
% Gamma1: 31-40Hz
% Gamma2: 41-50Hz
% Higher: 51->200 Hz
bLims = [[1;3], [4;7], [8;9], [10;12], [13;17], [18;30], [31;40], ...
    [41;50], [51;70], [71;150], [151;250]]; % Last 3 mod M37
nBands = size(bLims,2);
nChans = 16;

bands2D = NaN(nBands, 16, 'single');

mB2D =  NaN(1, 16, 'single');

for c = 1:nChans

    Fs = 400;
    T = 1/Fs;
    L = size(data,1);
    
    Y = fft(data(:,c));
    
    P2 = abs(Y/L);
    P1 = P2(1:L/2+1);
    P1(2:end-1) = 2*P1(2:end-1);
    
    f = Fs*(0:(L/2))/L;
    
    if params.plotOn
        plot(f,P1)
        title('Single-Sided Amplitude Spectrum of X(t)')
        xlabel('f (Hz)')
        ylabel('|P1(f)|')
    end
    
    for b = 1:nBands
        bIdx = f>=bLims(1,b) & f<=bLims(2,b);
        
        mPower = mean(P1(bIdx));
        
        bands2D(b, c) = mPower;
    end
    
    [~, mB2D(1,c)] = max(bands2D(:,c));
end

% Max bands
mBAv = single(mean(mB2D));
namesmB2D = (string('maxBand_c') + (1:16)')';
namesmBAv = 'maxBandAv';

% Bands lin
bandsLinAv = mean(bands2D,2)';
bandsLin2D = reshape(bands2D, 1, nChans*nBands);

names2D = cellstr([repmat('bandsLin2D_b', nChans*nBands,1), ...
    num2str(repmat((1:nBands)', nChans, 1)), ...
    repmat('_c', nChans*nBands, 1), ...
    num2str(reshape(repmat((1:16), nBands, 1), nBands*nChans,1))]);
names2D = strrep(names2D, ' ' , '')';

namesAv = cellstr([repmat('bandsLinAv_b', nBands,1), ...
    num2str((1:nBands)')])';



function [HBLog2D, HBLogAv, ...
    mB2D, mBAv, ...
    names2D, namesAv, ...
    namesmB2D, namesmBAv] = ...
    extractHillBands(data, params)

nChans = size(data,2);
nBands = numel(params.HillsBands.Range);

HBLog = NaN(nBands, nChans);
for c = 1:nChans
    % T = 1/Fs;
    L = size(data,1);
    % t = (0:L-1)*T;
    
    Y = fft(data(:,c));
    
    P2 = abs(Y/L);
    P1 = P2(1:L/2+1);
    P1(2:end-1) = 2*P1(2:end-1);
    
    f = params.Fs*(0:(L/2))/L;
    
    if params.plotOn
        plot(f,P1)
        title('Single-Sided Amplitude Spectrum of X(t)')
        xlabel('f (Hz)')
        ylabel('|P1(f)|')
    end
    
    for h = 1:nBands
        hz = params.HillsBands.Range(h);
        
        HBLog(h,c) = mean(P2(round(f) == hz));
        
    end
end

% Log10
HBLog2D = log10(HBLog);
% Remove infs
HBLog2D(isinf(HBLog2D)) = 0;
% Mean across channels
HBLogAv = mean(HBLog2D,2)';

[~, mIdx] = max(HBLog2D);
mB2D = single(mIdx);
mBAv = mean(mB2D);

namesmB2D = (string('maxHills_c') + (1:16)')';
namesmBAv = 'maxHillsAv';


nFs = 47;
HBLog2D = reshape(HBLog2D, 1, nChans*nFs);

names2D = cellstr([repmat('hillBands2D_', nFs*16, 1), ...
    repmat(num2str((1:nFs)'), 16,1), ...
    repmat('_c', nFs*16,1), ...
    num2str(reshape(repmat((1:16),nFs,1),nFs*16,1))])';
names2D = strrep(names2D, ' ', '');

namesAv = cellstr([repmat('hillsBandAv_',47,1), num2str((1:47)')])';
namesAv = strrep(namesAv, ' ', '');
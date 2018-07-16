
clear all;

% datapath
dataroot = '/media/carsen/DATA2/grive/10krecordings/imgResp/';        
matroot = '/media/carsen/DATA2/grive/10krecordings/stimResults/';        

load(fullfile(dataroot,'dbstims.mat'));

useGPU = 1;
stimset={'natimg2800','white2800','natimg2800_8D','natimg2800_4D','natimg2800_small','ori','natimg32'};
%%

nPCspont = [0 1 4 16 64 256 1024];

K = 1;
clf;
%%
tic;
iexp = find(stype==K);
for k = 1:length(iexp)
    
    fname = fullfile(dataroot, sprintf('%s_%s_%s.mat', stimset{K},...
        dbstims(iexp(k)).mouse_name, dbstims(iexp(k)).date));
    
    %%
    load(fname);
    
    
    resp0   = stim.resp(stim.istim<max(stim.istim), :);
    resp0(isnan(resp0)) = 0;
    
    % rescale by spont firing
    istim   = stim.istim(stim.istim<max(stim.istim));
    mu      = mean(stim.spont,1);
    sd      = std(stim.spont,1,1)+ 1e-6;
    resp0   = (resp0 - mu)./sd;

    Fs0 = stim.spont;
    Fs0 = (Fs0 - mu)./sd;
	if useGPU
		[~, ~, Vspont] = svdecon(gpuArray(single(Fs0)));
	else
		[~, ~, Vspont] = svdecon(single(Fs0));
	end
       
    clf;
    for ip = 1:length(nPCspont(nPCspont<=size(Vspont,2)))
		nPCs = nPCspont(ip);

		keepNAN = 0;
        if nPCs > 0
            Vspont1 = gather(Vspont(:, 1:nPCs));
            respB = resp0 - (resp0 * Vspont1) * Vspont1';
        else
            respB = resp0;
        end
        respB = respB - mean(respB,1);
        respB = compute_means(istim, respB, 2, 0);
        iNotNaN = ~isnan(sum(respB(:,:),2));
        respB = respB(iNotNaN, :, :);

        nshuff = 10;
        ss0 = shuffledSpectrum(respB, nshuff, useGPU);
        ss  = gather_try(nanmean(ss0,2));
        ss  = ss(:) / sum(ss);
        
		specPC{k}{ip} = ss;
        
        loglog(ss);
        hold all;
        drawnow;
        toc;
		
        % SNR
		vnoise = var(respB(:,:,1) - respB(:,:,2), 1, 1) / 2;
		v1     = var(respB(:,:,1), 1, 1);
		v2     = var(respB(:,:,2), 1, 1);    
		snr{k}{ip} = (v1 + v2 - 2*vnoise) ./ (2*vnoise);
		
    end
    
end

%%
save(fullfile(matroot, 'specSpontPC.mat'),'specPC','nPCspont','snr');
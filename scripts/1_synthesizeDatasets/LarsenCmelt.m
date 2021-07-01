%% Script to extract Larsen C basal melt rates along several transects 
% from hdf5 files created by Adusumilli et al. (2020), 
% available through the library digital collections:
% https://library.ucsd.edu/dc/object/bb0448974g 
% and with supplemental processing code available as a GitHub repository: 
% https://github.com/sioglaciology/ice_shelf_change

clear all; close all;

save_figure = 1; % = 1 to save resulting figure
save_mr = 1; % = 1 to save resulting melt rates

homepath = '/Users/raineyaberle/Desktop/Research/CraneModeling/';
addpath([homepath,'CraneGlacier_flowlinemodeling/matlabFunctions/cmocean_v2.0/cmocean/']);
addpath('/Users/raineyaberle/Desktop/Research/matlabFunctions');
cd([homepath,'ice_shelf_change/']);

% load grid, basal melt rate (w_b), interpolated basal melt rate
% (w_b_interp), and basal melt rate uncertainty (w_b_uncert)
cd('ANT/');
x = h5read('ANT_iceshelf_melt_rates_CS2_2010-2018_v0.h5','/x'); % [m]
y = h5read('ANT_iceshelf_melt_rates_CS2_2010-2018_v0.h5','/y'); % [m]
w_b = h5read('ANT_iceshelf_melt_rates_CS2_2010-2018_v0.h5','/w_b')'; % [m/a]
w_b_interp = h5read('ANT_iceshelf_melt_rates_CS2_2010-2018_v0.h5','/w_b_interp')'; % [m/a]
w_b_uncert = h5read('ANT_iceshelf_melt_rates_CS2_2010-2018_v0.h5','/w_b_uncert')'; % [m/a]

%% extract melt rates along six transects at the Larsen C ice shelf and plot

% define coordinates for six transects
tsx = [-2.3426e6 -2.1844e6; -2.33193e6 -2.1753e6; -2.2920e6 -2.1649e6; ...
    -2.2337e6 -2.1519e6; -2.1662e6 -2.1208e6; -2.1364e6 -2.0988e6];
tsy = [1.1588e6 1.2347e6; 1.1266e6 1.2157e6; 1.0712e6 1.1982e6; ...
    1.0055e6 1.1894e6; 0.98803e6 1.1719e6; 0.9880e6 1.1631e6];

% set up figure
figure(1); clf; hold on;
set(gcf,'position',[50 150 1000 400]);
subplot(1,2,1);  
    set(gca,'fontsize',18,'linewidth',2); hold on;
    colormap(cmocean('amp'));
    imagesc(x/10^3,y/10^3,w_b); grid on;
    xlabel('Easting (km)'); ylabel('Northing (km)');
    xlim([-2.4e3 -1.9e3]); ylim([0.9e3 1.4e3]);
    c=colorbar; c.Label.String = "Basal Melt Rate (m a^{-1})"; caxis([0 10]);
    col = cmocean('turbid',7); col(1,:)=[]; % color scheme for plotting
subplot(1,2,2); hold on; grid on;
    set(gca,'fontsize',18,'linewidth',2);
    xlabel('Distance Along Transect (km)'); ylabel('Melt Rate (m/a)');
    
% loop through transects
tsxpts = NaN*ones(length(tsx(:,1)),51); tsypts = NaN*ones(length(tsy(:,1)),51);
mr = NaN*ones(length(tsxpts(:,1)),51); X = zeros(length(tsxpts(:,1)),51); 
for i=1:length(tsx(:,1))
    % increase number of points in transect
    tsxpts(i,:) = tsx(i,1):(tsx(i,2)-tsx(i,1))/50:tsx(i,2);
    tsypts(i,:) = tsy(i,1):(tsy(i,2)-tsy(i,1))/50:tsy(i,2);
    % plot transect on map
    subplot(1,2,1); plot(tsxpts(i,:)/10^3,tsypts(i,:)/10^3,'-','linewidth',2,'color',col(i,:));
    % interpolate melt rate along transect
    mr(i,1:length(tsxpts(i,:))) = interp2(x,y,w_b,tsxpts(i,:),tsypts(i,:)); % [m/a]
    % define distance along transect [m]
    for j=2:length(tsxpts(i,:))
        X(i,j) = sqrt((tsxpts(i,j)-tsxpts(i,j-1))^2+(tsypts(i,j)-tsypts(i,j-1))^2)+X(i,j-1);
    end
    % plot melt rate along transect
    subplot(1,2,2); plot(X(i,:)/10^3,mr(i,:),'color',col(i,:),'linewidth',1);
    % calculate mean melt rate as a function of distance along transect
    if i==length(tsxpts(:,1))
        mr_mean = nanmean(mr);
        % calculate a logarithmic fit
        mr_mean_fit = fit(X(4,~isnan(mr_mean))',mr_mean(~isnan(mr_mean))','exp2');
        % plot results on figure
        subplot(1,2,2); plot(X(4,:)/10^3,mr_mean,'-b','linewidth',3);
        plot(X(4,:)/10^3,feval(mr_mean_fit,X(4,:)),'--b','linewidth',3);
        disp('Best fit logarithmic equation:');
        disp(['y=',num2str(round(mr_mean_fit.a)),'*exp(',num2str(mr_mean_fit.b),...
            '*x) + ',num2str(mr_mean_fit.c),'*exp(',num2str(mr_mean_fit.d),'*x)']);
    end

end

% save melt rate results
if save_mr
    cd([homepath,'CraneGlacier_flowlinemodeling/inputs-outputs/']);
    save('LarsenC_MeanMeltRate.mat','mr','mr_mean','X','tsxpts','tsypts','mr_mean_fit');
    disp('melt rates saved');
end

% save figure
if save_figure
    cd([homepath,'CraneGlacier_flowlinemodeling/figures/']);
    saveas(gcf,'LarsenC_MeanMeltRate.png','png');
    disp('figure 1 saved')
end

%% scale fit for other maximum submarine melt rates - TEST
smr_max = 10; % m/yr
x = 0:200:10e3; % distance along ice tongue (m)
smr = smr_max/(mr_mean_fit.a+1)*feval(mr_mean_fit,x);
smr(1) = 0; 
figure; plot(x,smr); hold on; plot(x,feval(mr_mean_fit,x));

%% Glacier Flowline Model
% Rainey Aberle
% Winter 2020
% Adapted from Ellyn Enderlin's flowline model demo code
%
% Objectives:
%   1. Run flowline model for 100 years to reach near steady-state conditions
%       using 2009 observations. (Skip if output is already saved)
%   2. Tune the enhancement factor along the centerline to minimize
%       misfit between modeled and observed ice surface elevation.
%   3. Tune the fresh water depth in crevasses to minimize the misfit
%       between modeled and observed terminus positions 2009-2019.
%   4. Run sensitivity tests for surface mass balance (SMB) & submarine
%       melting rate (SMR). 

clear all; close all;
warning off; % turn off warnings (velocity coefficient matrix is close to singular)

%% 0. define time and space independent variables
    
dx0 = 250; % desired grid spacing (m)
dx=dx0;
            
use_binavg = 1;     % = 1 to use average within bins proportional to dx0

% define home path in directory
    homepath = '/Users/raineyaberle/Desktop/Research/CraneGlacier_modeling/';
    cd([homepath,'inputs-outputs']);
    addpath([homepath,'scripts/100yrScenario']); % add path to U_convergence

% Load Crane Glacier initialization variables
    load('Crane_flowline_initialization.mat');
    %A0 = polyval(polyfit([x0(1) x0(end)],[A0(1) A0_adj(1,end)],2),x0);
    A0(140:end)=A0(140:end).*2;
    A0 = polyval(polyfit(x0,A0,1),x0);
    beta0 = movmean(beta0,20); % use moving mean for smooth boundaries
    W0(isnan(W0)) = W0(find(~isnan(W0),1,'last'));
    W0 = movmean(W0,20); % use moving mean for smooth boundaries
    
% submarine melting rate parameter
%   Dryak and Enderlin (2020), Crane iceberg melt rates:
%       2013-2014: 0.70 cm/d = 8.1e-8 m/s
%       2014-2015: 0.51 cm/d = 5.29e-8 m/s
%       2015-2016: 0.46 cm/d = 4.77e-8 m/s
%       2016-2017: 0.08 cm/d = 0.823e-8 m/s
%       Mean melt rate (2013-17) = 4.75e-8 m/s = 1.5 m/yr
%   Adusumilli et al. (2018):
%       Larsen C basal melt rate (1994-2016) = 0.5+/-1.4 m/a = 1.59e-8 m/s
%       Larsen C net mass balance (1994-2016)= -0.4+/-1.3 m/a = 1.27e-8 m/s
smr0 = 4.75e-8; % m/s = 1.5 m/a

% Load observations of dH to help tune SMB
    dH_obs = load('dHdt_2009-2018.mat').dHdt.dH_total; % (m) total change in thickness 2009-2018
% Load observations of terminus position to help tune calving parameter
    term = load('Crane_TerminusPosition_2002-2019.mat').term;
    for i=1:length(term)
        termx_obs(i) = term(i).x;
        termDate_obs(i) = term(i).decidate;
    end
    % start in 2009
    termx_obs(1:4)=[]; termDate_obs(1:4)=[];
    % fit a quadratic to the terminus positions
    termx_obs = feval(fit(termDate_obs',termx_obs','poly2'),termDate_obs');
    clear term
    
% densities and g
    rho_i = 917; % ice density (kg m^-3)
    rho_sw = 1028; % ocean water density (kg m^-3)
    rho_fw = 1000; % fresh water density (kg m^-3)
    g = 9.81; % acceleration (m s^-2)

% time stepping (s)
    dt = 0.001*3.1536e7; 
    t_start = 0*3.1536e7; 
    t_end = 100*3.1536e7;    
    t = (t_start:dt:t_end);

% stress parameters (unitless)
    m = 1; % basal sliding exponent
    n = 3; % flow law exponent
    %E = 1; % enhancement factor

% calving parameters
    Hc = 400; % m -> set the calving front to a default minimum ice thickness value
    fwd = 30; % fresh water depth in crevasses (m)
     
% maximum & minimum thickness cut-off to check for instability
    H_max = 2000; % maximum thickness (m)
    H_min = 100;  % minimum thickness (m)

% regrid the initialization data to match the desired grid spacing, 
    xi = x0; % rename initialization distance vector
    L = 70e3; % length of glacier (m)
    xi = 0:dx0:L; % desired distance vector (m from ice divide)  
    
    % calving front location
    c = dsearchn(transpose(xi),termx_obs(1)); % 2009 terminus location (index)
         
    % If the desired grid spacing is smaller than the original, use the
    % interp1 function to determine each spatial vector.
    % Otherwise, take the average within each bin at every point for each
    % spatial variable. 
    if length(xi)>length(x0)
        hi = interp1(x0,h0,xi);
        hbi = interp1(x0,hb0,xi);
        Wi = interp1(x0,W0,xi);
        Ui = interp1(x0,U0,xi);
        Ai = interp1(x0,A0_adj(1,:),xi);
        betai = interp1(x0,beta0,xi);            
    else
        % Use a staggered grid for bin averages
        xm = (xi(1:end-1)+xi(2:end))./2;
        for k=1:length(xi)
            if k==1
              hi(k) = mean(h0(1:dsearchn(x0',xm(k))));
              hbi(k) = mean(hb0(1:dsearchn(x0',xm(k))));
              Wi(k) = mean(W0(1:dsearchn(x0',xm(k))));
              Ui(k) = mean(U0(1:dsearchn(x0',xm(k))));
              Ai(k) = mean(A0_adj(1,1:dsearchn(x0',xm(k))));
              betai(k) = mean(beta0(1:dsearchn(x0',xm(k))));               
            elseif k==length(xi)
              hi(k) = mean(h0(dsearchn(x0',xm(k-1)):c));
              hbi(k) = mean(hb0(dsearchn(x0',xm(k-1)):c));
              Wi(k) = mean(W0(dsearchn(x0',xm(k-1)):c));
              Ui(k) = mean(U0(dsearchn(x0',xm(k-1)):c));
              Ai(k) = mean(A0_adj(1,dsearchn(x0',xm(k-1)):c));
              betai(k) = mean(beta0(dsearchn(x0',xm(k-1)):c));              
            else
              hi(k) = mean(h0(dsearchn(x0',xm(k-1)):dsearchn(x0',xm(k))));
              hbi(k) = mean(hb0(dsearchn(x0',xm(k-1)):dsearchn(x0',xm(k))));
              Wi(k) = mean(W0(dsearchn(x0',xm(k-1)):dsearchn(x0',xm(k))));
              Ui(k) = mean(U0(dsearchn(x0',xm(k-1)):dsearchn(x0',xm(k))));
              Ai(k) = mean(A0_adj(1,dsearchn(x0',xm(k-1)):dsearchn(x0',xm(k))));
              betai(k) = mean(beta0(dsearchn(x0',xm(k-1)):dsearchn(x0',xm(k))));                            
            end
        end
    end 
    
    dUdxi = [(Ui(2:end)-Ui(1:end-1))./(xi(2:end)-xi(1:end-1)) 0]; % strain rate
    Hi = hi-hbi; % thickness (m)    
    
    % find the location of the grounding line and the end of the ice-covered domain
    Hf = -(rho_sw./rho_i).*hbi; % flotation thickness (m)
    gl = find(Hf-Hi>0,1,'first')-1; %grounding line location 
    Hi(gl:end)=hi(gl:end)*rho_sw/(rho_sw-rho_i); % buoyant thickness using surface
    Hi(Hi>=(hi-hbi))=hi(Hi>=(hi-hbi))-hbi(Hi>=(hi-hbi)); % thickness can't go beneath bed elevation
    
    % add a dummy ice end (hi & Hi)
    for i=c-10:length(xi)
        hi(i) = hi(i-1)-5; % decrease until reaching 0m  
        Hi(i) = Hi(i-1)-25; % decrease until reaching 0m 
        if Hi(i)>=hi(i)-hbi(i)
            Hi(i)=hi(i)-hbi(i); % can't go beneath bed elevation
        end
    end  
    hi(hi<0)=0; % surface can't go below sea level
    Hi(Hi<0)=0; % no negative thicknesses
    
    % find the end of the ice-covered domain (m along centerline)
    ice_endi = (find(Hi<=0,1,'first')); 
    if isempty(ice_endi) || ice_endi>length(xi)
        ice_endi=length(xi);
    end
    
    % extend variables past where there are NaNs (set to last value)
    Ai(find(isnan(Ai),1,'first'):end) = Ai(find(isnan(Ai),1,'first')-1);
    Ui(find(isnan(Ui),1,'first'):end) = Ui(find(isnan(Ui),1,'first')-1);
    betai(find(isnan(betai),1,'first'):end) = betai(find(isnan(betai),1,'first')-1);
    hbi(find(isnan(hbi),1,'first'):end) = hbi(find(isnan(hbi),1,'first')-1);
    Wi(find(isnan(Wi),1,'first'):end) = Wi(find(isnan(Wi),1,'first')-1);    
    
    % use 90% the observed velocity at the upper bounds
    Ui(1:round(0.2*length(Ui))) = 0.9.*Ui(1:round(0.2*length(Ui)));
    
    % rename initial vectors
    x=xi; h=hi; hb=hbi; W=Wi; H=Hi; A=Ai; beta=betai; U=Ui; dUdx=dUdxi;
    ice_end=ice_endi;
    
%% 1. Run the flowline model for 100 years to reach near steady-state 
%   conditions using 2009 observations

E = ones(1,length(x)); %polyval(polyfit([x(1) x(end)],[0.5 1.5],2),x);

for i=1:length(t)
    
    if t(i)==t_start
        col = parula(length(t)+20); %Color scheme for plots
        figure(1); clf % glacier geometry
            hold on; grid on;
            set(gcf,'Position',[0 50 500 400]);
            set(gca,'FontSize',14,'linewidth',2,'fontweight','bold'); 
            legend('Location','northeast'); xlim([0 65]); ylim([min(hb)-100 max(h)+200]);
            title('a) Glacier Geometry'); 
            xlabel('Distance Along Centerline (km)'); ylabel('Elevation (m)'); 
            % ice surface
            plot(x(1:c)./10^3,h(1:c),'color',col(i,:),'linewidth',2,'displayname','0');
            % calving front
            plot(x(c)*[1,1]/10^3,[h(c)-H(c),h(c)],'.-','color',col(i,:),'linewidth',2,'HandleVisibility','off');
            % ice end
            plot(x(c+1:ice_end)./10^3,h(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');            
            plot(x(c+1:ice_end)./10^3,h(c+1:ice_end)-H(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');            
            % floating bed
            plot(x(gl:c)/10^3,h(gl:c)-H(gl:c),'color',col(i,:),'linewidth',2,'HandleVisibility','off');
            % bed elevation
            plot(x/10^3,hb,'k','linewidth',2,'HandleVisibility','off'); 
            % mean sea level
            plot([x(1),x(end)]/10^3,[0,0],'k--','HandleVisibility','off'); 
        figure(2); clf % ice speed
            hold on; grid on; 
            set(gcf,'Position',[500 50 500 400]);
            set(gca,'FontSize',14,'linewidth',2,'fontweight','bold'); 
            title('b) Ice Speed Profile');  
            xlim([0 65]); ylim([0 4000]);
            xlabel('Distance Along Centerline (km)'); ylabel('Speed (m yr^{-1})'); 
            legend('Location','northeast'); 
            % 1:c
            plot(x(1:c)./10^3,U(1:c).*3.1536e7,'color',col(i,:),'linewidth',2,'displayname','0');
            % c:ice_end
            plot(x(c:ice_end)./10^3,U(c:ice_end).*3.1536e7,'--','color',col(i,:),'linewidth',2,'HandleVisibility','off');            
        figure(3); clf % terminus position
            hold on; grid on; 
            set(gcf,'Position',[1000 50 500 400]);
            set(gca,'FontSize',14,'linewidth',2,'fontweight','bold');
            title('c) Terminus Position'); ylabel('Year');
            xlabel('Distance Along Centerline (km)'); 
            xlim([35 55]);legend('Location','northeast');
            % initial terminus position
            plot(x(c)/10^3,t(i),'.','markersize',15,'color',col(i,:),'displayname','0'); 
    elseif mod(i-1,round(length(t)/50))==0 %mod(i-1,round(length(t)/10))==0
        figure(1); hold on; % Plot geometries every 10 time iterations  
        if mod(i-1,round(length(t)/10))==0
            % ice surface
            plot(x(1:c)/10^3,h(1:c),'-','color',col(i,:),'linewidth',2,'displayname',num2str(t(i)./3.1536e7)); 
        else
            % ice surface
            plot(x(1:c)/10^3,h(1:c),'-','color',col(i,:),'linewidth',2,'HandleVisibility','off'); 
        end
            % calving front
            plot(x(c)*[1,1]/10^3,[h(c)-H(c),h(c)],'.-','color',col(i,:),'linewidth',2,'HandleVisibility','off');
            % floating bed
            plot(x(gl:c)/10^3,h(gl:c)-H(gl:c),'color',col(i,:),'linewidth',2,'HandleVisibility','off');
            % ice end
            plot(x(c+1:ice_end)./10^3,h(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');            
            plot(x(c+1:ice_end)./10^3,h(c+1:ice_end)-H(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');  
        figure(2); hold on; % Plot velocity every 10 time iterations
        if mod(i-1,round(length(t)/10))==0
            % 1:c
            plot(x(1:c)/10^3,U(1:c).*3.1536e7,'-','Color',col(i,:),'linewidth',2,'DisplayName',num2str(t(i)./3.1536e7)); hold on;
        else
            % 1:c
            plot(x(1:c)/10^3,U(1:c).*3.1536e7,'-','Color',col(i,:),'linewidth',2,'HandleVisibility','off'); hold on;            
        end
            % c:ice_end
            plot(x(c:ice_end)./10^3,U(c:ice_end).*3.1536e7,'--','color',col(i,:),'linewidth',2,'HandleVisibility','off');            
        figure(3); hold on; % Plot terminus position every 10 time iterations   
            if mod(i-1,round(length(t)/10))==0
                plot(x(c)./10^3,t(i)./3.1536e7,'.','Color',col(i,:),'markersize',15,'linewidth',1.5,'displayname',num2str(t(i)./3.1536e7)); hold on;
            else
                plot(x(c)./10^3,t(i)./3.1536e7,'.','Color',col(i,:),'markersize',15,'linewidth',1.5,'HandleVisibility','off'); hold on;                
            end
    end 

    % calculate the thickness required to remain grounded at each grid cell
    Hf = -(rho_sw./rho_i).*hb; %flotation thickness (m)
    % find the location of the grounding line and use a floating
    % geometry from the grounding line to the calving front
    gl = find(Hf-H>0,1,'first')-1; %grounding line location 
    ice_end = find(H<=100,1,'first'); %end of ice-covered domain
    if isempty(ice_end) || ice_end>length(x) || ice_end<c
        ice_end = length(x);
        disp('ice end criteria not met.');
    end

    %calculate the glacier's surface elevation and slope
    h = hb+H; %h = surface elevation (m a.s.l.)
    h(gl:length(x)) = (1-rho_i/rho_sw).*H(gl:length(x)); %adjust the surface elevation of ungrounded ice to account for buoyancy
    dhdx = [(h(2:end)-h(1:end-1))./(x(2:end)-x(1:end-1)) 0]; % surface slope (unitless)

    % find the calving front location (based on Benn et al., 2007 & Nick et al., 2010)
    Rxx = 2*nthroot((dUdx./(E.*A(1:length(dUdx)))),n); %resistive stress (Pa)
    crev = (Rxx./(rho_i.*g))+((rho_fw./rho_i).*fwd); %crevasse penetration depth (m)
    c = find(h(1:ice_end-1)-crev(1:ice_end-1)<=0,1,'first'); %calving front located where the inland-most crevasse intersects sea level
    %if the crevasses never intersect sea level
    if isempty(c) == 1
        c = find(H<Hc,1,'first'); %set the calving front to a default minimum ice thickness value
    end
    if isempty(c)==1
        c=length(x);
        disp('calving criteria not met');
    end
    % if the crevasses first intersect sea level inland of the grounding line 
    if c <= gl
        c = gl; %set the grounding line as the calving front
    end
    % use observed terminus position for first time increment
    if i==1
        c=dsearchn(transpose(x),termx_obs(1));            
    end 

    if any(h<0) % surface cannot go below sea level
        c = find(h<0,1,'first');
        H(c:end) = 0;
        h(c:end)=0;
    end

    %calculate the effective pressure (ice overburden pressure minus water
    %pressure) assuming an easy & open connection between the ocean and
    %ice-bed interface
    sl = find(hb<=0,1,'first'); %find where the glacier base first drops below sea level
    N_ground = rho_i*g*H(1:sl); %effective pressure where the bed is above sea level (Pa)
    N_marine = rho_i*g*H(sl+1:length(x))+(rho_sw*g*hb(sl+1:length(x))); %effective pressure where the bed is below sea level (Pa)
    N = [N_ground N_marine];
    N(N<0)=1; %cannot have negative values

    % Solve for new velocity
    [U,dUdx,vm,T] = U_convergence_varyingE(x,U,U0,dUdx,dhdx,H,A,E,N,W,dx,c,ice_end,n,m,beta,rho_i,rho_sw,g); 

    % calculate ice flux
    F = U.*H.*W; % ice flux (m^3 s^-1)
    F(isnan(F))=0;

    % calculate the  change in ice thickness from continuity
    dHdt = -(1./W).*gradient(F,x);
    dH = dHdt.*dt;

    % surface mass balance
    yr = round(t(i)/3.1536e7)+1;
    if yr>10
        yr=10;
    end
    clear smb sigma_smb smr % clear to avoid changing size with changing x

    % interpolate smb0 to centerline, add tributary flux Q0 to smb
    smb = interp1(x0,smb0+Q0,x); % m/s
    sigma_smb = interp1(x0,smb0_err+Q0_err,x); % m/s
        sigma_smb(ice_end+1:end) = 0; 

    % add submarine melting rate where ice is ungrounded
    smr(1:gl)= 0; % m/s (zero at grounded ice)
    smr(gl+1:length(x)) = -smr0.*ones(1,length(x(gl+1:end))); % m/s

    % adjust smb to minimize misfit of surface observations 
    smb_add = zeros(1,length(x0));
        smb_add = smb_add-0.05e-5;
        smb_add(80:170) = smb_add(80:170)+0.1e-5;
        smb_add(1:50) = smb_add(1:50)+0.11e-5;
    smb = movmean(interp1(x0,smb0+Q0+smb_add,x),20);

    % new thickness (change from dynamics, SMB, & SMR)
    Hn = H+dH+(smb.*dt)+(smr.*dt); 
    Hn(Hn < 0) = 0; % remove negative values 
    H = Hn; %set as the new thickness value
    
    % smooth out the points near the ice divide
    H(1:10) = ones(1,length(H(1:10))).*nanmean(H(1:10),'all');
    
    % thickness & surface past calving front
    for j=c-10:length(xi)
        h(j) = h(j-1)-5; % decrease until reaching 0m  
        H(j) = H(j-1)-25; % decrease until reaching 0m 
        if H(j)>=h(j)-hb(j)
            H(j)=h(j)-hb(j); % can't go beneath bed elevation
        end
    end  
    h(h<0)=0; % surface can't go below sea level
    H(H<0)=0; % no negative thicknesses

    % stop the model if it behaves unstably (monitored by ice thickness and speed)
    if max(H) > H_max
        disp(['Adjust dt']);
        break;
    end
    if min(H(1:c)) < H_min
        disp('Too thin! Check A, beta, E...');
        break; 
    end
    if mean(U)<200/3.1536e7
        disp('Too slow!');
        break;
    end
    
    % find the precise location of the grounding line (where H=Hf)
    xf = x(find(Hf-H>0,1,'first')-1); 

    %adjust the grid spacing so the grounding line is continuously tracked
    xl = round(xf/dx0); %number of ideal grid spaces needed to reach the grounding line
    dx = xf/xl; %new grid spacing (should be ~dx0)
    xn = 0:dx:L; %new distance vector    

    %adjust the space-dependent variables to the new distance vector
    hb = interp1(x0,hb0,xn); hb(isnan(hb)) = hb(find(~isnan(hb),1,'last'));
    W = interp1(x0,W0,xn); W(isnan(W)) = W(find(~isnan(W),1,'last'));
    H = interp1(x,H,xn,'linear','extrap'); H(isnan(H)) = H(find(~isnan(H),1,'last')); % ice thickness (m)
    Hf = interp1(x,Hf,xn,'linear','extrap'); Hf(isnan(Hf)) = Hf(find(~isnan(Hf),1,'last'));
    U = interp1(x,U,xn,'linear','extrap'); % speed (m s^-1)
    A = interp1(x0,A0,x); % rate factor (Pa^-n s^-1)
    beta = interp1(x,beta,xn,'linear','extrap'); % basal roughness factor

    %find the location of the grounding line and end of the ice-covered domain for the adjusted data
    gl = find(Hf-H<0,1,'last');
    ice_end = find(H<=100,1,'first');
    if isempty(ice_end) || ice_end>length(xn) || ice_end<c
        ice_end = length(xn);
        disp('ice end criteria not met.')
    end

    if U(ice_end)==0
        U(ice_end) = U(ice_end-1);
    end

    %rename the distance vector
    x = xn; %distance from the divide (m)

    %calculate the new surface elevation and slope
    h = hb+H; %grounded ice surface elevation (m a.s.l.)
    h(gl:length(x)) = (1-rho_i/rho_sw).*H(gl:length(x)); %floating ice surface elevation (m a.s.l.)   
    dhdx = [(h(2:end)-h(1:end-1))./(x(2:end)-x(1:end-1)) 0]; % surface slope (unitless)

    H(H>=(h-hb))=h(H>=(h-hb))-hb(H>=(h-hb)); % thickness can't go beneath bed elevation

    % calculate new strain rate
    dUdx = [(U(2:end)-U(1:end-1))./(x(2:end)-x(1:end-1)) 0]; % strain rate

    % find the calving front location (based on Benn et al., 2007 & Nick et al., 2010)
        Rxx = 2*nthroot((dUdx./(E.*A(1:length(dUdx)))),n); %resistive stress (Pa)
        crev = (Rxx./(rho_i.*g))+((rho_fw./rho_i).*fwd); %crevasse penetration depth (m)
        c = find(h(1:ice_end-1)-crev(1:ice_end-1)<=0,1,'first'); %calving front located where the inland-most crevasse intersects sea level
        %if the crevasses never intersect sea level
        if isempty(c) == 1
            c = find(H<Hc,1,'first'); %set the calving front to a default minimum ice thickness value
        end
        if isempty(c)==1
            c=length(x);
            disp('calving criteria not met');
        end
        % if the crevasses first intersect sea level inland of the grounding line 
        if c <= gl
            c = gl; %set the grounding line as the calving front
        end
        % use observed terminus position for first time increment
        if i==1
            c=dsearchn(transpose(x),termx_obs(1));            
        end 

        if any(h<0) % surface cannot go below sea level
            c = find(h<0,1,'first');
            H(c:end) = 0;
            h(c:end)=0;
        end

end

    % save conditions
    xj=x; hj=h; hbj=hb; Wj=W; Hj=H; Aj=A; betaj=beta; Uj=U; dUdxj=dUdx;
    ice_endj=ice_end; cj=c;  
    save('Crane_flowline_100yr_output2.mat','xj','hj','Wj','Hj','Aj',...
        'betaj','Uj','dUdxj','ice_endj','cj','hbj');
    disp('saved year 100 conditions.');
    
%% 2. Tune enhancement factor E along centerline to minimize misfit between
%   modeled and observed surface elevation
%   (using 100 yr output as initialization)

close all; 
addpath([homepath,'inputs-outputs']);
addpath([homepath,'scripts/100yrScenario']);

% load 100 yr output conditions
    load('Crane_flowline_100yr_output2.mat');

% initialize variables using final conditions from 100 yr scenario
    x=xj; h=hj; hb=hbi; W=Wj; H=Hj; A=Aj; beta=betaj; U=Uj; dUdx=dUdxj; 
    ice_end=ice_endj; c=cj; 
    
% Define E fit variables
    ub_E = [0.5 1]; % upper bound (minimum E near ice divide)
    lb_E = 0.5:0.5:2; % lower bound (maximum E at terminus)
    deg_E = 0:3; % polynomial degrees
    col_E = winter(length(deg_E)*length(lb_E)*length(ub_E)); % color scheme for plotting

    % set up figure
    figure(10); clf
    set(gca,'fontsize',14,'linewidth',2);
    xlabel('distance along centerline (km)'); ylabel('enhancement factor');
    grid on; hold on; title('Enhancement Factor Fits');
    
    count = 0; % counter
    % loop through upper bounds
    for i=1:length(deg_E)
        % loop through lower bounds
        for j=1:length(ub_E)
            % loop through polynomial degrees
            for k=1:length(lb_E)
                count=count+1;
                Efit(count).degree = deg_E(i);
                Efit(count).fit = polyfit([x(1) x(end)],[ub_E(j) lb_E(k)],deg_E(i));
                Efit(count).E = polyval(Efit(count).fit,x);
                figure(10); hold on;
                plot(x./10^3,Efit(count).E,'color',col_E(count,:),'linewidth',2);
            end
        end
    end

% redefine time variables
    dt = 0.001*3.1536e7; 
    t_start = 0*3.1536e7; 
    t_end = 10*3.1536e7;    
    t = (t_start:dt:t_end);

% pre-allocate dH variables
    dH_tot = zeros(length(Efit),length(x)); % total dH on each iteration
    dH_misfit = zeros(length(Efit),length(x)); % misfit of total dH 
    dH_misfit_mean = zeros(length(Efit),1); % mean misfit of total dH

% loop through all Efits
for e=1:length(Efit)
    
    E = Efit(e).E; % define E
    
    % re-initialize variables using final conditions from 100 yr scenario
    x=xj; h=hj; hb=hbi; W=Wj; H=Hj; A=Aj; beta=betaj; U=Uj; dUdx=dUdxj; 
    ice_end=ice_endj; c=cj; 
    
    % Run flowline model
    for i=1:length(t)
        
        if t(i)==t_start
            col = parula(length(t)+20); %Color scheme for plots
            figure(1); clf % glacier geometry
            hold on; grid on;
            set(gcf,'Position',[0 50 500 400]);
            set(gca,'FontSize',14,'linewidth',2,'fontweight','bold');
            legend('Location','northeast'); xlim([0 65]); ylim([min(hb)-100 max(h)+200]);
            title('a) Glacier Geometry');
            xlabel('Distance Along Centerline (km)'); ylabel('Elevation (m)');
            % ice surface
            plot(x(1:c)./10^3,h(1:c),'color',col(i,:),'linewidth',2,'displayname','0');
            % calving front
            plot(x(c)*[1,1]/10^3,[h(c)-H(c),h(c)],'.-','color',col(i,:),'linewidth',2,'HandleVisibility','off');
            % ice end
            plot(x(c+1:ice_end)./10^3,h(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');
            plot(x(c+1:ice_end)./10^3,h(c+1:ice_end)-H(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');
            % floating bed
            plot(x(gl:c)/10^3,h(gl:c)-H(gl:c),'color',col(i,:),'linewidth',2,'HandleVisibility','off');
            % bed elevation
            plot(x/10^3,hb,'k','linewidth',2,'HandleVisibility','off');
            % mean sea level
            plot([x(1),x(end)]/10^3,[0,0],'k--','HandleVisibility','off');
            figure(2); clf % ice speed
            hold on; grid on;
            set(gcf,'Position',[500 50 500 400]);
            set(gca,'FontSize',14,'linewidth',2,'fontweight','bold');
            title('b) Ice Speed Profile');
            xlim([0 65]); ylim([0 4000]);
            xlabel('Distance Along Centerline (km)'); ylabel('Speed (m yr^{-1})');
            legend('Location','northeast');
            % 1:c
            plot(x(1:c)./10^3,U(1:c).*3.1536e7,'color',col(i,:),'linewidth',2,'displayname','0');
            % c:ice_end
            plot(x(c:ice_end)./10^3,U(c:ice_end).*3.1536e7,'--','color',col(i,:),'linewidth',2,'HandleVisibility','off');
            figure(3); clf % terminus position
            hold on; grid on;
            set(gcf,'Position',[1000 50 500 400]);
            set(gca,'FontSize',14,'linewidth',2,'fontweight','bold');
            title('c) Terminus Position'); ylabel('Year');
            xlabel('Distance Along Centerline (km)');
            xlim([35 55]);legend('Location','northeast');
            % initial terminus position
            plot(x(c)/10^3,t(i),'.','markersize',15,'color',col(i,:),'displayname','0');
        elseif mod(i-1,round(length(t)/50))==0 %mod(i-1,round(length(t)/10))==0
            figure(1); hold on; % Plot geometries every 10 time iterations
            if mod(i-1,round(length(t)/10))==0
                % ice surface
                plot(x(1:c)/10^3,h(1:c),'-','color',col(i,:),'linewidth',2,'displayname',num2str(t(i)./3.1536e7));
            else
                % ice surface
                plot(x(1:c)/10^3,h(1:c),'-','color',col(i,:),'linewidth',2,'HandleVisibility','off');
            end
            % calving front
            plot(x(c)*[1,1]/10^3,[h(c)-H(c),h(c)],'.-','color',col(i,:),'linewidth',2,'HandleVisibility','off');
            % floating bed
            plot(x(gl:c)/10^3,h(gl:c)-H(gl:c),'color',col(i,:),'linewidth',2,'HandleVisibility','off');
            % ice end
            plot(x(c+1:ice_end)./10^3,h(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');
            plot(x(c+1:ice_end)./10^3,h(c+1:ice_end)-H(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');
            figure(2); hold on; % Plot velocity every 10 time iterations
            if mod(i-1,round(length(t)/10))==0
                % 1:c
                plot(x(1:c)/10^3,U(1:c).*3.1536e7,'-','Color',col(i,:),'linewidth',2,'DisplayName',num2str(t(i)./3.1536e7)); hold on;
            else
                % 1:c
                plot(x(1:c)/10^3,U(1:c).*3.1536e7,'-','Color',col(i,:),'linewidth',2,'HandleVisibility','off'); hold on;
            end
            % c:ice_end
            plot(x(c:ice_end)./10^3,U(c:ice_end).*3.1536e7,'--','color',col(i,:),'linewidth',2,'HandleVisibility','off');
            figure(3); hold on; % Plot terminus position every 10 time iterations
            if mod(i-1,round(length(t)/10))==0
                plot(x(c)./10^3,t(i)./3.1536e7,'.','Color',col(i,:),'markersize',15,'linewidth',1.5,'displayname',num2str(t(i)./3.1536e7)); hold on;
            else
                plot(x(c)./10^3,t(i)./3.1536e7,'.','Color',col(i,:),'markersize',15,'linewidth',1.5,'HandleVisibility','off'); hold on;
            end
        end
        
        % calculate the thickness required to remain grounded at each grid cell
        Hf = -(rho_sw./rho_i).*hb; %flotation thickness (m)
        % find the location of the grounding line and use a floating
        % geometry from the grounding line to the calving front
        gl = find(Hf-H>0,1,'first')-1; %grounding line location
        ice_end = find(H<=100,1,'first'); %end of ice-covered domain
        if isempty(ice_end) || ice_end>length(x) || ice_end<c
            ice_end = length(x);
            disp('ice end criteria not met.');
        end
        
        %calculate the glacier's surface elevation and slope
        h = hb+H; %h = surface elevation (m a.s.l.)
        h(gl:length(x)) = (1-rho_i/rho_sw).*H(gl:length(x)); %adjust the surface elevation of ungrounded ice to account for buoyancy
        dhdx = [(h(2:end)-h(1:end-1))./(x(2:end)-x(1:end-1)) 0]; % surface slope (unitless)
        
        % find the calving front location (based on Benn et al., 2007 & Nick et al., 2010)
        Rxx = 2*nthroot((dUdx./(E.*A(1:length(dUdx)))),n); %resistive stress (Pa)
        crev = (Rxx./(rho_i.*g))+((rho_fw./rho_i).*fwd); %crevasse penetration depth (m)
        c = find(h(1:ice_end-1)-crev(1:ice_end-1)<=0,1,'first'); %calving front located where the inland-most crevasse intersects sea level
        %if the crevasses never intersect sea level
        if isempty(c) == 1
            c = find(H<Hc,1,'first'); %set the calving front to a default minimum ice thickness value
        end
        if isempty(c)==1
            c=length(x);
            disp('calving criteria not met');
        end
        % if the crevasses first intersect sea level inland of the grounding line
        if c <= gl
            c = gl; %set the grounding line as the calving front
        end
        % use observed terminus position for first time increment
        if i==1
            c=dsearchn(transpose(x),termx_obs(1));
        end
        
        if any(h<0) % surface cannot go below sea level
            c = find(h<0,1,'first');
            H(c:end) = 0;
            h(c:end)=0;
        end
        
        %calculate the effective pressure (ice overburden pressure minus water
        %pressure) assuming an easy & open connection between the ocean and
        %ice-bed interface
        sl = find(hb<=0,1,'first'); %find where the glacier base first drops below sea level
        N_ground = rho_i*g*H(1:sl); %effective pressure where the bed is above sea level (Pa)
        N_marine = rho_i*g*H(sl+1:length(x))+(rho_sw*g*hb(sl+1:length(x))); %effective pressure where the bed is below sea level (Pa)
        N = [N_ground N_marine];
        N(N<0)=1; %cannot have negative values
        
        % Solve for new velocity
        [U,dUdx,vm,T] = U_convergence_varyingE(x,U,U0,dUdx,dhdx,H,A,E,N,W,dx,c,ice_end,n,m,beta,rho_i,rho_sw,g);
        
        % calculate ice flux
        F = U.*H.*W; % ice flux (m^3 s^-1)
        F(isnan(F))=0;
        
        % calculate the  change in ice thickness from continuity
        dHdt = -(1./W).*gradient(F,x);
        dH = dHdt.*dt;
        
        % surface mass balance
        yr = round(t(i)/3.1536e7)+1;
        if yr>10
            yr=10;
        end
        clear smb sigma_smb smr % clear to avoid changing size with changing x
        
        % interpolate smb0 to centerline, add tributary flux Q0 to smb
        smb = interp1(x0,smb0+Q0,x); % m/s
        sigma_smb = interp1(x0,smb0_err+Q0_err,x); % m/s
        sigma_smb(ice_end+1:end) = 0;
        
        % add submarine melting rate where ice is ungrounded
        smr(1:gl)= 0; % m/s (zero at grounded ice)
        smr(gl+1:length(x)) = -smr0.*ones(1,length(x(gl+1:end))); % m/s
        
        % adjust smb to minimize misfit of surface observations
        smb_add = zeros(1,length(x0));
        smb_add = smb_add-0.05e-5;
        smb_add(80:170) = smb_add(80:170)+0.1e-5;
        smb_add(1:50) = smb_add(1:50)+0.11e-5;
        smb = movmean(interp1(x0,smb0+Q0+smb_add,x),20);
        
        % new thickness (change from dynamics, SMB, & SMR)
        Hn = H+dH+(smb.*dt)+(smr.*dt);
        Hn(Hn < 0) = 0; % remove negative values
        H = Hn; %set as the new thickness value
        
        % smooth out the points near the ice divide
        H(1:10) = ones(1,length(H(1:10))).*nanmean(H(1:10),'all');
        
        % thickness & surface past calving front
        for j=c-10:length(xi)
            h(j) = h(j-1)-5; % decrease until reaching 0m
            H(j) = H(j-1)-25; % decrease until reaching 0m
            if H(j)>=h(j)-hb(j)
                H(j)=h(j)-hb(j); % can't go beneath bed elevation
            end
        end
        h(h<0)=0; % surface can't go below sea level
        H(H<0)=0; % no negative thicknesses
        
        % stop the model if it behaves unstably (monitored by ice thickness and speed)
        if max(H) > H_max
            disp(['Adjust dt']);
            break;
        end
        if min(H(1:c)) < H_min
            disp('Too thin! Check A, beta, E...');
            break;
        end
        if mean(U)<200/3.1536e7
            disp('Too slow!');
            break;
        end
        
        % find the precise location of the grounding line (where H=Hf)
        xf = x(find(Hf-H>0,1,'first')-1);
        
        %adjust the grid spacing so the grounding line is continuously tracked
        xl = round(xf/dx0); %number of ideal grid spaces needed to reach the grounding line
        dx = xf/xl; %new grid spacing (should be ~dx0)
        xn = 0:dx:L; %new distance vector
        
        %adjust the space-dependent variables to the new distance vector
        hb = interp1(x0,hb0,xn); hb(isnan(hb)) = hb(find(~isnan(hb),1,'last'));
        W = interp1(x0,W0,xn); W(isnan(W)) = W(find(~isnan(W),1,'last'));
        H = interp1(x,H,xn,'linear','extrap'); H(isnan(H)) = H(find(~isnan(H),1,'last')); % ice thickness (m)
        Hf = interp1(x,Hf,xn,'linear','extrap'); Hf(isnan(Hf)) = Hf(find(~isnan(Hf),1,'last'));
        U = interp1(x,U,xn,'linear','extrap'); % speed (m s^-1)
        A = interp1(x0,A0,x); % rate factor (Pa^-n s^-1)
        beta = interp1(x,beta,xn,'linear','extrap'); % basal roughness factor
        
        %find the location of the grounding line and end of the ice-covered domain for the adjusted data
        gl = find(Hf-H<0,1,'last');
        ice_end = find(H<=100,1,'first');
        if isempty(ice_end) || ice_end>length(xn) || ice_end<c
            ice_end = length(xn);
            disp('ice end criteria not met.')
        end
        
        if U(ice_end)==0
            U(ice_end) = U(ice_end-1);
        end
        
        %rename the distance vector
        x = xn; %distance from the divide (m)
        
        %calculate the new surface elevation and slope
        h = hb+H; %grounded ice surface elevation (m a.s.l.)
        h(gl:length(x)) = (1-rho_i/rho_sw).*H(gl:length(x)); %floating ice surface elevation (m a.s.l.)
        dhdx = [(h(2:end)-h(1:end-1))./(x(2:end)-x(1:end-1)) 0]; % surface slope (unitless)
        
        H(H>=(h-hb))=h(H>=(h-hb))-hb(H>=(h-hb)); % thickness can't go beneath bed elevation
        
        % calculate new strain rate
        dUdx = [(U(2:end)-U(1:end-1))./(x(2:end)-x(1:end-1)) 0]; % strain rate
        
        % find the calving front location (based on Benn et al., 2007 & Nick et al., 2010)
        Rxx = 2*nthroot((dUdx./(E.*A(1:length(dUdx)))),n); %resistive stress (Pa)
        crev = (Rxx./(rho_i.*g))+((rho_fw./rho_i).*fwd); %crevasse penetration depth (m)
        c = find(h(1:ice_end-1)-crev(1:ice_end-1)<=0,1,'first'); %calving front located where the inland-most crevasse intersects sea level
        %if the crevasses never intersect sea level
        if isempty(c) == 1
            c = find(H<Hc,1,'first'); %set the calving front to a default minimum ice thickness value
        end
        if isempty(c)==1
            c=length(x);
            disp('calving criteria not met');
        end
        % if the crevasses first intersect sea level inland of the grounding line
        if c <= gl
            c = gl; %set the grounding line as the calving front
        end
        % use observed terminus position for first time increment
        if i==1
            c=dsearchn(transpose(x),termx_obs(1));
        end
        
        if any(h<0) % surface cannot go below sea level
            c = find(h<0,1,'first');
            H(c:end) = 0;
            h(c:end)=0;
        end
        
    end

    % Calculate total dH at each point along the centerline
    dH_tot(e,:) = interp1(x,h,xj)-hj;
    
    % Calculate dH misfit at each point along the centerline
    dH_misfit(e,:) = dH_tot(e,:)-interp1(x0,dH_obs,xj);
    dH_misfit_mean(e) = nanmean(dH_misfit(e,:),'all');
    
end 

% plot results
figure(11); clf
    IEbest = find(abs(dH_misfit_mean)==min(abs(dH_misfit_mean)),1,'first');
    Ebest = Efit(IEbest).E; 
    hold on; grid on; legend;
    set(gca,'fontsize',14,'linewidth',2); 
    xlabel('distance along centerline (km)'); ylabel('dH (m)');
    eqn = ['E = ',num2str(Efit(IEbest).fit(1)),'*x + ',num2str(Efit(IEbest).fit(2))];
    plot(x./10^3,dH_tot(IEbest,:),'color',col_E(IEbest,:),'linewidth',2,...
        'displayname',eqn);
    plot(x0./10^3,dH_obs,'-k','linewidth',3,'displayname','observed dH');

% save Ebest
cd([homepath,'inputs-outputs']);
save('Ebest.mat','Ebest','x');
disp('Ebest saved');
    
%% 3. Tune fresh water depth in crevasses fwd
% (Using 100 yr output as initialization)

close all;

% load Ebest and 100 yr output variables
cd([homepath,'inputs-outputs']);
E = load('Ebest.mat').Ebest;
load('Crane_flowline_100yr_output.mat');

% calving parameters
Hc = 400; % m -> set the calving front to a default minimum ice thickness value
fwd = 10:5:100; % fresh water depth in crevasses (m)
term_rmse = zeros(length(fwd),length(t));

% loop through fwd
for q=1:length(fwd)
    
    disp(q);
    
    % re-initialize variables using final conditions from 100 yr scenario
    x=xj; h=hj; hb=hbj; W=Wj; H=Hj; A=Aj; beta=betaj; U=Uj; dUdx=dUdxj; 
    ice_end=ice_endj; c=dsearchn(x',termx_obs(1));
    
    % continue to the next loop if there is an error
    try
        for i=1:length(t)
            
            if t(i)==t_start
                col = parula(length(t)+20); %Color scheme for plots
                figure(1); clf % glacier geometry
                hold on; grid on;
                set(gcf,'Position',[0 50 500 400]);
                set(gca,'FontSize',14,'linewidth',2,'fontweight','bold');
                legend('Location','northeast'); xlim([0 65]); ylim([min(hb)-100 max(h)+200]);
                title('a) Glacier Geometry');
                xlabel('Distance Along Centerline (km)'); ylabel('Elevation (m)');
                % ice surface
                plot(x(1:c)./10^3,h(1:c),'color',col(i,:),'linewidth',2,'displayname','0');
                % calving front
                plot(x(c)*[1,1]/10^3,[h(c)-H(c),h(c)],'.-','color',col(i,:),'linewidth',2,'HandleVisibility','off');
                % ice end
                plot(x(c+1:ice_end)./10^3,h(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');
                plot(x(c+1:ice_end)./10^3,h(c+1:ice_end)-H(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');
                % floating bed
                plot(x(gl:c)/10^3,h(gl:c)-H(gl:c),'color',col(i,:),'linewidth',2,'HandleVisibility','off');
                % bed elevation
                plot(x/10^3,hb,'k','linewidth',2,'HandleVisibility','off');
                % mean sea level
                plot([x(1),x(end)]/10^3,[0,0],'k--','HandleVisibility','off');
                figure(2); clf % ice speed
                hold on; grid on;
                set(gcf,'Position',[500 50 500 400]);
                set(gca,'FontSize',14,'linewidth',2,'fontweight','bold');
                title('b) Ice Speed Profile');
                xlim([0 65]); ylim([0 4000]);
                xlabel('Distance Along Centerline (km)'); ylabel('Speed (m yr^{-1})');
                legend('Location','northeast');
                % 1:c
                plot(x(1:c)./10^3,U(1:c).*3.1536e7,'color',col(i,:),'linewidth',2,'displayname','0');
                % c:ice_end
                plot(x(c:ice_end)./10^3,U(c:ice_end).*3.1536e7,'--','color',col(i,:),'linewidth',2,'HandleVisibility','off');
                figure(3); clf % terminus position
                hold on; grid on;
                set(gcf,'Position',[1000 50 500 400]);
                set(gca,'FontSize',14,'linewidth',2,'fontweight','bold');
                title('c) Terminus Position'); ylabel('Year');
                xlabel('Distance Along Centerline (km)');
                xlim([35 55]);legend('Location','northeast');
                % initial terminus position
                plot(x(c)/10^3,t(i),'.','markersize',15,'color',col(i,:),'displayname','0');
            elseif mod(i-1,round(length(t)/50))==0 %mod(i-1,round(length(t)/10))==0
                figure(1); hold on; % Plot geometries every 10 time iterations
                if mod(i-1,round(length(t)/10))==0
                    % ice surface
                    plot(x(1:c)/10^3,h(1:c),'-','color',col(i,:),'linewidth',2,'displayname',num2str(t(i)./3.1536e7));
                else
                    % ice surface
                    plot(x(1:c)/10^3,h(1:c),'-','color',col(i,:),'linewidth',2,'HandleVisibility','off');
                end
                % calving front
                plot(x(c)*[1,1]/10^3,[h(c)-H(c),h(c)],'.-','color',col(i,:),'linewidth',2,'HandleVisibility','off');
                % floating bed
                plot(x(gl:c)/10^3,h(gl:c)-H(gl:c),'color',col(i,:),'linewidth',2,'HandleVisibility','off');
                % ice end
                plot(x(c+1:ice_end)./10^3,h(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');
                plot(x(c+1:ice_end)./10^3,h(c+1:ice_end)-H(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');
                figure(2); hold on; % Plot velocity every 10 time iterations
                if mod(i-1,round(length(t)/10))==0
                    % 1:c
                    plot(x(1:c)/10^3,U(1:c).*3.1536e7,'-','Color',col(i,:),'linewidth',2,'DisplayName',num2str(t(i)./3.1536e7)); hold on;
                else
                    % 1:c
                    plot(x(1:c)/10^3,U(1:c).*3.1536e7,'-','Color',col(i,:),'linewidth',2,'HandleVisibility','off'); hold on;
                end
                % c:ice_end
                plot(x(c:ice_end)./10^3,U(c:ice_end).*3.1536e7,'--','color',col(i,:),'linewidth',2,'HandleVisibility','off');
                figure(3); hold on; % Plot terminus position every 10 time iterations
                if mod(i-1,round(length(t)/10))==0
                    plot(x(c)./10^3,t(i)./3.1536e7,'.','Color',col(i,:),'markersize',15,'linewidth',1.5,'displayname',num2str(t(i)./3.1536e7)); hold on;
                else
                    plot(x(c)./10^3,t(i)./3.1536e7,'.','Color',col(i,:),'markersize',15,'linewidth',1.5,'HandleVisibility','off'); hold on;
                end
            end
            
            % calculate the thickness required to remain grounded at each grid cell
            Hf = -(rho_sw./rho_i).*hb; %flotation thickness (m)
            % find the location of the grounding line and use a floating
            % geometry from the grounding line to the calving front
            gl = find(Hf-H>0,1,'first')-1; %grounding line location
            ice_end = find(H<=100,1,'first'); %end of ice-covered domain
            if isempty(ice_end) || ice_end>length(x) || ice_end<c
                ice_end = length(x);
                disp('ice end criteria not met.');
            end
            
            %calculate the glacier's surface elevation and slope
            h = hb+H; %h = surface elevation (m a.s.l.)
            h(gl:length(x)) = (1-rho_i/rho_sw).*H(gl:length(x)); %adjust the surface elevation of ungrounded ice to account for buoyancy
            dhdx = [(h(2:end)-h(1:end-1))./(x(2:end)-x(1:end-1)) 0]; % surface slope (unitless)
            
            % find the calving front location (based on Benn et al., 2007 & Nick et al., 2010)
            Rxx = 2*nthroot((dUdx./(E.*A(1:length(dUdx)))),n); %resistive stress (Pa)
            crev = (Rxx./(rho_i.*g))+((rho_fw./rho_i).*fwd(q)); %crevasse penetration depth (m)
            c = find(h(1:ice_end-1)-crev(1:ice_end-1)<=0,1,'first'); %calving front located where the inland-most crevasse intersects sea level
            %if the crevasses never intersect sea level
            if isempty(c) == 1
                c = find(H<Hc,1,'first'); %set the calving front to a default minimum ice thickness value
            end
            if isempty(c)==1
                c=length(x);
                disp('calving criteria not met');
            end
            % if the crevasses first intersect sea level inland of the grounding line
            if c <= gl
                c = gl; %set the grounding line as the calving front
            end
            % use observed terminus position for first time increment
            if i==1
                c=dsearchn(transpose(x),termx_obs(1));
            end
            
            if any(h<0) % surface cannot go below sea level
                c = find(h<0,1,'first');
                H(c:end) = 0;
                h(c:end)=0;
            end
            
            %calculate the effective pressure (ice overburden pressure minus water
            %pressure) assuming an easy & open connection between the ocean and
            %ice-bed interface
            sl = find(hb<=0,1,'first'); %find where the glacier base first drops below sea level
            N_ground = rho_i*g*H(1:sl); %effective pressure where the bed is above sea level (Pa)
            N_marine = rho_i*g*H(sl+1:length(x))+(rho_sw*g*hb(sl+1:length(x))); %effective pressure where the bed is below sea level (Pa)
            N = [N_ground N_marine];
            N(N<0)=1; %cannot have negative values
            
            % Solve for new velocity
            [U,~,vm,T] = U_convergence_varyingE(x,U,U0,dUdx,dhdx,H,A,E,N,W,dx,c,ice_end,n,m,beta,rho_i,rho_sw,g);
            
            % calculate ice flux
            F = U.*H.*W; % ice flux (m^3 s^-1)
            F(isnan(F))=0;
            
            % calculate the  change in ice thickness from continuity
            dHdt = -(1./W).*gradient(F,x);
            dH = dHdt.*dt;
            
            % surface mass balance
            yr = round(t(i)/3.1536e7)+1;
            if yr>10
                yr=10;
            end
            clear smb sigma_smb smr % clear to avoid changing size with changing x
            
            % interpolate smb0 to centerline, add tributary flux Q0 to smb
            smb = interp1(x0,smb0+Q0,x); % m/s
            sigma_smb = interp1(x0,smb0_err+Q0_err,x); % m/s
            sigma_smb(ice_end+1:end) = 0;
            
            % add submarine melting rate where ice is ungrounded
            smr(1:gl)= 0; % m/s (zero at grounded ice)
            smr(gl+1:length(x)) = -smr0.*ones(1,length(x(gl+1:end))); % m/s
            
            % adjust smb to minimize misfit of surface observations
            smb_add = zeros(1,length(x0));
            smb_add = smb_add-0.05e-5;
            smb_add(80:170) = smb_add(80:170)+0.1e-5;
            smb_add(1:50) = smb_add(1:50)+0.11e-5;
            smb = movmean(interp1(x0,smb0+Q0+smb_add,x),20);
            
            % new thickness (change from dynamics, SMB, & SMR)
            Hn = H+dH+(smb.*dt)+(smr.*dt);
            Hn(Hn < 0) = 0; % remove negative values
            H = Hn; %set as the new thickness value
            
            % smooth out the points near the ice divide
            H(1:10) = ones(1,length(H(1:10))).*nanmean(H(1:10),'all');
            
            % thickness & surface past calving front
            for j=c-10:length(xi)
                h(j) = h(j-1)-5; % decrease until reaching 0m
                H(j) = H(j-1)-25; % decrease until reaching 0m
                if H(j)>=h(j)-hb(j)
                    H(j)=h(j)-hb(j); % can't go beneath bed elevation
                end
            end
            h(h<0)=0; % surface can't go below sea level
            H(H<0)=0; % no negative thicknesses
            
            % stop the model if it behaves unstably (monitored by ice thickness and speed)
            if max(H) > H_max
                disp(['Adjust dt']);
                break;
            end
            if min(H(1:c)) < H_min
                disp('Too thin! Check A, beta, E...');
                break;
            end
            if mean(U)<200/3.1536e7
                disp('Too slow!');
                break;
            end
            
            % find the precise location of the grounding line (where H=Hf)
            xf = x(find(Hf-H>0,1,'first')-1);
            
            %adjust the grid spacing so the grounding line is continuously tracked
            xl = round(xf/dx0); %number of ideal grid spaces needed to reach the grounding line
            dx = xf/xl; %new grid spacing (should be ~dx0)
            xn = 0:dx:L; %new distance vector
            
            %adjust the space-dependent variables to the new distance vector
            hb = interp1(x0,hb0,xn); hb(isnan(hb)) = hb(find(~isnan(hb),1,'last'));
            W = interp1(x0,W0,xn); W(isnan(W)) = W(find(~isnan(W),1,'last'));
            H = interp1(x,H,xn,'linear','extrap'); H(isnan(H)) = H(find(~isnan(H),1,'last')); % ice thickness (m)
            Hf = interp1(x,Hf,xn,'linear','extrap'); Hf(isnan(Hf)) = Hf(find(~isnan(Hf),1,'last'));
            U = interp1(x,U,xn,'linear','extrap'); % speed (m s^-1)
            A = interp1(x0,A0,x); % rate factor (Pa^-n s^-1)
            beta = interp1(x,beta,xn,'linear','extrap'); % basal roughness factor
            
            %find the location of the grounding line and end of the ice-covered domain for the adjusted data
            gl = find(Hf-H<0,1,'last');
            ice_end = find(H<=100,1,'first');
            if isempty(ice_end) || ice_end>length(xn) || ice_end<c
                ice_end = length(xn);
                disp('ice end criteria not met.')
            end
            
            if U(ice_end)==0
                U(ice_end) = U(ice_end-1);
            end
            
            %rename the distance vector
            x = xn; %distance from the divide (m)
            
            %calculate the new surface elevation and slope
            h = hb+H; %grounded ice surface elevation (m a.s.l.)
            h(gl:length(x)) = (1-rho_i/rho_sw).*H(gl:length(x)); %floating ice surface elevation (m a.s.l.)
            dhdx = [(h(2:end)-h(1:end-1))./(x(2:end)-x(1:end-1)) 0]; % surface slope (unitless)
            
            H(H>=(h-hb))=h(H>=(h-hb))-hb(H>=(h-hb)); % thickness can't go beneath bed elevation
            
            % calculate new strain rate
            dUdx = [(U(2:end)-U(1:end-1))./(x(2:end)-x(1:end-1)) 0]; % strain rate
            
            % find the calving front location (based on Benn et al., 2007 & Nick et al., 2010)
            Rxx = 2*nthroot((dUdx./(E.*A(1:length(dUdx)))),n); %resistive stress (Pa)
            crev = (Rxx./(rho_i.*g))+((rho_fw./rho_i).*fwd(q)); %crevasse penetration depth (m)
            c = find(h(1:ice_end-1)-crev(1:ice_end-1)<=0,1,'first'); %calving front located where the inland-most crevasse intersects sea level
            %if the crevasses never intersect sea level
            if isempty(c) == 1
                c = find(H<Hc,1,'first'); %set the calving front to a default minimum ice thickness value
            end
            if isempty(c)==1
                c=length(x);
                disp('calving criteria not met');
            end
            % if the crevasses first intersect sea level inland of the grounding line
            if c <= gl
                c = gl; %set the grounding line as the calving front
            end
            % use observed terminus position for first time increment
            if i==1
                c=dsearchn(transpose(x),termx_obs(1));
            end
            
            if any(h<0) % surface cannot go below sea level
                c = find(h<0,1,'first');
                H(c:end) = 0;
                h(c:end)=0;
            end
            
        end
    catch
        disp(['iteration q=',num2str(q),' broke the loop.']);
        term_rmse(q,i:end) = NaN; % insert NaNs for remaining times
        continue; % continue to the next loop
    end
    
end

term_rmse(term_rmse==0)=NaN;
term_Cts = zeros(1,length(fwd)); % # of successful iterations per combo
term_rmse_mean = zeros(1,length(fwd));
term_rmse_final = zeros(1,length(fwd)); 

for q=1:length(fwd)
    
    % Count the number of time iterations in each combo before crashing
    term_Cts(q) = length(find(~isnan(term_rmse(q,:))));
    
    % Calculate mean RMSE for each combo of Hc and fwd
    term_rmse_mean(q) = nanmean(term_rmse(q,:));
    
    % Grab the misfit just for the final year
    term_rmse_final(q) = term_rmse(q,end);
    
end

% Display results
figure(6); clf; hold on;
    plot(fwd,term_rmse_mean,'.-k','markersize',10,'linewidth',2,'displayname','mean RMSE');
    plot(fwd,term_rmse_final,'.--k','markersize',10,'linewidth',2,'displayname','final RMSE');
    set(gca,'fontsize',14,'linewidth',2);
    xlabel('fwd (m)'); ylabel('Mean error'); legend;
    yyaxis right
    plot(fwd,term_Cts,'.-r','markersize',5,'linewidth',1,'displayname','# points');
    ylabel('# of points');

%% 4. Run sensitivity tests for SMB & SMR
% (Using 100 yr output as initialization)

% load Ebest and 100 yr output variables
cd([homepath,'inputs-outputs']);
E = load('Ebest.mat').Ebest; % optimal enhancement factor
load('Crane_100yr_sensitivityTests_h1.mat'); % load no change variables
load('Crane_flowline_100yr_output.mat');
fwd=27; % best fwd from step #3

save_figure = 1; % = 1 to save resulting figure

% set up changes in SMB & SMR
smb_change = 0.0e-7; % m/s change in SMB
smr_change = 0.0e-7; % m/s change in SMR
  
% initialize variables using 100yr output
A=Aj; H=Hj; U=Uj; W=Wj; beta=betaj; c=cj; dUdx=dUdxj; h=hj; 
ice_end=ice_endj; x=xj;

% time stepping (s)
dt = 0.001*3.1536e7; 
t_start = 0*3.1536e7; 
t_end = 10*3.1536e7;    
t = (t_start:dt:t_end);

% Run flowline model with changes
for i=1:length(t)

    % set up figures, plot geometries at t==0, then every t/10 iterations
    if t(i)==t_start
        col = parula(length(t)+10); %Color scheme for plots
        figure(1); clf; % glacier geometry
            hold on; grid on;
            set(gcf,'Position',[0 50 500 400]);
            set(gca,'FontSize',14,'linewidth',2,'fontweight','bold');
            legend('Location','east'); xlim([0 65]); ylim([min(hb)-100 max(h)+100]);
            title('a) Glacier Geometry');
            xlabel('Distance Along Centerline (km)'); ylabel('Elevation (m)');
            % ice surface
            plot(x(1:c)./10^3,h(1:c),'color',col(i,:),'linewidth',2,'displayname','2009');
            % calving front
            plot(x(c)*[1,1]/10^3,[h(c)-H(c),h(c)],'.-','color',col(i,:),'linewidth',2,'HandleVisibility','off');
            % ice end
            plot(x(c+1:ice_end)./10^3,h(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');
            plot(x(c+1:ice_end)./10^3,h(c+1:ice_end)-H(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');
            % floating bed
            plot(x(gl:c)/10^3,h(gl:c)-H(gl:c),'color',col(i,:),'linewidth',2,'HandleVisibility','off');
            % bed elevation
            plot(x/10^3,hb,'k','linewidth',2,'HandleVisibility','off');
            % mean sea level
            plot([x(1),x(end)]/10^3,[0,0],'k--','HandleVisibility','off');
        figure(2); clf % ice speed
            hold on; grid on;
            set(gcf,'Position',[500 50 500 400]);
            set(gca,'FontSize',14,'linewidth',2,'fontweight','bold');
            title('b) Ice Speed Profile');
            xlim([0 65]); ylim([0 max(U(1:ice_end)).*3.1536e7+50]);
            xlabel('Distance Along Centerline (km)'); ylabel('Speed (m yr^{-1})');
            legend('Location','east');
            % 1:c
            plot(x(1:c)./10^3,U(1:c).*3.1536e7,'color',col(i,:),'linewidth',2,'displayname','2009');
            % c:ice_end
            plot(x(c:ice_end)./10^3,U(c:ice_end).*3.1536e7,'--','color',col(i,:),'linewidth',2,'HandleVisibility','off');
        figure(3); clf % terminus position
            hold on; grid on;
            set(gcf,'Position',[1000 50 500 400]);
            set(gca,'FontSize',14,'linewidth',2,'fontweight','bold');
            title('c) Terminus Position'); ylabel('Year');
            xlabel('Distance Along Centerline (km)');
            xlim([42 52]); ylim([2008 2020]); legend('Location','east');
            plot(termx_obs./10^3,termDate_obs,'.-k','markersize',10,'displayname','Observed');
            % 2009 terminus position
            plot(x(c)./10^3,2009,'.','markersize',10,'color',col(i,:),...
                'linewidth',2,'displayname','Modeled');
    elseif mod(i-1,round(length(t)/10))==0
        figure(1); hold on; % Plot geometries every 10 time iterations
            % ice surface
            plot(x(1:c)/10^3,h(1:c),'-','color',col(i,:),'linewidth',2,'displayname',num2str(t(i)./3.1536e7+2009));
            % calving front
            plot(x(c)*[1,1]/10^3,[h(c)-H(c),h(c)],'.-','color',col(i,:),'linewidth',2,'HandleVisibility','off');
            % ice end
            plot(x(c+1:ice_end)./10^3,h(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');
            plot(x(c+1:ice_end)./10^3,h(c+1:ice_end)-H(c+1:ice_end),'--','color',col(i,:),'linewidth',1.5,'HandleVisibility','off');
            % floating bed
            plot(x(gl:c)/10^3,h(gl:c)-H(gl:c),'color',col(i,:),'linewidth',2,'HandleVisibility','off');                       
        figure(2); hold on; % Plot velocity every 10 time iterations
            % 1:c
            plot(x(1:c)/10^3,U(1:c).*3.1536e7,'-','Color',col(i,:),'linewidth',2,'DisplayName',num2str(t(i)./3.1536e7+2009)); hold on;
            % c:ice_end
            plot(x(c:ice_end)./10^3,U(c:ice_end).*3.1536e7,'--','color',col(i,:),'linewidth',2,'HandleVisibility','off');            
        figure(3); hold on; % Plot terminus position every 10 time iterations
            plot(x(c)./10^3,t(i)./3.1536e7+2009,'.','Color',col(i,:),'markersize',15,'linewidth',1.5,'displayname',num2str(t(i)./3.1536e7+2009)); hold on;

    end
    
    % plot results on final time step
    if t(i)==t_end
        h2=h; H2=H; x2=x; c2=c; gl2=gl; % save geometry variables

        figure(4); clf % sensitivity test changes
        hold on; grid on;
        set(gcf,'Position',[350 300 700 600]);
        set(gca,'FontSize',14,'linewidth',2,'fontweight','bold');
        xlabel('Distance Along Centerline (km)'); ylabel('Elevation (m)');
        legend('Location','east'); xlim([0 65]); ylim([-1200 1200]);
        title(['SMR = + ',num2str(round(smr_change.*3.1536e7,1)),'m/a, SMB = + ',...
            num2str(round(smb_change*3.1536e7,1)),'m/a, \Delta L = ',num2str(x2(c2)-x1(c1)),'m']);
        ax1=get(gca);
            % ice surface
            plot(x1(1:c1)/10^3,movmean(h1(1:c1),5),'-k','linewidth',2,'displayname','no change');
            plot(x2(1:c2)/10^3,movmean(h2(1:c2),5),'color',[0.8 0 0],'linewidth',2,'displayname','change');
            % calving front
            plot(x1(c1)*[1,1]/10^3,[h1(c1)-H1(c1),h1(c1)],'-k','linewidth',2,'HandleVisibility','off');
            plot(x2(c2)*[1,1]/10^3,[h2(c2)-H2(c2),h2(c2)],'color',[0.8 0 0],'linewidth',2,'HandleVisibility','off');
            % floating bed
            plot(x1(gl1:c1)/10^3,h1(gl1:c1)-H1(gl1:c1),'-k','linewidth',2,'HandleVisibility','off');
            plot(x2(gl2:c2)/10^3,h2(gl2:c2)-H2(gl2:c2),'color',[0.8 0 0],'linewidth',2,'HandleVisibility','off');
            % bed elevation
            plot(x1/10^3,hb,'k','linewidth',2,'HandleVisibility','off');
        % inset plot of terminus
        ax2 = axes('Position',[0.62 0.62 0.28 0.28]);
            hold on; grid on; set(gca,'linewidth',2,'fontweight','bold');
            title(['\Delta L = ',num2str(x2(c2)-x1(c1)),'m, ','\Delta H_{mean} = ',...
                num2str(round(mean(H2)-mean(H1),1)),' m']);
            xlim([40 50]); ylim([-1000 300]);
            % ice surface
            plot(x1(1:c1)/10^3,h1(1:c1),'-k','linewidth',2,'displayname','no change');
            plot(x2(1:c2)/10^3,h2(1:c2),'color',[0.8 0 0],'linewidth',2,'displayname','no change');
            % calving front
            plot(x1(c1)*[1,1]/10^3,[h1(c1)-H1(c1),h1(c1)],'-k','linewidth',2,'HandleVisibility','off');
            plot(x2(c2)*[1,1]/10^3,[h2(c2)-H2(c2),h2(c2)],'color',[0.8 0 0],'linewidth',2,'HandleVisibility','off');
            % floating bed
            plot(x1(gl1:c1)/10^3,h1(gl1:c1)-H1(gl1:c1),'-k','linewidth',2,'HandleVisibility','off');
            plot(x2(gl2:c2)/10^3,h2(gl2:c2)-H2(gl2:c2),'color',[0.8 0 0],'linewidth',2,'HandleVisibility','off');
            % bed elevation
            plot(x/10^3,hb,'k','linewidth',2,'HandleVisibility','off');
            % mean sea level
            plot([x(1),x(end)]/10^3,[0,0],'k--','HandleVisibility','off');
    end
    
    % calculate the thickness required to remain grounded at each grid cell
    Hf = -(rho_sw./rho_i).*hb; %flotation thickness (m)
    % find the location of the grounding line and use a floating
    % geometry from the grounding line to the calving front
    gl = find(Hf-H>0,1,'first')-1; %grounding line location
    ice_end = find(H<=100,1,'first'); %end of ice-covered domain
    if isempty(ice_end) || ice_end>length(x) || ice_end<c
        ice_end = length(x);
        disp('ice end criteria not met.');
    end

    %calculate the glacier's surface elevation and slope
    h = hb+H; %h = surface elevation (m a.s.l.)
    h(gl:length(x)) = (1-rho_i/rho_sw).*H(gl:length(x)); %adjust the surface elevation of ungrounded ice to account for buoyancy
    dhdx = [(h(2:end)-h(1:end-1))./(x(2:end)-x(1:end-1)) 0]; % surface slope (unitless)

    % find the calving front location (based on Benn et al., 2007 & Nick et al., 2010)
    Rxx = 2*nthroot((dUdx./(E.*A(1:length(dUdx)))),n); %resistive stress (Pa)
    crev = (Rxx./(rho_i.*g))+((rho_fw./rho_i).*fwd); %crevasse penetration depth (m)
    c = find(h(1:ice_end-1)-crev(1:ice_end-1)<=0,1,'first'); %calving front located where the inland-most crevasse intersects sea level
    %if the crevasses never intersect sea level
    if isempty(c) == 1
        c = find(H<Hc,1,'first'); %set the calving front to a default minimum ice thickness value
    end
    if isempty(c)==1
        c=length(x);
        disp('calving criteria not met');
    end
    % if the crevasses first intersect sea level inland of the grounding line
    if c <= gl
        c = gl; %set the grounding line as the calving front
    end
    % use observed terminus position for first time increment
    if i==1
        c=dsearchn(transpose(x),termx_obs(1));
    end

    if any(h<0) % surface cannot go below sea level
        c = find(h<0,1,'first');
        H(c:end) = 0;
        h(c:end)=0;
    end

    %calculate the effective pressure (ice overburden pressure minus water
    %pressure) assuming an easy & open connection between the ocean and
    %ice-bed interface
    sl = find(hb<=0,1,'first'); %find where the glacier base first drops below sea level
    N_ground = rho_i*g*H(1:sl); %effective pressure where the bed is above sea level (Pa)
    N_marine = rho_i*g*H(sl+1:length(x))+(rho_sw*g*hb(sl+1:length(x))); %effective pressure where the bed is below sea level (Pa)
    N = [N_ground N_marine];
    N(N<0)=1; %cannot have negative values

    % Solve for new velocity
    [U,dUdx,vm,T] = U_convergence_varyingE(x,U,U0,dUdx,dhdx,H,A,E,N,W,dx,c,ice_end,n,m,beta,rho_i,rho_sw,g);
    % break if speed is too low
    if mean(U)<=200/3.1536e7
        break;
    end

    % calculate ice flux
    F = U.*H.*W; % ice flux (m^3 s^-1)
    F(isnan(F))=0;

    % calculate the  change in ice thickness from continuity
    dHdt = -(1./W).*gradient(F,x);
    dH = dHdt.*dt;

    % surface mass balance
    clear smb sigma_smb smr % clear to avoid changing size with changing x
        % interpolate smb0 to centerline, add tributary flux Q0 to smb
        smb = interp1(x0,smb0+Q0,x); % m/s
        % add submarine melting rate where ice is ungrounded
        smr(1:gl)= 0; % m/s (zero at grounded ice)
        smr(gl+1:length(x)) = -smr0.*ones(1,length(x(gl+1:end))); % m/s
        % adjust smb to minimize misfit of surface observations
        smb_add = zeros(1,length(x0));
        smb_add = smb_add+0.05e-5;
        smb_add(80:170) = smb_add(80:170)+0.01e-5;
        smb = movmean(interp1(x0,smb0+Q0+smb_add,x),20);
        smb(ice_end+1:end) = 0; % zero smb past the ice_end
        % implement changes
        smb = smb+smb_change; % SMB
        smr(gl+1:end) = smr(gl+1:end)+smr_change; % SMR

    % new thickness (change from dynamics, SMB, & SMR)
    Hn = H+dH+(smb.*dt)+(smr.*dt);
    Hn(Hn < 0) = 0; % remove negative values
    H = Hn; %set as the new thickness value

    % smooth out the points near the ice divide
    H(1:10) = ones(1,length(H(1:10))).*nanmean(H(1:10),'all');

    % thickness & surface past calving front (dummy ice end)
    for j=c-10:length(xi)
        h(j) = h(j-1)-1; % decrease by 5m until at 0m
        H(j) = H(j-1)-10; % decrease by 20m until 0
        if H(j)>=h(j)-hb(j)
            H(j)=h(j)-hb(j); % can't go beneath bed elevation
        end
    end
    h(h<0)=0; % surface can't go below sea level
    H(H<0)=0; % no negative thicknesses

    % stop the model if it behaves unstably (monitored by ice thickness)
    if max(H) > H_max
        disp('Adjust dt');
        break;
    end
    if min(H(1:c)) < H_min
        disp('Too thin! Check A, E, U, beta...');

    end

    % find the precise location of the grounding line (where H=Hf)
    xf = x(find(Hf-H>0,1,'first')-1);

    %adjust the grid spacing so the grounding line is continuously tracked
    xl = round(xf/dx0); %number of ideal grid spaces needed to reach the grounding line
    dx = xf/xl; %new grid spacing (should be ~dx0)
    xn = 0:dx:L; %new distance vector

    %adjust the space-dependent variables to the new distance vector
    hb = interp1(x0,hb0,xn); hb(isnan(hb)) = hb(find(~isnan(hb),1,'last'));
    W = interp1(x0,W0,xn); W(isnan(W)) = W(find(~isnan(W),1,'last'));
    H = interp1(x,H,xn,'linear','extrap'); H(isnan(H)) = H(find(~isnan(H),1,'last')); % ice thickness (m)
    Hf = interp1(x,Hf,xn,'linear','extrap'); Hf(isnan(Hf)) = Hf(find(~isnan(Hf),1,'last'));
    U = interp1(x,U,xn,'linear','extrap'); % speed (m s^-1)
    A = interp1(x0,A0_adj(1,:),x); % rate factor (Pa^-n s^-1)
    beta = interp1(x,beta,xn,'linear','extrap'); % basal roughness factor
    E = interp1(x,E,xn,'linear','extrap'); % enhancement factor (unitless)

    %find the location of the grounding line and end of the ice-covered domain for the adjusted data
    gl = find(Hf-H<0,1,'last');
    ice_end = find(H<=100,1,'first');
    if isempty(ice_end) || ice_end>length(xn) || ice_end<c
        ice_end = length(xn);
        disp('ice end criteria not met.')
    end

    if U(ice_end)==0
        U(ice_end) = U(ice_end-1);
    end

    %rename the distance vector
    x = xn; %distance from the divide (m)

    %calculate the new surface elevation and slope
    h = hb+H; %grounded ice surface elevation (m a.s.l.)
    h(gl:length(x)) = (1-rho_i/rho_sw).*H(gl:length(x)); %floating ice surface elevation (m a.s.l.)
    dhdx = [(h(2:end)-h(1:end-1))./(x(2:end)-x(1:end-1)) 0]; % surface slope (unitless)

    H(H>=(h-hb))=h(H>=(h-hb))-hb(H>=(h-hb)); % thickness can't go beneath bed elevation

    % calculate new strain rate
    dUdx = [(U(2:end)-U(1:end-1))./(x(2:end)-x(1:end-1)) 0]; % strain rate

    % find the calving front location (based on Benn et al., 2007 & Nick et al., 2010)
    Rxx = 2*nthroot((dUdx./(E.*A(1:length(dUdx)))),n); %resistive stress (Pa)
    crev = (Rxx./(rho_i.*g))+((rho_fw./rho_i).*fwd); %crevasse penetration depth (m)
    c = find(h(1:ice_end-1)-crev(1:ice_end-1)<=0,1,'first'); %calving front located where the inland-most crevasse intersects sea level
    %if the crevasses never intersect sea level
    if isempty(c) == 1
        c = find(H<Hc,1,'first'); %set the calving front to a default minimum ice thickness value
    end
    if isempty(c)==1
        c=length(x);
        disp('calving criteria not met');
    end
    % if the crevasses first intersect sea level inland of the grounding line
    if c <= gl
        c = gl; %set the grounding line as the calving front
    end
    % use observed terminus position for first time increment
    if i==1
        c=dsearchn(transpose(x),termx_obs(1));
    end

    if any(h<0) % surface cannot go below sea level
        c = find(h<0,1,'first');
        H(c:end) = 0;
        h(c:end)=0;
    end

end

cd([homepath,'scripts/100yrScenario']);
if save_figure && ishandle(4)
    % Save figure for test
    figName = ['SMR',num2str(smr_change),'_SMB',num2str(smb_change)];
    saveas(gcf,[figName,'.png'],'png');
    saveas(gcf,[figName,'.fig'],'fig');
    disp(['Fig. 4 saved (.png & .fig) in: ',pwd]);
elseif ~ishandle(4)
    disp('figure does not exist.');
else
    disp('no figure saved.');
end



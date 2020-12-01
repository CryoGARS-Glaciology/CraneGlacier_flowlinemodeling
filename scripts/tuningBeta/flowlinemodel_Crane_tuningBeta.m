function [t,XC,x0,hb0] = flowlinemodel_Crane_tuningBeta

clear all; close all;
warning off; % turn off warnings (velocity coefficient matrix is close to singular)

%% define time and space independent variables
    
dx0 = 5000; % desired grid spacing (m)
            % Stress-coupling Length (SCL) =~ 5km
use_binavg = 1;     % = 1 to use average within bins proportional to dx0
use_u_lin = 0;      % = 1 y/n to use a linear trendline for the velocity
save_figure = 1;    % = 1 to save figure of resistive stresses
poly_solve = 1;     % = 1 to solve for the best polynomial degree fit for beta
plotStresses = 0; % = 1 to solve for and plot the finalresistive stresses

% define home path in directory
homepath = '/Users/raineyaberle/Desktop/Research/CraneGlacier_modeling/';
cd([homepath,'inputs-outputs']);

% add paths to required matlab functions
addpath('/Users/raineyaberle/Desktop/Research/matlabFunctions');
addpath([homepath,'scripts/tuningbeta']);

    % Load 2009 terminus position (m along centerline)
    centerline = load('LarsenB_centerline.mat').centerline;
    termx = centerline.termx(5); termy = centerline.termy(5); % row 5 = 2009
        x_cl = load('Crane_centerline.mat').x; 
        y_cl = load('Crane_centerline.mat').y;
    
        % Search for the index of the coordinate closest to the terminus location
        term = dsearchn([x_cl y_cl],[termx termy]); 
        
    % densities and g
    rho_i = 917; % ice density (kg m^-3)
    rho_sw = 1028; % ocean water density (kg m^-3)
    rho_fw = 1000; % fresh water density (kg m^-3)
    g = 9.81; % acceleration (m s^-2)
        
    % time stepping (s)
    dt = 0.5*3.1536e7; 
    t_start = 0*3.1536e7; 
    t_end = 1*3.1536e7;    
    t = (t_start:dt:t_end);

    % glacier geometry initialisation
    % initial grid spacing vectors x and dx (m)
        x0 = zeros(1,term);
        for i=2:length(x_cl)
            x0(i) = sqrt((x_cl(i)-x_cl(i-1))^2+(y_cl(i)-y_cl(i-1))^2)+x0(i-1);
        end
        x0 = transpose(x0); % make a row vector
        x = x0(1:term);
        dx = dx0; 
    % bed elevation (m)
        OIBPicks.hb = load('Crane_OIBPicks_2018.mat').CraneOIBPicks_2018_full.hb_geoid;
        OIBPicks.X = load('Crane_OIBPicks_2018.mat').CraneOIBPicks_2018_full.Easting;
        OIBPicks.Y = load('Crane_OIBPicks_2018.mat').CraneOIBPicks_2018_full.Northing;
        hb0 = interp1(OIBPicks.Y,OIBPicks.hb,y_cl);
            hb0(1:6) = hb0(7).*ones(6,1); hb=hb0(1:term); 
    % surface elevation (m)
        h_obs = load('Crane_SurfaceObservations_2009-2018.mat').h;
        h0 = h_obs(3).surface(1:term); % 2011 OIB ice surface 
        h=h0;
    % width (m)
        W0 = load('Crane_CalculatedWidth.mat').width.W;
        W = W0(1:term);
    % thickness (m)
        H0 = h-transpose(hb(1:length(h)));
        H = H0;
        
    % surface mass balance 
    smb0 = load('Crane_downscaledSMB_2009-2016.mat').SMB(3).smb_linear; % 2011 SMB (m/yr)
    smb0_err = load('Crane_downscaledSMB_2009-2016.mat').SMB(3).sigma_smb; % (m/yr)
        % tributary fluxes
        Q = transpose(load('TributaryFlux.mat').tribFlux.Q); % (m/yr)
        Q_err = transpose(load('TributaryFlux.mat').tribFlux.Q_err); % (m/yr)
            Q = Q./3.1536e7; % m/s
            Q_err = Q_err./3.1536e7; % m/s
        Q_x = transpose(load('TributaryFlux.mat').tribFlux.x);
        % interpolate to centerline
        Q = interp1(Q_x,Q,x0);
        Q_err = interp1(Q_x,Q_err,x0);
        % add tributary flux to smb
        smb = smb0+Q(1:length(smb0));
        smb_err = transpose(smb0_err)+Q_err(1:length(smb0_err)); 
        
    % stress parameters (unitless)
        m = 1; % basal sliding exponent
        n = 3; % flow law exponent
        E = 1; % enhancement factor
    % rate factor (Pa^-3 s^-1)
        A0 = load('Crane_RateFactor.mat').A; % rate factor (Pa^-n s^-1)
        A=A0;    
    %  ice speed (m/s)
        %Use a smoothing spline fit function to interpolate U along centerline
        %where data do not exist
        u = load('Crane_CenterlineSpeeds_2009-2017.mat').u; 
        U0 = u(3).speed; % 2011 speed (m s^-1)
        
        % Align index / coordinates for U profile            
        U0 = fit(y_cl(~isnan(U0)),U0(~isnan(U0)),'linearinterp'); 
        U0 = feval(U0,y_cl); 
       
        % Use a linear trendline for velocity (optional)
        if use_u_lin==1
            U = polyval(polyfit(x,U0(1:term),1),x); 
        else 
            U=U0;
        end 
        
% regrid the initialization data using the interp1 function to match the desired grid spacing
    x_i = x; % rename initialization distance vector
    L = x(term); % length of glacier (m)
    x = 0:dx0:L; % desired distance vector (m from ice divide)
    h = interp1(x_i,h,x,'linear','extrap');
    hb = interp1(x_i,hb,x,'linear','extrap');
    W = interp1(x_i,W(1:term),x,'linear','extrap');
    U = interp1(x_i,U(1:term),x,'linear','extrap');
    A = interp1(x_i,A(1:term),x,'linear','extrap');
    SMB0 = interp1(x_i,smb(1:term),x,'linear','extrap');
    dUdx = (U(2:end)-U(1:end-1))./(x(2:end)-x(1:end-1));
        dUdx = [0,dUdx];
    
    beta = zeros(length(t),length(x)); % (s^{1/m} m^{-1/m})
    
    clear x_cl y_cl
    
% Use a staggered grid to calculate averages within bins
    if use_binavg
        xm = (x(1:end-1)+x(2:end))./2;
        for k=1:length(x)
            if k==1
              h(k) = mean(h0(1:dsearchn(x0,xm(k))));
              hb(k) = mean(hb0(1:dsearchn(x0,xm(k))));
              W(k) = mean(W0(1:dsearchn(x0,xm(k))));
              U(k) = mean(U0(1:dsearchn(x0,xm(k))));
              A(k) = mean(A0(1:dsearchn(x0,xm(k))));
              SMB0(k) = mean(smb0(1:dsearchn(x0,xm(k)))); 
            elseif k==length(x)
              h(k) = mean(h0(dsearchn(x0,xm(k-1)):term));
              hb(k) = mean(hb0(dsearchn(x0,xm(k-1)):term));
              W(k) = mean(W0(dsearchn(x0,xm(k-1)):term));
              U(k) = mean(U0(dsearchn(x0,xm(k-1)):term));
              A(k) = mean(A0(dsearchn(x0,xm(k-1)):term));
              SMB0(k) = mean(smb0(dsearchn(x0,xm(k-1)):term));
            else
              h(k) = mean(h0(dsearchn(x0,xm(k-1)):dsearchn(x0,xm(k))));
              hb(k) = mean(hb0(dsearchn(x0,xm(k-1)):dsearchn(x0,xm(k))));
              W(k) = mean(W0(dsearchn(x0,xm(k-1)):dsearchn(x0,xm(k))));
              U(k) = mean(U0(dsearchn(x0,xm(k-1)):dsearchn(x0,xm(k))));
              A(k) = mean(A0(dsearchn(x0,xm(k-1)):dsearchn(x0,xm(k))));
              SMB0(k) = mean(smb0(dsearchn(x0,xm(k-1)):dsearchn(x0,xm(k))));
            end
        end 
        H = h-hb;
    end 
   
    SMB=SMB0;
    
    % Solve for faf at the calving frontx
    faf = H(end)*rho_i/(-hb(end)*rho_sw);
    disp(['FAF = ',num2str(faf)]);

%% Run the flowline model   

    XC=zeros(1,length(t)); % pre-allocate

for i=1:length(t)
    
    % find the calving front location
    if i==1
        xcf = term;
    else
        xcf = find(-faf*rho_sw.*hb(1:length(x))/rho_i-H>0,1,'first');
    end 
    
    % if calving front criteria unmet, use previous calving front location
    % and display error
    if isempty(xcf)
        XC(i) = XC(i-1);
        disp(['t = ',num2str(t(i)./3.1536e7),' yrs did not meet calving criteria.']);
    else
        XC(i) = xcf;
    end
    
    % set up figures
    if t(i)==t_start
        col = parula(length(t)+12); %Color scheme for plots
        figure; % fig1 = glacier geometry
            set(gcf,'Position',[0 100 500 400]);
            set(gca,'FontSize',14,'FontName','Arial'); grid on;
            legend; xlim([0 60]); ylim([min(hb)-100 max(h)+100]);
            xlabel('Distance Along Centerline (km)'); ylabel('Elevation (m)'); 
            hold on; grid on;
            plot(x(end)*[1,1]/10^3,[hb(end),h(end)],'.-','color',col(i,:),'linewidth',2,'HandleVisibility','off');
            plot(x/10^3,hb,'k','linewidth',2,'HandleVisibility','off'); 
            plot([x(end),x0(end)]/10^3,[0,0],'k--','displayname','Mean Sea Level','HandleVisibility','off'); 
        figure; % fig2 = ice speed
            hold on; grid on; set(gcf,'Position',[500 100 500 400]);
            set(gca,'FontSize',14,'FontName','Arial'); grid on;
            xlabel('Distance Along Centerline (km)'); ylabel('Speed (m yr^-^1)'); 
            legend('Location','northwest'); title('Ice Speed Profile');
        figure; % fig3 = beta results
            hold on; grid on; set(gcf,'Position',[1000 100 500 400]);
            set(gca,'FontSize',14,'FontName','Arial'); grid on;
            xlabel('Distance Along Centerline (km)'); ylabel('\beta (s^{1/m} m^{-1/m})'); 
            legend('Location','northwest'); title('Basal roughness factor');
        if plotStresses==1
            figure; % fig4 = stress balance equations
                hold on; set(gcf,'Position',[150 600 500 400]);
                set(gca,'FontSize',14,'FontName','Arial'); grid on;
                xlabel('Distance Along Centerline (km)'); 
                legend('Location','northeast'); title('Stress Balance Variables');
            figure; % fig5 = basal resistance and driving stress
                set(gcf,'Position',[700 600 700 600]);
        end 
    end 

    % calculate ice flux
    F = U.*H.*W; % ice flux (m^3 s^-1)
    
    % change in thickness term
    c = length(x);
    ice_end = c-1; 
    clearvars dHdt
    dHdt(1) = (-1/W(1))*(F(2)-F(1))/(x(2)-x(1)) + SMB(1);
    dHdt(2:c-1) = (-1./W(2:c-1)).*(F(3:c)-F(1:c-2))./(x(3:c)-x(1:c-2)) + SMB(2:c-1);
    dHdt(c) = (-1/W(c))*(F(c)-F(ice_end))/(x(c)-x(ice_end)) + SMB(c);
    
    dHdt = zeros(1,c);
    
    % new thickness and surface
    H = H + dHdt*dt;
    h = hb+H;
 
    %calculate the effective pressure (ice overburden pressure minus water
    %pressure) assuming an easy & open connection between the ocean and
    %ice-bed interface
    sl = find(hb<=0,1,'first'); %find where the glacier base first drops below sea level
    N_ground = rho_i*g*H(1:sl); %effective pressure where the bed is above sea level (Pa)
    N_marine = rho_i*g*H(sl+1:length(x))+(rho_sw*g*hb(sl+1:length(x))); %effective pressure where the bed is below sea level (Pa)
    N = [N_ground N_marine];
    N(N<0)=1; %cannot have negative values

    % Solve for new beta
    [beta,U,vm,T,dUdx] = betaSolve(x,h,rho_i,g,m,n,A,H,W,dx,c,ice_end,N,i,U0,x0,t,beta,E,rho_sw,plotStresses);  
    
    % Plot geometries for every 10 time iterations
        figure(1)
        if mod(i-1,round(length(t)/10))==0
            plot(x/10^3,h,'-','color',col(i,:),'linewidth',2,'displayname',['yr ',num2str(t(i)./3.1536e7)]); 
            plot([x(c)/10^3 x(c)/10^3],[h(c) hb(c)],'-','color',col(i,:),'linewidth',2,'HandleVisibility','off'); 
        else 
            plot(x/10^3,h,'-','color',col(i,:),'linewidth',2,'HandleVisibility','off'); 
            plot([x(c)/10^3 x(c)/10^3],[h(c) hb(c)],'-','color',col(i,:),'linewidth',2,'HandleVisibility','off'); 
        end 
        title(['time = ',num2str(t(i)/(3.1536e7)),' yrs']);    
    % Plot velocity
        figure(2)
        if mod(i-1,round(length(t)/10))==0
            plot(x/10^3,U.*3.1536e7,'-','Color',col(i,:),'linewidth',2,'DisplayName',['yr ',num2str(t(i)./3.1536e7)]); hold on;
        else 
            plot(x/10^3,U.*3.1536e7,'-','Color',col(i,:),'linewidth',2,'HandleVisibility','off'); hold on;           
        end 
        
    % Plot resulting beta
        figure(3)
        if mod(i-1,round(length(t)/10))==0
            plot(x(1:c)./10^3,beta(i,1:c),'-','Color',col(i,:),'linewidth',2,'DisplayName',['yr ',num2str(t(i)./3.1536e7)]); hold on;
        else
            plot(x(1:c)./10^3,beta(i,1:c),'-','Color',col(i,:),'linewidth',2,'HandleVisibility','off'); hold on;
        end 
        ylim([min(beta(i,:)) max(beta(i,:))]);
        
    % Calculate resistive and driving stresses
        % Eqn. (2) in Flowline Model User Guide (Enderlin, 2013)
    if plotStresses==1 && t(i)==t(end)

        % Calculate basal resistance
            Rb = -beta(i,:).*N.*(U.^(1/m)); 
            
        % Calculate longitudinal and lateral stresses (Pa)
        Rlon_piece = zeros(1,length(x)); R_lat = zeros(1,length(x)); 
        for k=1:length(x)
            Rlon_piece(k) = H(k)*vm(k)*dUdx(k); % Calculate inner matrix before taking gradient
            Rlat(k) = -2*H(k)/W(k)*((5*U(k)/(E*A(k)*W(k)))^(1/n));
        end 
            % Use a forward difference to calculate d/dx(R_lon_piece)
            Rlon = zeros(1,length(x));
            for k=1:length(x)
                if k==length(x)
                    Rlon(k) = NaN;
                else
                    Rlon(k) = (Rlon_piece(k+1)-Rlon_piece(k))/(x(k+1)-x(k));
                end 
            end
            
        % Calculate total resistive stress
        R_tot = Rb+Rlon+Rlat; 
        
        % Plot results onto figure 5
        figure(5); clf
        subplot(3,2,1); 
        hold on;
        plot(x/10^3,Rb,'-b','linewidth',2,'displayname','BR');
        grid on; set(gca,'FontSize',12,'fontname','Arial');        
        title('R_{basal}'); ylabel('(Pa)');
        
        subplot(3,2,2); 
        hold on; 
        plot(x/10^3,T,'-b','linewidth',2);
        title('T_d');
        grid on; set(gca,'FontSize',12,'fontname','Arial');
        
        subplot(3,2,3); 
        hold on; 
        plot(x/10^3,Rlon,'-b','linewidth',2);
        title('R_{longitudinal}'); ylabel('(Pa)');
        grid on; set(gca,'FontSize',12,'fontname','Arial');
        
        subplot(3,2,4); 
        hold on; 
        plot(x/10^3,Rlat,'-b','linewidth',2);
        title('R_{lateral}');
        grid on; set(gca,'FontSize',12,'fontname','Arial');
        
        subplot(3,2,[5 6]);
        hold on; 
        plot(x/10^3,R_tot,'-m','linewidth',2,'displayname','R_tot');
        title('R_{total}'); 
        grid on; set(gca,'FontSize',12,'fontname','Arial');
        xlabel('Distance Along Centerline (km)'); ylabel('(Pa)');
        
        % Save figure
        if save_figure
            saveas(gcf,'ResistiveStresses.png','png');
            disp('Figure 5 saved');
        end 
    end 
    
        % Solve for the best polynomial fit of beta using cross-validation
        if poly_solve==1 && t(i)==t(end)
            deg = [0:4]; % polynomial degrees
            nMC=length(x); % number of Monte-Carlo simulations
            pTrain=0.9; % percentage of points to use as training data 
            replace=0; % do not replace values in MC simulations
            
            % Input into bestPolyFit function
            [RMSE,bestPoly] = bestPolyFit(x(1:end-1),beta(i,1:end-1),pTrain,deg,nMC,replace);
            betaFit = polyfit(x(1:end-1),beta(i,1:end-1),bestPoly);
            if betaFit(2)<0
                betaFit(2)=0;
            end
            betaFit = polyval(betaFit,x0);
            
            % Plot results        
            figure(3);
                plot(x0./10^3,betaFit,'-m',...
                    'linewidth',2,'displayname',...
                    ['best poly fit = ',num2str(bestPoly)]);
             disp(['Lowest RMSE = ',num2str(RMSE(deg==bestPoly)),'']);
                 disp([' (for ',num2str(bestPoly),' degree polynomial)']);
                        
        end 
      
end 

end
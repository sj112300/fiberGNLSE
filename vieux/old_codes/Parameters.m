function [sim,pump,fibre]=Parameters


%% simulation parameters
sim.option= 0;          % [0] only output [1] inner fibre spectral, [2] spectral+temporal

sim.c = 299792.458;                         % [nm/ps] speed of light
sim.nt= 2^12;                                   % number of spectral points
sim.time= 16;                                   % [ps] simulation window
sim.dz= 0.00000005;                    % [km] longitudinal step


%% Input pulses (pump)
pump.tfwhm= 31; % [fs] pulse width @FWHM
pump.tfwhm= pump.tfwhm* 1e-3; % ->[ps]
pump.lambda= 830; % [nm] 
pump.rate= 94E6; % [Hz]
pump.chirping= 0;             % unchirped

% to= pump.tfwhm/ 1.763;
% pump.w= sim.c/ pump.lambda;                   % [THz] frequency of the pulse, given to the SSFM.


%% Fiber Parameters
fibre.zdw= 790;                               % [nm] fiber zero dispersion wavelength
fibre.wzdw= 2* pi* sim.c/ fibre.zdw;	% [THz] central simulation frequency

fibre.gamma_zdw = 78;              % [w^-1* km^-1]
fibre.gamma= fibre.gamma_zdw* pump.lambda/ fibre.zdw;

fibre.L = 0.00075;                         % [km] fibre length


%% Numerical simulation calculations
sim.aux= -(sim.nt/2): (sim.nt/ 2- 1);
sim.dt= sim.time/ sim.nt;	% [ps] time step
sim.t= sim.dt* sim.aux; % [ps] time vector
sim.df= 1/ sim.time;	% [THz] frequency step
sim.f= sim.df* sim.aux;	% [THz] frequencies vector
sim.ws= 2* pi* sim.f;	% [radE12/s] angular frequencies
sim.wcent= sim.ws+ fibre.wzdw;  % [radE12/s] zdw centred angular frequencies
sim.lambdas= (2* pi*sim.c./ sim.wcent)';   % [nm] centred lambdas vector


%% fiber dispersion (interpolates beta(w)M1? data into sim.ws)
% %{
load('/home/vbettachini/documents/Fiber/simulacion/LEC_simul/pcf_data/beta_w');	% [1/ps 1/km]
beta_fibreLEC= beta_w(:,2);
w_fibreLEC= beta_w(:,1);
fibre.betap = interp1(w_fibreLEC, beta_fibreLEC, sim.wcent, 'spline', 'extrap');
% plot(sim.wcent, fibre.betap, '.-r', beta_w(:,1), beta_w(:,2), '*b');  % beta check
% %}


%% fiber dispersion (fit to 4 M1 provided beta2(w) )
% fibre.betap= beta_w_LECshifted(pump.lambda, sim.wcent);


%% fiber dispersion as beta polynomial (datasheet PCF)
%{
fibre.name= 'beta2y3 LEC';
fibre.beta2= 0;              % D @ZDW=0 -> fibre.beta2= 0
fibre.beta3= 0.0703;         % dD_lamb datasheet -> fibre.beta3 [ps nm^-2 km^-1]
fibre.betap= [0 0 fibre.beta2 fibre.beta3];
%}


%% fibre dispersion plot
%{
load('/home/vbettachini/documents/Fiber/simulacion/LEC_simul/pcf_data/beta_w');            % [1/ps 1/km]
figure(323)
plot(sim.wcent, fibre.betap, '.-r', beta_w(:,1), beta_w(:,2), '-b');
legend('shifted', 'Andres', 'Location', 'SouthEast');
xlabel('\omega [rad/ps]','FontSize',18,'FontName','Times');
ylabel('\beta [1/km]','FontSize',18,'FontName','Times');
grid on;
% print('-depsc', '-r600', strcat(results_path, sim.name, 'beta', '.eps' ) );   % save spectrum as eps
% print('-depsc', '-r600', strcat(results_path, sim.name, 'beta', '.pdf' ) );   % save spectrum as pdf
%}


%% fiber attenuation
fibre.alpha= 0;
% fibre.alpha= 11.22;               % 10.5 dB/km @1550 nm -> 11.22 1/km

%{
% interpolates fibre.alpha(sim.lambdas) in omegas of simulation
load alpha_lec;         % [nm dB/km]
% plot(alpha_lec(:,1), alpha_lec(:,2), '.-r');
alpha_w= 2* pi *simulation.c./ alpha_lec(:,1);                 % ->[1/ps]
alpha_att= 10.^(alpha_lec(:,2)./ 10);                 % ->[1/km]
fibre.alpha= interp1(alpha_w, alpha_att, sim.wcent, 'cubic', 0);
% plot(sim.wcent, fibre.alpha, '.-r', alpha_w, alpha_att, '*b');
%}


%% INPUT FIELD ************************************************************
sim.deltaw= fibre.wzdw- 2* pi* sim.c/ pump.lambda;
[aux1a,aux1b] = min( abs (sim.ws - sim.deltaw) );
pump.u0 = sech(sim.t/ pump.tfwhm).* exp(-1i* sim.ws(aux1b)* sim.t);     % [w^0.5] pump shape

% input pulse shape
pump.ShapeFactor= 0.88;     % sech2

% %{
% Mean -> Peak power
% pump.Pmean= 100E-3;         % [w] -> L=0.01, shift: >500 nm
% pump.Pmean= 50E-3;         % [w] -> L=0.01, shift: 500 nm
% pump.Pmean= 30E-3;         % [w] -> L=0.01, shift-> 1884 nm
pump.Pmean= 3E-3;         % [w] -> L=0.01, no soliton
% pump.Pmean= 200E-3;         % [w] -> L=0.01, no soliton
pump.Ppeak= pump.Pmean/( pump.tfwhm* 1E-12* pump.rate* pump.ShapeFactor);         % [w]
% %}

% TELCO 1ps
% 1Gbit/s, 500mW input, sech2 -> pump.Ppeak= 500E-3/ (0.88* 1E-12* 1E9);
% pump.Ppeak= 500E-3/ (0.88* 1E-12* 1E9);        % [w] (unos 570 w)
% pump.Ppeak= 1E6;

%{
% TELCO as LEC test
pump.Ppeak= 1E3;           % [w]
pump.Pmean= pump.Ppeak* ( pump.tfwhm* 1E-12* pump.rate* pump.ShapeFactor);         % [w]
%}

% pump power -> amplitude
pump.u0 = sqrt(pump.Ppeak)* pump.u0;                 % [w^0.5]

%{
% mean input pulse power
pump.ShapeFactor= 0.88;     % sech2
E_pulse_in= pump.Ppeak* pump.tfwhm* 1E-12/ pump.ShapeFactor; % [j]
pump.Pmean= pump.rate* E_pulse_in* 1E3;            % [mW]
%}

% chirp
% pump.chirping= 0.007400;             % chirp= 7400fs^2
% pump.u0 = ifft(fft(pump.u0).*exp(1i* 0.5* (-pump.chirping)* fftshift(sim.ws).^2) ); % [w^0.5]

%{
% Total input pulse energy
Pul_Et0= pump.u0.* conj(pump.u0);
Pul_Et0= sim.dt *sum(Pul_Et0);
%}
%{
% input pulse spectrum
figure(75)
inp= fft(pump.u0);
inp= fftshift(inp);
inp= inp.* conj(inp);
inp= inp./ max(inp);
plot(sim.lambdas, inp);
xlim([sim.lambdas(simulation.nt) sim.lambdas(1)]);
xlabel('\lambda [nm]','FontSize',18,'FontName','Times');
ylabel ('Normalised Spectrum (a.u.)','FontSize',18,'FontName','Times');
%}




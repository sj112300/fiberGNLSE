clear all
close all

addpath('~/documents/Fiber/simulacion/aux_codes/');
results_path= ('~/documents/Fiber/simulacion/neu/results/');
% cd(results_path);    % save path

format long e
fprintf(1,'\n\n\n----------------------------------------------');
fprintf(1,'\nSimulating Soliton Propagation in PCF');


%% simulation parameters
option= 0;          % [0] only output [1] inner fibre spectral, [2] spectral+temporal

img_name= CurrDateFile_seq(results_path); % output filename

sim.c = 299792.458;                         % [nm/ps] speed of light
sim.nt= 2^12;                                   % number of spectral points
sim.time= 16;                                   % [ps] simulation window
sim.dz= 0.00000005;                    % [km] longitudinal step


%% Input pulses (pump)
pump.tfwhm= 31; % [fs] pulse width @FWHM
pump.tfwhm= pump.tfwhm* 1e-3; % ->[ps]
pump.lambda= 830; % [nm] 
pump.rate= 94E6; % [Hz]

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
% print('-depsc', '-r600', strcat(results_path, img_name, 'beta', '.eps' ) );   % save spectrum as eps
% print('-depsc', '-r600', strcat(results_path, img_name, 'beta', '.pdf' ) );   % save spectrum as pdf
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
chirping= 0;             % unchirped
% chirping= 0.007400;             % chirp= 7400fs^2
% pump.u0 = ifft(fft(pump.u0).*exp(1i* 0.5* (-chirping)* fftshift(sim.ws).^2) ); % [w^0.5]

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


%% save m file as backup [no anda en R2011a]

%{ 
es = com.mathworks.mlservices.MLEditorServices;
ad = char(es.builtinGetActiveDocument);
javaMethod('saveDocument',es,ad);
copyfile(ad,[img_name,'.m']);
%}



%% ssfm run
% tstart= tic;
tic();
tol= 1e-8;                          % tolerance

% option graba pasos intermedios en el tiempo
[u1, distances, out_spect, shapes_time, nf]= IP_CQEM_FD_struct(pump.u0,sim.dt,fibre.L,sim.dz,fibre.alpha,fibre.betap,fibre.gamma,sim.wzdw,sim.wzdw,tol,option);
spects= shapes_time.spects; 

telapsed= toc();
%{
% Total output pulse energy
Pul_Et1= u1.* conj(u1);
Pul_Et1= dt *sum(Pul_Et1);
%}


%% saves data for latter manual filtering
save( strcat(results_path, img_name) );      % saves .mat


%% Spectra at each step plot

plot_lambda_range(1)= pump.lambda- 200;
plot_lambda_range(2)= pump.lambda+ 200;

% %{
if (option==1)
    spect_pow= spects.* conj(spects);
    % spect_pow= spect_pow/ simulation.nt;                % ->[w] fft normalisation (sqrt(N) for each fft)
    noise = max(max(spect_pow ) )/ 10000;
    mesh_in_time = 10*log10(1000*(spect_pow+ noise));   % ->[dB]

    dist_axis= distances* 1e5;
    lambda_lin= linspace(min(sim.lambdas), max(sim.lambdas), round(max(sim.lambdas )- min(sim.lambdas) ) )';
    y_lin= linspace(min(dist_axis ), max(dist_axis ), 2* size(dist_axis, 1 ) )';
    [X, Y ]= meshgrid(lambda_lin, y_lin );
    Z= griddata(sim.lambdas, dist_axis, mesh_in_time, X, Y, 'cubic' );

    % ensayo fallido NO BORRAR, algun dia...
    %{
    auxMat=[];
    lambda_aux= [];
    for i=1:size(dist_axis,1);
        auxMat= [auxMat mesh_in_time(((i-1)*size(sim.lambdas, 1)+ 1): i*size(sim.lambdas, 1) ) ];
        lambda_aux= [lambda_aux;sim.lambdas ];
        dist_axis_aux((i-1)*size(sim.lambdas, 1)+ 1: i*size(sim.lambdas, 1))=  dist_axis(i);
    end
    auxMat= auxMat';
    cosa= TriScatteredInterp(lambda_aux, dist_axis_aux', auxMat);
    qz= cosa(X, Y);
    figure(668)
    mesh(X, Y, qz);
    %}

    figure(666)
    imagesc(lambda_lin, y_lin, Z);
    % axis([500 1200 0 L*1e5]);     % twice lenght fibre
    axis([plot_lambda_range, [0 fibre.L* 1e5] ]);     % twice lenght fibre
    % set(gca,'YDir','normal');      % 0 length at bottom

    xlabel('\lambda [nm]','FontSize',18,'FontName','Times');
    ylabel('Length [cm]','FontSize',18,'FontName','Times');
    print('-depsc', '-r600', strcat(results_path, img_name, 'map', '.eps' ) );   % eps
    % print('-depsc', '-r600', strcat(results_path, img_name, 'map','.pdf') );   % pdf
end
% %}


%% Outupt spectrum ************************************************************
fprintf(1,'\n\nPloting Results');
specN= out_spect.* conj(out_spect);
%{
% Total output pulse energy (frequency) -> No funciona, si da la suma sin sim.df/dt
specN= specN./ size(out_spec,2);                % ->[w] fft normalisation (sqrt(N) for each fft)
Pul_Ef= sim.df *sum(out_spec);
 plot(sim.lambdas,specN./ 1e3,'b.-')           % ->[kW]?
%}

specN = specN/ max(specN);        % normalised spectra to higher peak power
spec_ylabel= 'Normalised Spectrum (a.u.)';
% spec_ylabel= 'Power [kW]';  % if no normalisation performed

% plot
figure(662)
plot(sim.lambdas,specN,'b.-');
grid on;
xlabel('\lambda [nm]','FontSize',18,'FontName','Times');
ylabel (spec_ylabel,'FontSize',18,'FontName','Times');
xlim(plot_lambda_range);

% on graph input pulse data
str1(1)= strcat({'fibre: '}, fibre.name);
str1(2)= strcat({'L= '}, num2str(fibre.L*1E3,'%3.2f'), 'm');
str1(3)= strcat({'ZDW= '}, num2str(fibre.zdw,'%3.0f'), 'nm');
str1(4)= {'Pump shape: sech2'};
str1(5)= strcat({'\lambda_0= '}, num2str(pump.lambda), ' nm');
str1(6)= strcat({'\Deltat= '}, num2str(pump.tfwhm* 1e3), ' fs  (FWHM)');
str1(7)= strcat({'chirp= '}, num2str(chirping* 1e6, '%3.1f'), ' fs^2');
str1(8)= strcat({'P peak= '}, num2str(pump.Ppeak,'%3.1f'), ' w');
str1(9)= strcat({'P mean= '}, num2str(pump.Pmean *1E3, '%3.1f'), ' mW');
text_x_pos= plot_lambda_range(1)+ 0.05*(plot_lambda_range(2)- plot_lambda_range(1) );
y_pos= ylim;
text_y_pos= 0.7* y_pos(2);
txt_spr_hnld= text(text_x_pos, text_y_pos, str1);

% test octave
%{
str1a= strcat('fibre: ', fibre.name, '\n');
str1a= strcat(str1a, 'input shape: sech2', '\n');
txt_spr_hnld= text(plot_lambda_range(1), 0.75, str1a);
%}

% saves output spectrum
print(662,'-depsc', '-r600', strcat(results_path, img_name, 'sp', '.eps' ) );   % save spectrum as eps
% print('-depsc', '-r600', strcat(img_name, 'sp', '.pdf' ) );   % save spectrum as pdf
% saveas(gcf, img_name, 'fig');     % save spectrum as fig


fprintf(1,'\n\n----------------------------------------------');
fprintf(1,'\n');



% PONER UNA ESPERA (???) O IMPLEMENTAR ALGO TIPO CORTA-TRANSFORMA
% (AUX_CODES)


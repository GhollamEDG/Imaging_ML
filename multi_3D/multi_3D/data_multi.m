%%
close all;
clc; clear;

addpath('../function');

%% Parameters
Rs = 5e5;   % USRP sampling rate 
f_pu = 0;
USRP_setup_delay = 6;
ls_wait = 8;

%% file
date_ref = '1009';      % reference of experiment date
obj_ref = '20';
run_ref = 1;

command = sprintf('mkdir ~/Jayden/Imaging_ML/data/%s',date_ref);
system(command);
file_addr = sprintf('~/Jayden/Imaging_ML/data/%s/o%s_r%d',date_ref,obj_ref,run_ref);
command = ['mkdir ',file_addr];
system(command);

%%
% ls_pos = ls_pos_log('initiate',x_ls_rng_h,0,wv_len_half);
% ls_pos = ls_pos_log('initiate',0,0,wv_len_half);

%% Linear stage
x_ls_port = 0;
z_ls_port = 1;

x_ls_rng = 150;
z_ls_rng = 150;
x_ls_rng_h = floor(x_ls_rng/2);
z_ls_rng_h = floor(z_ls_rng/2);

scan_mode = 'cross'; % rect or cross
% scan_mode = 'rect'; % rect or cross

rect_stg = struct('Num',4,'x_stp',[x_ls_rng,0,-x_ls_rng,0],'z_stp',[0,z_ls_rng,0,-z_ls_rng]);
cross_stg = struct('Num',6,'x_stp',[0,-x_ls_rng_h,0,x_ls_rng,0,-x_ls_rng_h],'z_stp',[z_ls_rng,0,-z_ls_rng_h,0,-z_ls_rng_h,0]);

x_ls_pos = 0;
z_ls_pos = 0;

wv_len_half = 3e8/(60e9);
ls_pos = ls_pos_log('read',0,0,wv_len_half);

%%
if strcmp(scan_mode,'rect')
    scan_stg = rect_stg;
    if (ls_pos.x ~= 0)|(ls_pos.z ~= 0)
        error('Error. \nInvalid initial position')
    end
    fprintf('Ready for rect scan\n');
elseif strcmp(scan_mode,'cross')
    scan_stg = cross_stg; 
    if (ls_pos.x ~= x_ls_rng_h)|(ls_pos.z ~= 0)
        error('Error. \nInvalid initial position')
    end
    fprintf('Ready for cross scan\n');
else
    error('Error. \nInvalid scan mode')
end    

for k_stg = 1:scan_stg.Num
    fprintf(sprintf('%s stage %d\n',scan_mode,k_stg));
    N_x_stp = scan_stg.x_stp(k_stg);
    N_z_stp = scan_stg.z_stp(k_stg);
    if N_x_stp ~= 0
        arduino=sprintf('sudo echo -ne "%d,%d\n" > /dev/ttyACM%d',scan_stg.x_stp(k_stg),ls_wait,x_ls_port);
        N_stp = N_x_stp;
    elseif N_z_stp ~= 0
        arduino=sprintf('sudo echo -ne "%d,%d\n" > /dev/ttyACM%d',scan_stg.z_stp(k_stg),ls_wait,z_ls_port);
        N_stp = N_z_stp;
    end
    system(arduino);    
    switch N_stp
        case x_ls_rng 
            T_mov = 30;
            T_meas = 35;            % time of sampling in seconds
        case x_ls_rng_h 
            T_mov = 15;
            T_meas = 20;            % time of sampling in seconds
    end
    N_spl = T_meas * Rs;    % number of samples
    file_ref = sprintf('%s_stg%d_',scan_mode,k_stg); % refrence of experiment file name 
    file_USRP = [file_addr,'/',file_ref];
    % USRP sampling
    command=sprintf('sudo ~/uhd/host/build/examples/rx_multi_samples --args addr0=192.168.20.2,addr1=192.168.20.3,addr2=192.168.20.4 --file %s --nsamps %d --rate %d --freq %d  --gain 0 --sync pps --channels 0,1,2',file_USRP,N_spl,Rs,f_pu);
    system(command);
    ls_x_new = ls_pos.x + N_x_stp; 
    ls_z_new = ls_pos.z + N_z_stp;
    ls_pos = ls_pos_log('update',ls_x_new,ls_z_new,wv_len_half);
end
%     reset_ls(ls_x,ls_z,scan_mode) 

emnls_pos = rect2cross(ls_pos.x,ls_pos.z,x_ls_rng_h,-1,x_ls_port);

% reset linear stage
function reset_ls(ls_x,ls_z,scan_mode) 
switch scan_mode 
    case 'rect' % rect start from origin
        N_x_stp = 0 -ls_x;
        z_stp = 0 -ls_z;
    case 'cross' % cross starts from (x_ls_rng_h,0)
        N_x_stp = x_ls_rng_h - ls_x;
        z_stp = 0 -ls_z;
end

x_arduino=sprintf('sudo echo -ne "%d,0\n" > /dev/ttyACM%d',N_x_stp,x_ls_port);
system(x_arduino);
z_arduino=sprintf('sudo echo -ne "%d,0\n" > /dev/ttyACM%d',z_stp,z_ls_port);
system(z_arduino);
end


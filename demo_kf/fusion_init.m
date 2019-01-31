%%  Author    : Gao Ouyang
%%  Date      : 2017.01.18
%%  Descriptor: 5 UWB anchor(only ranging) and 6-axis MEMS-IMU
%%              apply a ukf demo for 3-D Location 
%%              states  : position,velocity,attitude,accel_bias,gyro_bias
%%              measures: ranging (unit: m)
%%              controls: accel , gyro(unit:deg/s)
%%

clc
clear all
close all

addpath('ekfukf');
load('ground_truth.mat')
%% download the sensor data
matfile = dir('*_HandledFileToMatData.mat');
if isempty(matfile)
    disp('            None Found *_HandledFileToMatData.mat')
end

for ki=1:size(matfile)
    load(matfile(ki).name)
end

global UKF;
UKF.AnchorOne = [9.21;1.08;-0.17];%4.08
UKF.AnchorTwo = [0;0;-1.885];
UKF.AnchorThree = [0;6.281;-1.37];
UKF.AnchorFour = [1.705;12.88;-2.27];
UKF.AnchorFive = [9.31;11.59;-0.52];
UKF.AnchorPosition = [UKF.AnchorOne, UKF.AnchorTwo,...
				      UKF.AnchorThree, UKF.AnchorFour,...
				      UKF.AnchorFive]*30;
UKF.AnchorPcs = 5;

% Noise and Initialization
ProcessNoiseVariance = [  3.9e-04,    4.5e-4,    7.9e-4;     %%% Accelerate_Variance
                        1.9239e-7, 3.5379e-7, 2.4626e-7;     %%% Accelerate_Bias_Variance
                          8.7e-04,   1.2e-03,   1.1e-03;     %%% Gyroscope_Variance
                        1.3111e-9, 2.5134e-9,  2.4871e-9     %%% Gyroscope_Bias_Variance
                       ];
MeasureNoiseVariance = [2.98e-03, 2.9e-03,...
					    1.8e-03, 1.2e-03,...
					    2.4e-03];  %%%%  UWB Ranging noise
Q = [   diag(ProcessNoiseVariance(1,:)),zeros(3,12); 
     	zeros(3,3), diag(ProcessNoiseVariance(1,:)),zeros(3,9); 
		zeros(3,6), diag(ProcessNoiseVariance(3,:)),zeros(3,6); 
		zeros(3,9),  diag(ProcessNoiseVariance(2,:)),zeros(3,3);
		zeros(3,12), diag(ProcessNoiseVariance(4,:))
	];
R = diag(MeasureNoiseVariance);
% Imu turn-on turn-off Noise 
StaticBiasAccelVariance  = [6.7203e-5,  8.7258e-5,   4.2737e-5]; 
StaticBiasGyroVariance   = [2.2178e-5,  5.9452e-5,   1.3473e-5];

% Initial guesses for the state mean x0 and covariance P0.   
Position_init        = [20;100;-1.9];     deta_Position_init = [0;0;0];
Speed_init           = [0;0;0];              deta_Speed_init = [0;0;0]; 
Euler_init           = [-10,20,80]'/180*pi;  deta_Euler_init = [0;0;0];          
Accelerate_Bias_init = [0;0;0];    deta_Accelerate_Bias_init = [0;0;0];   
Gyroscope_Bias_init  = [0;0;0];     deta_Gyroscope_Bias_init = [0;0;0];   
X0 = [Position_init; Speed_init; Euler_init; Accelerate_Bias_init; Gyroscope_Bias_init];
init_c = 0.1;
P0 = [init_c*eye(3,3),zeros(3,12);
      zeros(3,3),   1e-2*init_c*eye(3,3), zeros(3,9);
	  zeros(3,6),   1e-2*init_c*eye(3,3),zeros(3,6);
      zeros(3,9),   diag(StaticBiasGyroVariance),zeros(3,3);
      zeros(3,12),  diag( StaticBiasAccelVariance);
      ];

dX = [  zeros(9,1);   
	    sqrt(StaticBiasAccelVariance');
		sqrt(StaticBiasGyroVariance')];
X = X0;
P = P0;    
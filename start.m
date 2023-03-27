%%% This script sets some variables and launchs the Simulink interface

%% Cleaning workspace
bdclose all;
clc

%% Prompt the user for the type of simulation

disp('This script allows the user to select the interface method, which is');
disp('used to set some variables for the interface.');
disp(' '); 

disp('Select one of the following options:'); 
disp('    (1) Local Gazebo Simulation');
disp('    (2) Remote Gazebo Simulation'); 
disp('    (3) Wi-Fi control in station mode (the drone connects to a router)'); 
disp('    (4) Wi-Fi control in access point mode (the drone creates an hotspot)'); 

option = input('');

%% Create variables based on user input

h_receive = 0.005;
h_send = 0.025;  % Sampling time to send the commands, corresponds to 40Hz
h_optitrack = 0.02;
h_qualisys = 0.01;
h_stream_mocap = 0.04;
h = min([h_receive,h_stream_mocap,h_send,h_optitrack,h_qualisys]);

switch option
    case 1
        Remote_IP = '127.0.0.1';
        ID = input("Drone ID: ");
        Remote_Port = 14580+(ID-1);
        Local_Port = 14540+(ID-1);
    case 2
        Remote_IP = input("IP address of the computer running the simulation: ");
        ID = input("Drone ID: ");
        Remote_Port = 14580+(ID-1);
        Local_Port = 14540+(ID-1);
    case 3
        Remote_IP = ['192.168.1.',num2str(240+ID)];
        ID = input("Drone ID: ");
        Remote_Port = 15000+ID;
        Local_Port = 15000+ID;
    case 4
        Remote_IP = '192.168.4.1';
        ID = input("Drone ID: ");
        Remote_Port = 14555;
        Local_Port = 14550;
    otherwise
       disp('An incorrect option was selected')
       return
end

%% Open Simulink
addpath('lib/');
PX4_Control;
        

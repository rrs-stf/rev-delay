%% initialization of parameters
clear; close all; 

[x,fs] = audioread('drumloop.wav');
MSeconds = 1e-3;
M = round(MSeconds*fs);
overlap = 0.5;
f = 1024;
% Hop size
h = round(overlap*M);
x = x(:,1);
%}
%{
x = [1:5000; 5000:-1:1]';
%fs = 200;
ML = 100;
hL = 0.5*ML;
MR = 50;
hR = 0.5*MR;
f = 20;
M = ML;
h = hL;
%}
%{
x = 1:100;
x = x';
M = 10;
h = M/2;
f = 3;
fs = 20;
%}
wRect = rectwin(M);
wHann = hann(M,'periodic');
wHann = flipud(wHann);
vRect = 1;
vHann = 1 - vRect;
w = vRect.*wRect + vHann.*wHann;

g = 0.5;
%% Block based implementation
xD = zeros(length(x)+M,1);
y = zeros(length(x),1);

for i=1:h:length(x)-M
    xW = x(i+M-1:-1:i).*w;
    xD(i+M:i+2*M-1) = xW+xD(i+M:i+2*M-1);
    y(i:i+h-1) = (1-g)*x(i:i+h-1)+g*xD(i:i+h-1); 
end

%% Simulated real time implementation
iniK = 1;

xW1 = zeros(fs, 1);
xW2 = zeros(fs, 1);
xD = zeros(2*fs+h, 1);
outsig = [];

cnt1 = 0; cnt2 = 0; cntK = 0;
cnt = [cnt1 cnt2 cntK];
check = [];

read = fs;
order = 0;

for j = 1:f:length(x)-f
    in = x(j:j+f-1);
    
    [out, iniK, cnt, xW1, xW2, xD, read, order] = ...
    sttr(in, M, h, fs, g, w, iniK, cnt, xW1, xW2, xD, read, order);
    outsig = [outsig; out];
    
end
hold on
plot(y, 'b')
plot(outsig, 'r')
hold off

mse = immse(outsig, y(1:length(outsig)))
fprintf('Done\n')
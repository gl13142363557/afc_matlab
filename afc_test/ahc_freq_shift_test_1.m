
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% ahc_freq_shift_test_1.m
% 反馈抑制--移频法验证
% 
% 编辑者：高淋
% 开始时间：2024年09月30日
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%清理工程数据
clear all
close all
clc

%加载模拟外部环境处理的卷积系数
g = load('path.txt');
g = g(1: 300); %少取一点数据

%生成输入正弦波信号
% fs = 48000; %采样率
sig_time = 3; %信号时间
% sig_freq = 1126.12; %信号频率
% sig_amptiude = 0.1; %信号振幅
% sig_in = sig_amptiude * sin(2 * pi * sig_freq .* (0:sig_time * fs - 1) / fs);
%读取语音输入信号
[sig_in,fs] = audioread('man.wav');
sig_in = sig_in(1:sig_time * fs);
    
%计算输入数据数量
data_num = length(sig_in); %信号数据量

%生成希尔伯特滤波系数。希尔伯特变换所用滤波器，方法：先得到低通，然后移频
h = fir2(100,[0,0.48,0.5,1],[1,1,0,0]); 
h = h';%h(:);  %这就是一个转置操作，将行向量转为列向量，方便后面矩阵相乘 代替 卷积一个一个的点循环相乘
h = h .* exp(2*pi*1i*(1:length(h))'/4);
%反馈衰减
feed_gain = 0.3;  %如果这个反馈衰减值不够的话，就无法抑制啸叫
%移频处理参数
shift_freq = 3; %移动频率2hz
temp_h1 = exp(2*pi*1i*i/fs*shift_freq); %希尔伯特滤波系数


 %{
%模拟内部反馈，生成啸叫信号
c = [0,0,0,0,1]'; % 扩音系统内部传递路径c 注意这是个列向量，卷积计算时，直接矩阵相乘就行
xs1 = zeros(1, length(c)); %中间计算缓存
xs2 = zeros(1, length(g)); %中间计算缓存
feed_sig_out = zeros(1, data_num); %反馈输出信号缓存
temp = 0;
for i = 1:data_num
    % 等待与c卷积的信号缓存, 这里的卷积类似就只是加了一个延时
    %xs1 = [sig_in(i) + temp, xs1(1:end-1)];   
    %feed_sig_out(i) = feed_gain * (xs1 * c);  
    
    %直接将输入信号和外部环境处理的信号相加，进行一个衰减，就得到了反馈输入信号
    feed_sig_out(i) = feed_gain * (sig_in(i) + temp);
    
    % 幅度约束，啸叫则出现截止
    feed_sig_out(i) = min(1, feed_sig_out(i)); 
    feed_sig_out(i) = max(-1, feed_sig_out(i));
    
    % 等待与g卷积的信号缓存
    xs2 = [feed_sig_out(i), xs2(1:end-1)];  
    temp = xs2 * g;       
end
%}


%{
%模拟希尔伯特滤波器进行移频处理
shift_sig_out = zeros(1, data_num); %移频输出信号缓存
xs3 = zeros(1, length(h)); %中间计算缓存
for i = 1:data_num
    xs3 = [sig_in(i), xs3(1:end-1)]; %将输入信号加入卷积输入缓存区
    shift_sig_out(i) = xs3 * h; %卷积处理。因为时域卷积等于频域乘积，所以这里相当于频率移动了。
    shift_sig_out(i) = shift_sig_out(i) * temp_h1; % 频移f_shift
    shift_sig_out(i) = real(shift_sig_out(i));  % 取实部，恢复出频谱在负半轴部分的信号
end

%fft变换，查看频谱
h_fft = fft(h);
sig_in_fft = fft(sig_in);
shift_sig_out_fft = fft(shift_sig_out);

%频域图
% figure
% subplot(3,1,1);
% plot(abs(h_fft));
% subplot(3,1,2);
% plot(abs(sig_in_fft));
% subplot(3,1,3);
% plot(abs(shift_sig_out_fft));
%}


%模拟移频法进行反馈抑制
anti_feed_sig_out = zeros(1, data_num); %移频输出信号缓存
feed_sig_in = zeros(1, data_num); %反馈输入信号缓存
xs4 = zeros(1, length(h)); %中间计算缓存
xs5 = zeros(1, length(g)); %中间计算缓存
temp = 0;
for i = 1:data_num
    %直接将输入信号和外部环境处理的信号相加，就得到了反馈输入信号
    feed_sig_in(i) = feed_gain * (sig_in(i) + temp); %这里需要乘这个feed_gain，如果不衰减的话，抑制不来信号
    %移频处理
    xs4 = [feed_sig_in(i), xs4(1:end-1)]; %将输入信号加入卷积输入缓存区
    anti_feed_sig_out(i) = xs4 * h; %卷积处理。因为时域卷积等于频域乘积，所以这里相当于频率移动了。
    anti_feed_sig_out(i) = anti_feed_sig_out(i) * temp_h1; % 频移shift_freq
    anti_feed_sig_out(i) = real(anti_feed_sig_out(i));  % 取实部，恢复出频谱在负半轴部分的信号
    % 幅度约束，啸叫则出现截止
    anti_feed_sig_out(i) = min(1, anti_feed_sig_out(i)); 
    anti_feed_sig_out(i) = max(-1, anti_feed_sig_out(i));
    % 等待与g卷积的信号缓存
    xs5 = [anti_feed_sig_out(i), xs5(1:end-1)];  
    temp = xs5 * g;      
end


%时域图
figure
subplot(3,1,1);
plot(feed_sig_in);
subplot(3,1,2);
plot(sig_in);
subplot(3,1,3);
plot(anti_feed_sig_out);

%播放音频
% sound(sig_in, fs);
sound(anti_feed_sig_out, fs);


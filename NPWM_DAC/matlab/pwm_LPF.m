%% =========================================================
% PWM调压 + 一阶RC低通完整仿真
%
% 包含：
% 1. 从0V开始建立到最终稳态
% 2. Duty_old -> Duty_new 的小步进建立过程
% 3. 两种情况的稳定时间计算
% 4. 最终稳态PWM及输出纹波
%
%% =========================================================

clear;
clc;
close all;


%% =========================================================
% 1. 用户参数
% ==========================================================

V_PWM = 3.3;              % PWM峰值 [V]

f_PWM = 100e3;             % PWM频率 [Hz]

Duty_old = 0.05;          % 旧占空比

Duty_new = 0.06;          % 新占空比


%% =========================================================
% 2. RC参数
% ==========================================================

R = 85e3;                 % 电阻 [Ohm]

C = 22e-9;               % 223电容
                           % 22nF = 0.022uF


%% =========================================================
% 3. 仿真参数
% ==========================================================

points_per_period = 200;

N_period_show = 10;

% 允许的绝对稳定误差
V_error_allow = 1e-3;     % 1mV


%% =========================================================
% 4. 基本参数
% ==========================================================

T_PWM = 1/f_PWM;

tau = R*C;

fc = 1/(2*pi*R*C);


% 旧稳态电压
V_old = V_PWM*Duty_old;

% 新稳态目标电压
V_new = V_PWM*Duty_new;

% 占空比步进对应的电压变化
Delta_V_step = abs(V_new-V_old);


%% =========================================================
% 5. 从0V建立到最终稳态的稳定时间
% ==========================================================

% 从0V建立到V_new
%
% 输出平均包络：
%
% V(t) = V_new*(1-exp(-t/tau))
%
% 剩余误差：
%
% error(t) = V_new*exp(-t/tau)


if V_new > V_error_allow

    t_settle_0_to_final = ...
        -tau*log(V_error_allow/V_new);

else

    t_settle_0_to_final = 0;

end


% 常用百分比稳定时间

t_5pct = -tau*log(0.05);

t_1pct = -tau*log(0.01);

t_01pct = -tau*log(0.001);


%% =========================================================
% 6. Duty_old -> Duty_new 的稳定时间
% ==========================================================

if Delta_V_step > V_error_allow

    t_settle_step = ...
        -tau*log(V_error_allow/Delta_V_step);

else

    t_settle_step = 0;

end


%% =========================================================
% 7. 自动设置仿真时间
% ==========================================================

% 至少10tau
% 同时至少100个PWM周期

t_end = max(10*tau,100*T_PWM);


dt = T_PWM/points_per_period;

t = 0:dt:t_end;


%% =========================================================
% 8. 情况1：从0V开始建立
% ==========================================================

% 从t=0开始就使用Duty_new

PWM_zero = ...
    V_PWM*(mod(t,T_PWM) < Duty_new*T_PWM);


Vout_zero = zeros(size(t));


% 初始条件
Vout_zero(1) = 0;


for k = 1:length(t)-1

    dV = ...
        (PWM_zero(k)-Vout_zero(k))/(R*C);

    Vout_zero(k+1) = ...
        Vout_zero(k) + dV*dt;

end


%% =========================================================
% 9. 从0开始的理论平均包络
% ==========================================================

V_theory_zero = ...
    V_new*(1-exp(-t/tau));


%% =========================================================
% 10. 情况2：Duty_old -> Duty_new
% ==========================================================

PWM_step = ...
    V_PWM*(mod(t,T_PWM) < Duty_new*T_PWM);


Vout_step = zeros(size(t));


% 初始条件：
% 从旧稳态电压开始

Vout_step(1) = V_old;


for k = 1:length(t)-1

    dV = ...
        (PWM_step(k)-Vout_step(k))/(R*C);

    Vout_step(k+1) = ...
        Vout_step(k) + dV*dt;

end


%% =========================================================
% 11. 小步进理论平均包络
% ==========================================================

V_theory_step = ...
    V_new + ...
    (V_old-V_new)*exp(-t/tau);


%% =========================================================
% 12. 截取最终稳态
% ==========================================================

t_start_ss = ...
    t_end - N_period_show*T_PWM;


idx_ss = ...
    t >= t_start_ss;


t_ss = t(idx_ss);

PWM_ss = PWM_step(idx_ss);

Vout_ss = Vout_step(idx_ss);


% 横坐标从0开始

t_ss = t_ss-t_ss(1);

t_ss_us = t_ss*1e6;


%% =========================================================
% 13. 稳态参数
% ==========================================================

Vavg = mean(Vout_ss);

Vmax = max(Vout_ss);

Vmin = min(Vout_ss);

Ripple = Vmax-Vmin;


%% =========================================================
% 14. 打印结果
% ==========================================================

fprintf('\n');
fprintf('============================================\n');
fprintf('PWM + 一阶RC仿真结果\n');
fprintf('============================================\n');


fprintf('\nPWM参数：\n');

fprintf('PWM峰值             = %.3f V\n',V_PWM);

fprintf('PWM频率             = %.3f kHz\n',f_PWM/1e3);

fprintf('PWM周期             = %.3f us\n',T_PWM*1e6);


fprintf('\nRC参数：\n');

fprintf('R                   = %.3f kOhm\n',R/1e3);

fprintf('C                   = %.3f nF\n',C*1e9);

fprintf('时间常数 tau        = %.3f ms\n',tau*1e3);

fprintf('截止频率 fc         = %.3f Hz\n',fc);


fprintf('\n============================================\n');
fprintf('占空比和目标电压\n');
fprintf('============================================\n');

fprintf('旧Duty              = %.2f %%\n',...
        Duty_old*100);

fprintf('新Duty              = %.2f %%\n',...
        Duty_new*100);

fprintf('旧稳态电压          = %.6f V\n',...
        V_old);

fprintf('新稳态电压          = %.6f V\n',...
        V_new);

fprintf('单次步进电压变化    = %.3f mV\n',...
        Delta_V_step*1e3);


fprintf('\n============================================\n');
fprintf('从0V建立到最终稳态\n');
fprintf('============================================\n');

fprintf('目标电压            = %.6f V\n',...
        V_new);

fprintf('允许误差            = %.3f mV\n',...
        V_error_allow*1e3);

fprintf('进入 ±5%%           = %.3f ms\n',...
        t_5pct*1e3);

fprintf('进入 ±1%%           = %.3f ms\n',...
        t_1pct*1e3);

fprintf('进入 ±0.1%%         = %.3f ms\n',...
        t_01pct*1e3);

fprintf('按 %.3f mV误差稳定 = %.3f ms\n',...
        V_error_allow*1e3,...
        t_settle_0_to_final*1e3);


fprintf('\n============================================\n');
fprintf('Duty_old -> Duty_new 步进\n');
fprintf('============================================\n');

fprintf('电压变化量          = %.3f mV\n',...
        Delta_V_step*1e3);

fprintf('允许误差            = %.3f mV\n',...
        V_error_allow*1e3);

fprintf('步进稳定时间        = %.3f ms\n',...
        t_settle_step*1e3);


fprintf('\n============================================\n');
fprintf('最终稳态\n');
fprintf('============================================\n');

fprintf('理论平均电压        = %.6f V\n',...
        V_new);

fprintf('仿真平均电压        = %.6f V\n',...
        Vavg);

fprintf('最大电压            = %.6f V\n',...
        Vmax);

fprintf('最小电压            = %.6f V\n',...
        Vmin);

fprintf('纹波                = %.3f mVpp\n',...
        Ripple*1e3);


%% =========================================================
% 15. 图1：从0V建立到最终稳态
% ==========================================================

figure(1);

set(gcf,...
    'Name','从0V建立到最终稳态',...
    'Position',[100 100 1200 600]);


t_ms = t*1e3;


plot(t_ms,...
     Vout_zero,...
     'LineWidth',1.5);

hold on;


% 理论包络
plot(t_ms,...
     V_theory_zero,...
     '--',...
     'LineWidth',1.5);


% 目标值
yline(V_new,...
      '--',...
      '最终目标电压');


% 允许误差区域
yline(V_new+V_error_allow,...
      ':',...
      '+允许误差');

yline(V_new-V_error_allow,...
      ':',...
      '-允许误差');


% 时间常数
xline(tau*1e3,...
      ':',...
      '1\tau');


% 1%时间
xline(t_1pct*1e3,...
      ':',...
      '±1%');


% 实际设定稳定时间
xline(t_settle_0_to_final*1e3,...
      '--',...
      '稳定时间');


grid on;

xlabel('时间 / ms');

ylabel('输出电压 / V');


title(sprintf(...
    '从0V建立到 %.3fV，稳定时间 %.3f ms',...
    V_new,...
    t_settle_0_to_final*1e3));


legend(...
    'PWM实际RC输出',...
    '理论平均包络',...
    '最终目标',...
    'Location','best');


%% =========================================================
% 16. 图2：0V建立过程局部放大
% ==========================================================

figure(2);

set(gcf,...
    'Name','0V建立过程放大',...
    'Position',[120 120 1200 550]);


plot(t_ms,...
     Vout_zero,...
     'LineWidth',1.5);

hold on;


plot(t_ms,...
     V_theory_zero,...
     '--',...
     'LineWidth',1.5);


yline(V_new,...
      '--',...
      '目标值');


yline(V_new+V_error_allow,...
      ':');

yline(V_new-V_error_allow,...
      ':');


xline(t_settle_0_to_final*1e3,...
      '--',...
      '稳定时间');


grid on;

xlabel('时间 / ms');

ylabel('输出电压 / V');


title(sprintf(...
    '0V → %.3fV，允许误差 ±%.1f mV',...
    V_new,...
    V_error_allow*1e3));


xlim([0 min(t_end,6*tau)*1e3]);


%% =========================================================
% 17. 图3：Duty_old -> Duty_new建立过程
% ==========================================================

figure(3);

set(gcf,...
    'Name','占空比步进建立过程',...
    'Position',[140 140 1200 600]);


plot(t_ms,...
     Vout_step,...
     'LineWidth',1.5);

hold on;


plot(t_ms,...
     V_theory_step,...
     '--',...
     'LineWidth',1.5);


yline(V_old,...
      ':',...
      '旧稳态');


yline(V_new,...
      '--',...
      '新稳态');


yline(V_new+V_error_allow,...
      ':');

yline(V_new-V_error_allow,...
      ':');


xline(t_settle_step*1e3,...
      '--',...
      '步进稳定时间');


grid on;

xlabel('时间 / ms');

ylabel('输出电压 / V');


title(sprintf(...
    'Duty %.1f%% → %.1f%%，%.3fV → %.3fV',...
    Duty_old*100,...
    Duty_new*100,...
    V_old,...
    V_new));


legend(...
    'PWM实际RC输出',...
    '理论平均包络',...
    '旧稳态',...
    '新稳态',...
    'Location','best');


%% =========================================================
% 18. 图4：两种建立过程放一起比较
% ==========================================================

figure(4);

set(gcf,...
    'Name','两种建立过程对比',...
    'Position',[160 160 1200 600]);


plot(t_ms,...
     Vout_zero,...
     'LineWidth',1.5);

hold on;


plot(t_ms,...
     Vout_step,...
     'LineWidth',1.5);


yline(V_new,...
      '--',...
      '最终目标');


grid on;

xlabel('时间 / ms');

ylabel('输出电压 / V');


legend(...
    '0V → 最终稳态',...
    'Duty old → Duty new',...
    '最终目标',...
    'Location','best');


title('不同初始条件下的RC建立过程');


%% =========================================================
% 19. 图5：最终稳态PWM与RC输出
% ==========================================================

T_PWM_us = T_PWM*1e6;

x_max = N_period_show*T_PWM_us;


figure(5);

set(gcf,...
    'Name','最终稳态PWM和RC输出',...
    'Position',[180 100 1200 700]);


subplot(2,1,1);

plot(t_ss_us,...
     PWM_ss,...
     'LineWidth',1.2);

grid on;

xlim([0 x_max]);

xticks(0:T_PWM_us:x_max);

ylim([-0.2 V_PWM+0.2]);

ylabel('PWM / V');

title(sprintf(...
    '最终PWM，Duty = %.1f%%',...
    Duty_new*100));


subplot(2,1,2);

plot(t_ss_us,...
     Vout_ss,...
     'LineWidth',1.6);

hold on;


yline(Vavg,...
      '--',...
      '平均值');


grid on;

xlim([0 x_max]);

xticks(0:T_PWM_us:x_max);

xlabel('时间 / \mus');

ylabel('V_{out} / V');


title(sprintf(...
    '最终稳态：平均 %.6f V，纹波 %.3f mVpp',...
    Vavg,...
    Ripple*1e3));


%% =========================================================
% 20. 图6：最终稳态纹波放大
% ==========================================================

figure(6);

set(gcf,...
    'Name','最终稳态纹波放大',...
    'Position',[200 150 1200 500]);


plot(t_ss_us,...
     Vout_ss,...
     'LineWidth',1.8);

hold on;


yline(Vavg,...
      '--',...
      '平均值');

yline(Vmax,...
      ':',...
      '最大值');

yline(Vmin,...
      ':',...
      '最小值');


grid on;

xlim([0 x_max]);

xticks(0:T_PWM_us:x_max);

xlabel('时间 / \mus');

ylabel('输出电压 / V');


title(sprintf(...
    '稳态纹波：Vavg = %.6f V，Vpp = %.3f mV',...
    Vavg,...
    Ripple*1e3));

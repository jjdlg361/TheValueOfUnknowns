clear all
close all
clc

load('HMLdata.mat')
load('SMBdata.mat')
load('Russell3000.mat')
load('3monthbondyield.mat')
load('SaasTopdataTable.mat')
load('SaaSTopMCdataTable.mat')
load('IndexTopdataTable.mat')
%load('fullAIaverageReturns_outlierdelete.mat')
%load('fullAIaverageReturns_saasUSonly.mat')
load('fullaireturns_robust_less1_fixed.mat')
load('fullAIaverageReturns_outlierdelete.mat')
load('PortfolioIPO1yComplete.mat');
load('averageReturnsNPM.mat'); % Load RMW data
load('averageReturnsReinvRate.mat'); % Load CMA data
load('sentimentdata.mat'); % Load Sentiment data
load('IPOdataTable.mat')
load('RDtoRevDataTable.mat')
load('PeersTable.mat')

RMW_data=averageReturnsNPM;
CMA_data=averageReturnsReinvRate;
SentimentData=SentimentdataTable;
IPO_data = IPOdataTable; 
RD_data = RDtoRevDataTable;
Peers_data=PeersTable;

% Load your data (assuming they are in MATLAB tables or arrays)
AI_data = fullAIreturns; % Table with Date and AI returns
SaaS_data = PortfolioIPO1yComplete; % Table with Date and SaaS returns
SaaS_data.AverageReturn=SaaS_data.AverageReturn.*100;
% Convert the first column (dates) of all data tables to datetime objects and filter dates
date_cutoff = datetime('01-Jan-2021');
AI_data = AI_data(AI_data.Date >= date_cutoff, :);
SaaS_data = SaaS_data(SaaS_data.Date >= date_cutoff, :);



% Load Market factors data
% Assuming you have these tables already:
% MKT_data - Table with Date and Market Excess Return
% SMB_data - Table with Date and Size Factor
% HML_data - Table with Date and Value Factor
% risk_free_rate - Table with Date and Risk-free rate

% Example of loading (replace with actual data loading process)
MKT_data = Russell3000; % Load MKT data

% For SMB_data, keep only columns 1 (Date) and 4
SMB_data = SMB_data(:, [1, 4]);

% For HML_data, keep only columns 1 (Date) and 6
HML_data = HML_data(:, [1, 6]);

risk_free_rate = irxData; % Assuming irxData is already loaded

% Assuming RMW_data and CMA_data are arrays with the mentioned structure,
% and RMW_dates and CMA_dates are the date vectors for each.

% Convert the first column (dates) of RMW_data and CMA_data to datetime objects
RMW_table = array2table(RMW_data, 'VariableNames', {'Date', 'RMW_High', 'RMW_Low'});
CMA_table = array2table(CMA_data, 'VariableNames', {'Date', 'CMA_High', 'CMA_Low'});
Sentiment_table=SentimentData;
IPO_table=IPO_data;
RD_table=RD_data;
P_table=Peers_data;

RMW_table.Date = datetime(RMW_table.Date, 'ConvertFrom', 'datenum');
CMA_table.Date = datetime(CMA_table.Date, 'ConvertFrom', 'datenum');

% % Combine market factors into one table
% market_factors = outerjoin(outerjoin(MKT_data, SMB_data, 'Keys', 'Date'), HML_data, 'Keys', 'Date');
% Join MKT_data and SMB_data first, then join the result with HML_data
market_factors = outerjoin(MKT_data, SMB_data, 'Keys', 'Date', 'MergeKeys', true);
market_factors = outerjoin(market_factors, HML_data, 'Keys', 'Date', 'MergeKeys', true);
market_factors = outerjoin(market_factors, RMW_table, 'Keys', 'Date', 'MergeKeys', true);
market_factors = outerjoin(market_factors, CMA_table, 'Keys', 'Date', 'MergeKeys', true);
market_factors = outerjoin(market_factors, Sentiment_table, 'Keys', 'Date', 'MergeKeys', true);
market_factors = outerjoin(market_factors, IPO_table, 'Keys', 'Date', 'MergeKeys', true);
market_factors = outerjoin(market_factors, RD_table, 'Keys', 'Date', 'MergeKeys', true);
market_factors = outerjoin(market_factors, P_table, 'Keys', 'Date', 'MergeKeys', true);

% Synchronize AI_data with market factors and risk-free rate
merged_AI_data = outerjoin(AI_data, market_factors, 'Keys', 'Date', 'MergeKeys', true);
merged_AI_data = outerjoin(merged_AI_data, risk_free_rate, 'Keys', 'Date', 'MergeKeys', true);

% Remove rows with missing data
merged_AI_data = rmmissing(merged_AI_data);

% Calculate excess returns for AI companies
AI_excess_returns = merged_AI_data.AverageReturn - merged_AI_data.AdjClose;

% Prepare data for regression
X_AI = [merged_AI_data.Return, merged_AI_data.SMB, merged_AI_data.HML,merged_AI_data.RMW_High-merged_AI_data.RMW_Low,merged_AI_data.CMA_High-merged_AI_data.CMA_Low];%,merged_AI_data.("1y_minus")-merged_AI_data.("10y_plus"),merged_AI_data.("Group 50+")-merged_AI_data.("Group 10-"),merged_AI_data.("4peers_minus")-merged_AI_data.("10peers_plus")];
Y_AI = AI_excess_returns;

% Linear regression for AI companies
%% Use the following 3 lines in case you want to apply a robust ols
% mdl_AI = fitlm(X_AI, Y_AI, 'RobustOpts', 'on');
% beta_AI = mdl_AI.Coefficients.Estimate;
% stats_AI = [mdl_AI.Rsquared.Ordinary, mdl_AI.anova.F(1), mdl_AI.anova.pValue(1), mdl_AI.MSE];
[beta_AI, ~, ~, ~, stats_AI] = regress(Y_AI, [ones(size(X_AI, 1), 1) X_AI]);

% Display regression statistics for AI companies
disp('Regression statistics for AI Companies:');
disp(stats_AI);

% Synchronize SaaS_data with market factors and risk-free rate
merged_SaaS_data = outerjoin(SaaS_data, market_factors, 'Keys', 'Date', 'MergeKeys', true);
merged_SaaS_data = outerjoin(merged_SaaS_data, risk_free_rate, 'Keys', 'Date', 'MergeKeys', true);

% Remove rows with missing data
merged_SaaS_data = rmmissing(merged_SaaS_data);

% Remove the first 15 days from the data table
%merged_SaaS_data = removeFirst15Days(merged_SaaS_data);

% Calculate excess returns for SaaS companies
SaaS_excess_returns = merged_SaaS_data.AverageReturn - merged_SaaS_data.AdjClose;

% Prepare data for regression
X_SaaS = [merged_SaaS_data.Return, merged_SaaS_data.SMB, merged_SaaS_data.HML,merged_SaaS_data.RMW_High-merged_SaaS_data.RMW_Low,merged_SaaS_data.CMA_High-merged_SaaS_data.CMA_Low];%, merged_SaaS_data.("Group 50+")-merged_SaaS_data.("Group 10-"),merged_SaaS_data.("4peers_minus")-merged_SaaS_data.("10peers_plus"),merged_SaaS_data.("1y_minus")-merged_SaaS_data.("10y_plus")];
Y_SaaS = SaaS_excess_returns;

% Linear regression for SaaS companies
%% Use the following 3 lines in case you want to apply a robust ols
%mdl_SaaS = fitlm(X_SaaS, Y_SaaS, 'RobustOpts', 'on');
%beta_SaaS = mdl_SaaS.Coefficients.Estimate;
%stats_SaaS = [mdl_SaaS.Rsquared.Ordinary, mdl_SaaS.anova.F(1), mdl_SaaS.anova.pValue(1), mdl_SaaS.MSE];
[beta_SaaS, ~, ~, ~, stats_SaaS] = regress(Y_SaaS, [ones(size(X_SaaS, 1), 1) X_SaaS]);


% Display regression statistics for SaaS companies
disp('Regression statistics for SaaS Companies:');
disp(stats_SaaS);

avgReturn_AI = mean(AI_data.AverageReturn);
avgReturn_SaaS = mean(SaaS_data.AverageReturn);

% For AI Data
numRowsAI = height(AI_data);
firstHalfAI = AI_data(1:floor(numRowsAI/2), :); % First half of AI data
secondHalfAI = AI_data(floor(numRowsAI/2) + 1:end, :); % Second half of AI data

avgReturn_FirstHalf_AI = mean(firstHalfAI.AverageReturn);
avgReturn_SecondHalf_AI = mean(secondHalfAI.AverageReturn);

% For SaaS Data
numRowsSaaS = height(SaaS_data);
firstHalfSaaS = SaaS_data(1:floor(numRowsSaaS/2), :); % First half of SaaS data
secondHalfSaaS = SaaS_data(floor(numRowsSaaS/2) + 1:end, :); % Second half of SaaS data

avgReturn_FirstHalf_SaaS = mean(firstHalfSaaS.AverageReturn);
avgReturn_SecondHalf_SaaS = mean(secondHalfSaaS.AverageReturn);

% Display the results
disp(['AI First Half Average Return: ', num2str(avgReturn_FirstHalf_AI)]);
disp(['AI Second Half Average Return: ', num2str(avgReturn_SecondHalf_AI)]);
disp(['SaaS First Half Average Return: ', num2str(avgReturn_FirstHalf_SaaS)]);
disp(['SaaS Second Half Average Return: ', num2str(avgReturn_SecondHalf_SaaS)]);


figure; % Create a new figure
plot(AI_data.Date, AI_data.AverageReturn, 'b-', 'LineWidth', 2); % Plot AI data with a blue line
hold on; 
plot(SaaS_data.Date, SaaS_data.AverageReturn, 'r--', 'LineWidth', 2); % Plot SaaS data with a red dashed line

xlabel('Date'); % Label for the x-axis
ylabel('Average Return'); % Label for the y-axis
title('Average Returns of AI and SaaS Companies Over Time'); % Title of the plot
legend('AI Companies', 'SaaS Companies', 'Location', 'best'); % Add a legend

grid on; % Turn on the grid for better readability
datetick('x', 'yyyy'); % Format the x-axis to show years
hold off;

% Assuming your AI_data, SaaS_data, and irxData are already loaded and have the same date range

% Find common dates
commonDates = intersect(SaaS_data.Date, AI_data.Date);

% Filter AI_data and SaaS_data to only include common dates
AI_data = AI_data(ismember(AI_data.Date, commonDates), :);
SaaS_data = SaaS_data(ismember(SaaS_data.Date, commonDates), :);

% Interpolate or align the risk-free rate data with common dates
riskFreeRateInterpolated = interp1(datenum(irxData.Date), irxData.AdjClose, datenum(commonDates), 'linear', 'extrap');

% Calculate daily excess returns for AI and SaaS
excessReturns_AI = AI_data.AverageReturn; %- riskFreeRateInterpolated;
excessReturns_SaaS = SaaS_data.AverageReturn; %- riskFreeRateInterpolated;

% Calculate Sharpe Ratios
sharpeRatio_AI = mean(excessReturns_AI) / std(excessReturns_AI);
sharpeRatio_SaaS = mean(excessReturns_SaaS) / std(excessReturns_SaaS);

% Display Sharpe Ratios
disp(['Sharpe Ratio for AI: ', num2str(sharpeRatio_AI)]);
disp(['Sharpe Ratio for SaaS: ', num2str(sharpeRatio_SaaS)]);

% Plot the excess returns
figure;
plot(AI_data.Date, excessReturns_AI, 'b-', 'LineWidth', 2); % Plot excess returns for AI
hold on; 
plot(SaaS_data.Date, excessReturns_SaaS, 'r--', 'LineWidth', 2); % Plot excess returns for SaaS
xlabel('Date');
ylabel('Excess Returns');
title('Excess Returns of AI and SaaS Companies Over Time');
legend('AI Companies', 'SaaS Companies', 'Location', 'best');
grid on;
datetick('x', 'yyyy');
hold off;

% Define the window size for the moving average
windowSize = 20; % Example: 30-day moving average

% Calculate the moving average for AI and SaaS excess returns
movingAvg_AI = movmean(excessReturns_AI, windowSize);
movingAvg_SaaS = movmean(excessReturns_SaaS, windowSize);

% Create a larger figure
figure('Units', 'normalized', 'Position', [0.1, 0.1, 0.6, 0.6]);

% Plot the excess returns, moving averages, and risk-free rate
hold on;
grid minor
plot(AI_data.Date, movingAvg_AI, 'b-', 'LineWidth', 2); % Moving average for AI (solid line)
plot(SaaS_data.Date, movingAvg_SaaS, 'r-', 'LineWidth', 2); % Moving average for SaaS (solid line)

% Enhance plot labels, title, and legend with larger font size
xlabel('Date', 'FontSize', 24);
ylabel('Returns', 'FontSize', 24);
title('Returns and Moving Averages of AI and SaaS Companies Over Time', 'FontSize', 26);
legend('AI Moving Average', 'SaaS Moving Average', 'Location', 'best', 'FontSize', 22);

% Increase the font size of the axis ticks
set(gca, 'FontSize', 24);

% Format the x-axis to show years
datetick('x', 'yyyy');
grid on;
hold off;
% === Diagnostics for AI regression ===
% Residuals
residuals = Y_AI - [ones(size(X_AI,1),1) X_AI] * beta_AI;

% Intercept (alpha)
alpha = beta_AI(1);

% Average return
avgReturn_AI = mean(Y_AI);

% Standard deviation of residuals
std_resid = std(residuals);

% R² and adjusted R²
R2 = stats_AI(1);
n = length(Y_AI);
k = size(X_AI, 2);
adj_R2 = 1 - (1 - R2) * (n - 1) / (n - k - 1);

% Breusch–Pagan test for heteroscedasticity
e2 = residuals.^2;
[~, ~, ~, ~, stats_BP] = regress(e2, [ones(n,1) X_AI]);
LM = n * stats_BP(1);
pval_BP = 1 - chi2cdf(LM, k);

% VIFs
vif = zeros(k, 1);
for i = 1:k
    Xi = X_AI(:, i);
    X_others = X_AI(:, [1:i-1, i+1:end]);
    [~, ~, ~, ~, stats_vif] = regress(Xi, [ones(size(X_others,1),1) X_others]);
    vif(i) = 1 / (1 - stats_vif(1));
end

% === Display Summary ===
fprintf('\n--- Regression Diagnostics (AI) ---\n');
fprintf('Intercept (Alpha): %.4f\n', alpha);
fprintf('Average Excess Return: %.4f\n', avgReturn_AI);
fprintf('Standard Deviation of Residuals: %.4f\n', std_resid);
fprintf('R²: %.4f\n', R2);
fprintf('Adjusted R²: %.4f\n', adj_R2);
fprintf('F-statistic: %.4f\n', stats_AI(2));
fprintf('F-statistic p-value: %.4f\n', stats_AI(3));
fprintf('Breusch–Pagan p-value: %.4f\n', pval_BP);
fprintf('--- VIFs ---\n');
disp(array2table(vif, 'VariableNames', {'VIF'}, 'RowNames', compose('X%d', 1:k)));

% === Diagnostics for SaaS regression ===
% Residuals
residuals_SaaS = Y_SaaS - [ones(size(X_SaaS,1),1) X_SaaS] * beta_SaaS;

% Intercept (alpha)
alpha_SaaS = beta_SaaS(1);

% Average return
avgReturn_SaaS = mean(Y_SaaS);

% Standard deviation of residuals
std_resid_SaaS = std(residuals_SaaS);

% R² and adjusted R²
R2_SaaS = stats_SaaS(1);
n_SaaS = length(Y_SaaS);
k_SaaS = size(X_SaaS, 2);
adj_R2_SaaS = 1 - (1 - R2_SaaS) * (n_SaaS - 1) / (n_SaaS - k_SaaS - 1);

% Breusch–Pagan test for heteroscedasticity
e2_SaaS = residuals_SaaS.^2;
[~, ~, ~, ~, stats_BP_SaaS] = regress(e2_SaaS, [ones(n_SaaS,1) X_SaaS]);
LM_SaaS = n_SaaS * stats_BP_SaaS(1);
pval_BP_SaaS = 1 - chi2cdf(LM_SaaS, k_SaaS);

% VIFs
vif_SaaS = zeros(k_SaaS, 1);
for i = 1:k_SaaS
    Xi = X_SaaS(:, i);
    X_others = X_SaaS(:, [1:i-1, i+1:end]);
    [~, ~, ~, ~, stats_vif_SaaS] = regress(Xi, [ones(size(X_others,1),1) X_others]);
    vif_SaaS(i) = 1 / (1 - stats_vif_SaaS(1));
end

% === Display Summary ===
fprintf('\n--- Regression Diagnostics (SaaS) ---\n');
fprintf('Intercept (Alpha): %.4f\n', alpha_SaaS);
fprintf('Average Excess Return: %.4f\n', avgReturn_SaaS);
fprintf('Standard Deviation of Residuals: %.4f\n', std_resid_SaaS);
fprintf('R²: %.4f\n', R2_SaaS);
fprintf('Adjusted R²: %.4f\n', adj_R2_SaaS);
fprintf('F-statistic: %.4f\n', stats_SaaS(2));
fprintf('F-statistic p-value: %.4f\n', stats_SaaS(3));
fprintf('Breusch–Pagan p-value: %.4f\n', pval_BP_SaaS);
fprintf('--- VIFs ---\n');
disp(array2table(vif_SaaS, 'VariableNames', {'VIF'}, 'RowNames', compose('X%d', 1:k_SaaS)));


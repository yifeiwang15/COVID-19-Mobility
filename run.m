%% load data

[nytLogDC,~] = load_NYT('data/us-states.csv'); % log daily cases

dotM = CMobility_DoT();
dotM.load_state_data('data/trips_state.csv',1); % mobility

% mask and restaurant policies
policy ={};
policy{1} = readtable('data/maskrequired_all.csv', 'ReadVariableNames', true, ...
                      'ReadRowNames', false ); 
policy{2} = readtable('data/policy_state_food_restaurant.csv', 'ReadVariableNames', true, ...
                      'ReadRowNames', false, 'Delimiter',','); 

warning('off')

mse = {};
avg = {};

StateNames = dotM.mStateNames; % Names of all states

%% train and test
varnames_p={'Intercept','x1_pvalue','x2_pvalue','x3_pvalue','x4_pvalue', ...
            'x5_pvalue','x6_pvalue','x7_pvalue','x8_pvalue','x9_pvalue', ...
            'x10_pvalue','x11_pvalue','x12_pvalue', 'x13_pvalue'};
varnames={'Intercept','x1','x2','x3','x4','x5','x6','x7','x8','x9','x10', ...
          'x11','x12','x13'};

vartypes = cell(1, length(varnames));

for k = 1 : length( varnames )
    vartypes{k} = 'double';
end

FitTable = table('Size', [length(StateNames), length( varnames )], 'VariableType', ...
                 vartypes, 'VariableNames', varnames, 'RowNames', StateNames );
FitTableP = table('Size', [length(StateNames), length( varnames )], 'VariableType', ...
                 vartypes, 'VariableNames', varnames_p, 'RowNames', StateNames );

for i = 1 : length(StateNames)
    StateName = StateNames{i};
    model = COVID_Mobility();
    model.fit(nytLogDC(:,1:end-14), dotM.mStateMobility, policy, StateName);
    
    temp_mse = [];
    temp_avg = [];
    
    for k = [3, 7, 10, 14]
        model.test(nytLogDC(:,1:end), dotM.mStateMobility, [], StateName, 0, k);
        temp_mse = [temp_mse, model.mTestMSE]; %mTestMSE
        temp_avg = [temp_avg, model.mTestAvg];
    end 
        
    mse{i} = temp_mse;
    avg{i} = temp_avg;
    FitData = [model.mIntercept, model.mCoeffStat.Coefficients.Estimate(2:end)'];
    FitDataP = [model.mIntercept, model.mCoeffStat.Coefficients.pValue(2:end)'];
    FitTable(i,1:length(num2cell(FitData))) = num2cell(FitData);
    FitTableP(i,1:length(num2cell(FitDataP))) = num2cell(FitDataP);
end

reportMSE = zeros(length(mse), 4);
reportAVG = zeros(length(avg), 4);
for i = 1:length(mse)
    reportMSE(i,:)=mse{i};
    reportAVG(i,:)=avg{i};
end

%% overall performance

% box plot of nRMSE and RALE
figure;   
set(gcf,'unit','centimeters','position',[10 5 30 20]);
subplot(2,2,1); 
boxplot(reportMSE,{'3 days','7 days','10 days','14 days'});
text([1 2 3 4], median(reportMSE)-0.007, num2str(median(reportMSE)','%.3f'), 'FontSize', 8)
hold on
plot(median(reportMSE),'ro-')
ylabel('nRMSE')

subplot(2,2,2); 
boxplot(reportAVG,{'3 days','7 days','10 days','14 days'});
text([1 2 3 4], median(reportAVG)-0.0042, num2str(median(reportAVG)','%.3f'), 'FontSize', 8)
hold on
plot(median(reportAVG),'ro-')
ylabel('RALE')





% significant factors
subplot(2,2,3); 
nFreqCount = sum(TableP>0);
nFreqCount(12) = nFreqCount(12)-1; % remove states of missing restaurant policy.
nFreqCount(13) = nFreqCount(13)-17; % remove states of missing mask policy.
nFreq = nFreqCount ./ ([51*ones(1,11), 51-1, 51-17]);
[~, Idx] = sort(nFreq,'ascend');
mVarNames = {'Dis-0-1','Dis-1-3', 'Dis-3-5', 'Dis-5-10', 'Dis-10-25', 'Dis-25-50', ...
             'Dis-50-100', 'Dis-100-250', 'Dis-250-500', 'Dis > 500', 'Stay-at-home', ...
             'Restaurant Policy', 'Mask Policy'};

barh(nFreq(Idx));
set(gca,'yTickLabel',mVarNames(Idx))
xlabel('Frequency being identified as significant')

subplot(2,2,4); 
mask = FitTableP{:,2:end}<=0.05;
TableP = -log(FitTableP{:, 2:end}).*mask;
Coeffs = FitTable{:,2:end}.*mask;
Coeffs(Coeffs == 0) = NaN;
boxplot(Coeffs(:,[13, 12, 11, 1, 2, 10]),{'Mask Policy', 'Restaurant Policy', 'Stay-at-home', 'Dis-0-1', 'Dis-1-3', 'Dis > 500'},'orientation','horizontal')
xlabel('Estimated coefficients')
hold on
plot([0, 0], [0, 7],'--')


% one prediction example

StateName = 'MA';
model = COVID_Mobility();
model.fit(nytLogDC(:,1:end-14), dotM.mStateMobility, policy, StateName);
model.test(nytLogDC(:,1:end), dotM.mStateMobility, [], StateName, 1, 14);



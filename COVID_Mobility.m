classdef COVID_Mobility < handle
    properties
        mState = '';
        mStartDate = [];
        mEndDate = [];
        
        mPolicy = 0;
        mPolicyRestaurant = [];
        
        mLogDC = [];
        mSmoothenedLogDC = [];

        mLogR = [];
        mProcessedLogR = [];
        
        mMobility = [];
        mSmoothenMobility = 0;
        mMobilityBias = [];
        mMobilityNorm = [];
        
        mVar = 0;
        mDataAugmentation = 0;
        mMaxDC = 0;
        
        mIncubation = 18;
        mCoeff = [];
        mIntercept = [];
        mCoeffStat = [];
        mMinCVMSE = [];
        mSelectedIdx = [];
        mPandemicStart = [];
        
        mPolyFun = [];
        
        mPredictions = [];
        mTestMSE = [];
        mTestAvg = [];
        mPCACoeff = [];
        mPCAmu = [];
        mCalibration = [];
    end
    
    methods        
        function [trainX, trainY, fitModel] = fit( this, logDC, mobility, policy, state)
            if nargin < 5 ; end
            
            % load data for the target state
            this.mState = state;
            this.mLogDC = logDC{state, :};
            dcDay = str2double( logDC.Properties.VariableNames{1}(end-1:end) );
            
            mobilityDay = str2double( mobility{1}.Properties.VariableNames{1}(end-1:end) );

            if dcDay < mobilityDay
                this.mStartDate = datenum( strrep(mobility{1}.Properties.VariableNames{1}(2:end), '_', '-') );
                this.mEndDate = datenum( strrep(mobility{1}.Properties.VariableNames{end}(2:end), '_', '-') );
                
                this.mLogDC = this.mLogDC(mobilityDay-dcDay+1 : end);
                this.mMobility = [];
                for k = 1 : length(mobility)
                    this.mMobility(end+1, :) = normalize(mobility{k}{state, :});
                end
            else
                this.mStartDate = datenum( strrep(logDC.Properties.VariableNames{1}(2:end), '_', '-') );
                this.mEndDate = datenum( strrep(logDC.Properties.VariableNames{end}(2:end), '_', '-') );

                d = dcDay - mobilityDay;
                this.mMobility = [];
                for k = 1 : length(mobility)
                    this.mMobility(end+1, :) = mobility{k}{state, d+1:end};
                end
            end
            
            %% preprocessing
            
            % mobility reconstruction
            this.mMobility = this.reconstruct_mobility(this.mMobility);
            
            % mobility normalization 
            this.mMobilityNorm = max(this.mMobility(:,1:60),[],2); 
            this.mMobility = this.mMobility./this.mMobilityNorm;
            this.mMobilityBias = median(this.mMobility(:,1:60),2);
            this.mMobility = this.mMobility - this.mMobilityBias;
           
            % policy day
            if ~isempty( policy )
                % Check existance of target state
                IsMember = ismember(policy{1}{:,1},this.mState);
                StateId = find(IsMember, 1);
                IsMemberR = ismember(policy{2}{:,1},this.mState);
                StateIdR = find(IsMemberR, 1);
                if ~isempty(StateIdR)
                    this.mPolicyRestaurant = [datenum(policy{2}{StateIdR, 2}), datenum(policy{2}{StateIdR, 3})];
                else
                    disp(['No restaurant policy for ', this.mState]);
                end
                if ~isempty(StateId) 
                    this.mPolicy = datenum(policy{1}{StateId, 2}); 
                else 
                    disp(['No masking policy for ', this.mState]);
                end
            end

            
            this.mPandemicStart = COVID_Mobility.detect_pandemic_start( this.mLogDC );
            this.mSmoothenedLogDC = COVID_Mobility.smoothen_logDC( this.mLogDC, this.mPandemicStart );
            
            % log transimission rate
            this.mLogR = [0, this.mSmoothenedLogDC(2:end) - this.mSmoothenedLogDC(1:end-1)];
            this.mLogR( this.mPandemicStart ) = 0;
            

            prior = 1 : size(this.mMobility, 1);
            x = this.mMobility(prior, :)';
            
            % dummy variable for policies
            if ~isempty(this.mPolicyRestaurant)
                x(:,end+1)=zeros(size(x, 1),1); % restaurant
                x(this.mPolicyRestaurant(1)-this.mStartDate+1 : min([this.mPolicyRestaurant(2)-this.mStartDate+1,end]), end) = 1;
            end
            if this.mPolicy ~= 0 
                x(:,end+1)=zeros(size(x, 1),1); % mask
                x(this.mPolicy-this.mStartDate+1:end, end) = 1;
            end
            this.mMobility = x';
            
            y = this.mLogR(this.mPandemicStart+1:end); 
            
            % output the training data
            trainX = x; trainY = y;
            
            % extra
            newLogR = COVID_Mobility.preprocess_logR( y );
            this.mProcessedLogR = [zeros(1, this.mPandemicStart), newLogR];
            
           
            %% fitting
 
            this.mMinCVMSE = Inf;
            
            for delay = 15 : min(20, this.mPandemicStart)      
                x = trainX( this.mPandemicStart+1-delay : end, :);
                duration = min( size(x,1), length(newLogR) );
                x = x(1:duration, :);
                y = newLogR(1:duration)';


                % 10 fold CV 
                indices = crossvalind('Kfold',y,10);
                mse = 0;
                for i = 1:10
                    test = (indices == i);
                    train = ~test;
                    if (this.mPolicy > 0) && (this.mPolicyRestaurant(1) > 0)
                        mdl = fitlm(x(train,:), y(train), 'CategoricalVars', [12, 13], 'RobustOpts','on'); % mask and restaurant
                    elseif this.mPolicyRestaurant ~= 0
                        mdl = fitlm(x(train,:), y(train), 'CategoricalVars', [12], 'RobustOpts','on'); % restaurant
                    else                         
                        mdl = fitlm(x(train,:), y(train), 'RobustOpts','on'); % no policy
                    end
                    preds = predict(mdl,x(test,:));
                    mse = mse + immse(y(test),preds);
                end
                mse = mse/10;            
                normalizedMSE = mse / (max(newLogR(121:end)) + eps);
                if normalizedMSE < this.mMinCVMSE
                    if (this.mPolicy > 0) && (this.mPolicyRestaurant(1) > 0)
                        mdl = fitlm(x(train,:), y(train), 'CategoricalVars', [12, 13], 'RobustOpts','on'); % mask and restaurant
                    elseif this.mPolicyRestaurant ~= 0
                        mdl = fitlm(x(train,:), y(train), 'CategoricalVars', [12], 'RobustOpts','on'); % restaurant
                    else                         
                        mdl = fitlm(x(train,:), y(train), 'RobustOpts','on'); % no policy
                    end
                    this.mIntercept = mdl.Coefficients.Estimate(1);
                    this.mCoeff = mdl.Coefficients.Estimate(2:end);
                    this.mCoeffStat = mdl;
                    this.mSelectedIdx = 1 : size(this.mMobility+1, 1);
                    this.mMinCVMSE = normalizedMSE;
                    this.mIncubation = delay;
                end
            end
        end

        function [predictedLogR, predictedLogDC, delay] = test( this, logDC, mobility, policy, state, draw, predLen)
            
            % load data for the target state
            gtLogDC = logDC{state, :}; % ground truth
            temp = strrep( logDC.Properties.VariableNames{1}(2:end), '_', '-' );
            if length(temp) == 4
                dcDay = datenum( ['2020', temp], 'yyyymmdd' );
            else
                dcDay = datenum( temp );
            end
            if ~isempty( policy )
                policyDay = datenum( strrep( policy.Properties.VariableNames{1}(2:end), '_', '-' ) );
            else
                policyDay = 1;
            end
            temp = strrep( mobility{1}.Properties.VariableNames{1}(2:end), '_', '-' );
            if length(temp) == 4
                mobilityDay = datenum( ['2020', temp], 'yyyymmdd' );
            else
                mobilityDay = datenum( [temp(1:4), '-', temp(5:6), '-', temp(7:8)] );
            end

            if dcDay < mobilityDay
                gtLogDC = gtLogDC(mobilityDay-dcDay+1 : end);
                testMobility = zeros( length(mobility), length(mobility{1}{state, :}) );
                for k = 1 : length(mobility)
                    testMobility(k, :) = normalize(mobility{k}{state, :});
                end
                startDate = mobilityDay;
            else
                d = dcDay - mobilityDay;
                testMobility = zeros( length(mobility), length(mobility{1}{state, :})-d );
                for k = 1 : length(mobility)
                    testMobility(k, :) = mobility{k}{state, d+1:end};
                end
                startDate = dcDay;
            end
          
            %% Preprocessing
            % reconstruct test mobility
 
            tempMobility = testMobility';
            mobility_reconstruct = tempMobility;
            
            PCAscore = (tempMobility-this.mPCAmu)*this.mPCACoeff;
            temp = PCAscore*this.mPCACoeff' + repmat(this.mPCAmu,size(tempMobility,1),1);
            
            OutlierIdx = isoutlier(tempMobility);
            mobility_reconstruct(OutlierIdx) = temp(OutlierIdx);
            testMobility = mobility_reconstruct';
            
            % mobility normalization
            testMobility = testMobility./this.mMobilityNorm;
            testMobility = testMobility - this.mMobilityBias;

            
            % policy
            if ~isempty(this.mPolicyRestaurant)
                testMobility(end+1,:) = zeros(size(testMobility,2),1);
                testMobility(end, this.mPolicyRestaurant(1)-startDate+1 : min([this.mPolicyRestaurant(2)-startDate+1,end])) = 1;
            end
            
            if this.mPolicy > 0
                testMobility(end+1,:) = zeros(size(testMobility,2),1);
                testMobility(end, this.mPolicy-startDate+1:end) = 1;
            end
            
            
            %% Prediction

            pandemicStart = COVID_Mobility.detect_pandemic_start( gtLogDC );
            smoothenedGTLogDC = COVID_Mobility.smoothen_logDC( gtLogDC, pandemicStart );
            gtLogR = [0, smoothenedGTLogDC(2:end) - smoothenedGTLogDC(1:end-1)];
            gtLogR( pandemicStart ) = 0;
            processedGTLogR = [gtLogR(1:pandemicStart), COVID_Mobility.preprocess_logR( gtLogR(pandemicStart+1:end) )];
            
            testLen = length(gtLogDC);
            temp = COVID_Mobility.smoothen_logDC( gtLogDC, pandemicStart );
            predictedLogDC = zeros(1, testLen + this.mIncubation);
            predictedLogDC(pandemicStart) = temp(pandemicStart);
            
            [predictedLogR, delay] = this.predict( testMobility );
            predictionEndDate = startDate + size(testMobility,2) + delay - 1;
            
            ObeservedDuration = this.mEndDate-this.mStartDate; 
            % smoothing logR
            for k = ObeservedDuration-7 : length(predictedLogR) % testLen + delay
                predictedLogR_accum = movavg(predictedLogR(k-4:k)', 'exponential', 3);
                predictedLogDC(k) = predictedLogDC(k-1) + predictedLogR_accum(end);
            end
            
            %% calibration
           
            % try with parameter a
            a = optimvar('a');
            b = optimvar('b');
            
            x = predictedLogDC(ObeservedDuration-7 : ObeservedDuration)';
            
            % build optimization problem
            options = optimset('Display','off');
            problem = optimproblem('ObjectiveSense','min');
            problem.Objective = sum(( (a*x + b) - smoothenedGTLogDC(ObeservedDuration-7 : ObeservedDuration)' ).^2 );
            cons1 = a <= 1.01;
            cons2 = a >= 0.99;
            problem.Constraints.cons1 = cons1;
            problem.Constraints.cons2 = cons2;
            caliberation = solve( problem, 'options', options );
            predictedLogDC = caliberation.a*predictedLogDC + caliberation.b;
            this.mCalibration = [caliberation.a, caliberation.b];
            this.mPredictions = exp(predictedLogDC);
        
            
            %% performance
            % print nRMSE of predLen days
            nDur = 13;
            mse = mean(abs(predictedLogDC(testLen-nDur : testLen-nDur + predLen -1)-smoothenedGTLogDC(testLen-nDur : testLen-nDur + predLen -1)).^2);
            this.mTestMSE = sqrt(mse) / (median(smoothenedGTLogDC(testLen - nDur :testLen-nDur + predLen -1))+eps);
            
            % print RALE of predLen days
            AvgCases  = sum(predictedLogDC(testLen-nDur : testLen-nDur + predLen -1)-smoothenedGTLogDC(testLen-nDur :testLen-nDur + predLen -1));
            this.mTestAvg = abs(AvgCases)/(sum(smoothenedGTLogDC(testLen-nDur : testLen-nDur + predLen -1)));
           
           %% draw 
           if draw == 1
               gtLen = length(gtLogR);
               policyIdx = [];
                                 
            %% figure 1 -- Transimission rates reconstruction
           
            figure; 
            subplot(2,1,1)
            
            % Observed R
            plot( startDate+pandemicStart : startDate+gtLen-1, exp(gtLogR(pandemicStart+1:end)), ...
                 'Color', [0, 0.4470, 0.7410],'LineWidth', 0.6);
            hold on;
            
            % Recontructed R
            Rdur = this.mEndDate-(startDate+delay+pandemicStart)+1;
            plot( startDate+delay+pandemicStart :  this.mEndDate, exp(predictedLogR(delay+pandemicStart+(1:Rdur) )), ...
                 '--', 'Color', [0.8500, 0.3250, 0.0980],'LineWidth', 0.8  ); %'k-.'
           
             % Predicted R
            plot( this.mEndDate: predictionEndDate, exp(predictedLogR(delay+pandemicStart+Rdur : end)), ...
                 'Color', [0.8500, 0.3250, 0.0980],'LineWidth', 0.8  ); %'k-.'
            
            plot( [startDate, predictionEndDate], [1, 1], 'b--' );
            ylim_min = min(exp(gtLogR(pandemicStart+1:end)))*0.99;
            ylim_max = max(exp(gtLogR(pandemicStart+1:end)))*1.01;
            
            plot( [this.mEndDate, this.mEndDate], [ylim_min, ylim_max], '--',  'Color', [ 0.9290, 0.6940, 0.1250])
            ylim([ylim_min, ylim_max])
            legend( {'Observed R', 'Reconstructed R', 'Predicted R'}, 'Location', 'NorthWest' );
            text(this.mEndDate+2, ylim_min+(ylim_max-ylim_min)*0.8, 'Preds');
            title( [state, '  (\Delta t = ', num2str(delay), ')'] );
            
            
            datetick('x','mm/dd', 'keepticks')
            l = axis; l(1) = startDate+60; l(2) = predictionEndDate;
            axis( l );
           
            
            
%             % blowout window
%             axes('Position',[0.3,0.6,0.4*0.75,0.3])
%             plot( startDate+gtLen-1-21 : startDate+gtLen-1, exp(gtLogR(end-21:end)) , 'Color', [0, 0.4470, 0.7410],'LineWidth', 0.8); % gt
%             hold on;
%             pred_l = predictionEndDate-(startDate+gtLen-1-14);
%             plot( startDate+gtLen-1-14 : predictionEndDate, exp(predictedLogR(end-pred_l:end)) , 'Color', [0.8500, 0.3250, 0.0980],'LineWidth', 0.8 ); % Prediction
%             hold on;
%             
%             %axis off;
%             datetick('x', 'mm/dd', 'keepticks');
%             ylim_min = min(exp(gtLogR(end-21:end)))*0.99;
%             ylim_max = max(exp(gtLogR(end-21:end)))*1.01;
%             plot( [this.mEndDate, this.mEndDate], [ylim_min, ylim_max], '--',  'Color', [ 0.9290, 0.6940, 0.1250])
%             ylim([ylim_min, ylim_max])
%             l = axis; l(1) = startDate+gtLen-1-21; l(2) = predictionEndDate;
%             axis( l );
            
            %% figure 2 -- Daily cases prediction
            
            subplot(2,1,2)
         
            % gt
            plot( startDate+this.mPandemicStart : startDate+gtLen-1, gtLogDC(this.mPandemicStart+1:end) , ...
                 'Color', [0, 0.4470, 0.7410],'LineWidth', 0.6); 
            hold on;
            
            % smoothed gt
            plot( startDate+this.mPandemicStart : startDate+gtLen-1, smoothenedGTLogDC(this.mPandemicStart+1:end), ...
                 '--', 'Color', [0, 0.4470, 0.7410], 'LineWidth', 0.8  ); 
            hold on;
            
            % 14-day predictions 
            plot(  startDate+gtLen-1-14 : startDate+gtLen-1, predictedLogDC(gtLen-14:gtLen), 'Color', [0.8500, 0.3250, 0.0980],'LineWidth', 1 ); 
            
            plot( [this.mEndDate, this.mEndDate], [min(min(gtLogDC)*1.2,0), max(gtLogDC)*1.2], '--',  'Color', [ 0.9290, 0.6940, 0.1250])
        
            ylim_min = min(gtLogDC(this.mPandemicStart+1:end))*0.8;
            ylim_max = max(gtLogDC(this.mPandemicStart+1:end))*1.2;
            
            legend( {'Observed daily cases', 'Processed cases', 'Predicted cases'}, 'Location', 'NorthWest' );
            
            text(this.mEndDate+2, ylim_min+(ylim_max-ylim_min)*0.2, 'Preds');
            title( state );
            ylim([ylim_min, ylim_max])
            datetick('x', 'mm/dd', 'keepticks');
            l = axis; l(1) = startDate+this.mPandemicStart; l(2) = predictionEndDate;
            axis( l );
            
%             % blowout
%             axes('Position',[0.5,0.2,0.4*0.75,0.3])
%             gca = plot( startDate+gtLen-1-21 : startDate+gtLen-1, gtLogDC(end-21:end) , 'Color', [0, 0.4470, 0.7410],'LineWidth', 0.8); % gt
%             hold on;
%             plot( startDate+gtLen-1-14 : startDate+gtLen-1, predictedLogDC(gtLen-14:gtLen) , 'Color', [0.8500, 0.3250, 0.0980],'LineWidth', 0.8 ); % Prediction
%             hold on;
%             plot( [this.mEndDate, this.mEndDate], [min(gtLogDC(end-21:end))*0.99, max(gtLogDC(end-21:end))*1.01], '--',  'Color', [ 0.9290, 0.6940, 0.1250])
%             %axis off;
%             datetick('x', 'mm/dd', 'keepticks');
%             ylim_min = min(gtLogDC(end-21:end))*0.99;
%             ylim_max = max(gtLogDC(end-21:end))*1.01;
%             
%             ylim([ylim_min, ylim_max])
%             l = axis; l(1) = startDate+gtLen-1-21; l(2) = startDate+gtLen-1;
%             axis( l );
           end
        end       
        
        
        function [optLogR, optDelay] = predict(this, mobility)    
            % uncalibrated prediction
            
            x = mobility;
            if this.mSmoothenMobility
                x = movmedian( x, 7, 2 ); 
            end
            optLogR = this.mCoeff' * x + this.mIntercept;
            optLogR = [zeros(1,this.mIncubation), optLogR];
            optDelay = this.mIncubation;
            
        end
        
        
        function [mobility_reconstruct] = reconstruct_mobility(this, mobility)
            % data reconstruction through pca
            % implement pca on training data and apply pca to new test data
            mobility = mobility';
            
            temp = mobility(1:end-30,:);
            [this.mPCACoeff, ~, ~, ~, ~, this.mPCAmu] = pca(temp,'NumComponents',4);

            % Reconstruct all the observed data.
            mobility_reconstruct = mobility;
            score_all = (mobility-this.mPCAmu)*this.mPCACoeff;
            temp = score_all*this.mPCACoeff' + repmat(this.mPCAmu,size(mobility,1),1); %(251,11)


            OutlierIdx = isoutlier(mobility);
            mobility_reconstruct(OutlierIdx) = temp(OutlierIdx);
            mobility_reconstruct = mobility_reconstruct';

        end
    end   
     methods(Static)
        function pandemicStart = detect_pandemic_start( logDC )
            temp = find( logDC );
            for k = 1 : length(temp)
                if all( logDC(temp(k)+1 : temp(k)+3) )
                    break;
                end
            end
            pandemicStart = temp(k);
        end     
        
        
        function processedLogR = preprocess_logR( logR )
            processedLogR = logR;
            [~, idx] = max( logR(1:25) );
            for k = idx+2 : length(logR)
                if ( logR(k) < logR(k-1) * 0.9 ) && ( logR(k-1) < logR(k-2) * 0.9 ) && ...
                        logR(k) < mean( logR(1:k) )
                    my = mean(logR(1 : k-1));
                    processedLogR(1:k-1) = (logR(1:k-1) - my)/5 + my;
                    break;
                end
            end
        end
        
        
        function slogDC = smoothen_logDC( logDC, pandemicStartIdx )
            slogDC = [zeros(1, pandemicStartIdx-1), movmean(movmedian( logDC(pandemicStartIdx:end), 7 ), 5)];
        end
        
        
    end
end
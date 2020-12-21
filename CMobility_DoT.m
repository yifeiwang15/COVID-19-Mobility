classdef CMobility_DoT < handle
    properties
        mStartDate = datenum( 2020, 1, 1 );
        mEndDate = datenum( 2020, 07, 26 );
        mStateMobility = {};
        mCountyMobility = {};
        
        mStateNames = {};
        mStateFIPS = [];
        mCountyNames = {};
        mCountyFIPS = [];
    end
    
    methods
        function load_state_data( this, filename, normalized_by_population )
            if nargin < 3 || isempty(normalized_by_population)
                normalized_by_population = 0;
            end
            temp = readtable(filename, 'ReadVariableNames', true, 'ReadRowNames', true );
            this.mStateNames = unique( temp{:, 3} );

            alldates = unique( temp{:,1} );
            this.mStartDate = datenum('2020/01/01');
            this.mEndDate = datenum( alldates{end} );
            
            columnnames = cell(1, this.mStartDate - this.mEndDate + 1);
            varTypes = cell(1, this.mStartDate - this.mEndDate + 1);
            for k = this.mStartDate : this.mEndDate
                columnnames{k-this.mStartDate+1} = ['D', datestr(k, 'mmdd')];
                varTypes{k-this.mStartDate+1} = 'double';
            end
            
            tripCategories = cell(1, length( temp.Properties.VariableNames ) - 7);
            for k = 9 : length( temp.Properties.VariableNames )
                name = strrep( temp.Properties.VariableNames{k}, 'NumberOfTrips', '' );
                if name(1) == '_'
                    if name(2) == '_'
                        name = ['Dis_', name(3:end), '_more'];
                    else
                        name = ['Dis_0', name];
                    end
                else
                    name = ['Dis_', name];
                end
                tripCategories{k-8} = name;
            end
            tripCategories{end} = 'StayHome';
            
            for k = 1 : length(tripCategories)
                this.mStateMobility{k} = table('Size',[length(this.mStateNames), length(columnnames)], 'VariableTypes', varTypes, ...
                    'VariableNames', columnnames, 'RowNames', this.mStateNames );
                this.mStateMobility{k}.Properties.DimensionNames = {'State', 'Date'};
                this.mStateMobility{k}.Properties.UserData = [this.mStartDate, this.mEndDate];
                this.mStateMobility{k}.Properties.Description = ['Category: ', tripCategories{k}];
            end
            
            for k = 1 : size(temp,1)
                date = ['D', temp{k,1}{1}(6:7), temp{k,1}{1}(9:10)];
                state = temp{k,3};
                popNotAtHome = temp{k,7};
                numTrips = temp{k, 9:end};
                totalTrip = sum(numTrips);
                for m = 1 : length(numTrips)
                    if normalized_by_population
                        this.mStateMobility{m}{state, date} = numTrips(m) / popNotAtHome;
                    else
                        this.mStateMobility{m}{state, date} = numTrips(m) / totalTrip;
                    end
                end
                this.mStateMobility{end}{state, date} = temp{k, 6}/(temp{k,6} + temp{k,7});
            end
        end
        
        function mobility = get_state_data( this, state )
            mobility = zeros( length(this.mStateMobility), size(this.mStateMobility{1}, 2) );
            for k = 1 : length( this.mStateMobility )
                mobility(k,:) = this.mStateMobility{k}{state, :};
            end
        end
        
        function denoise_NMF( this, state )
            if nargin == 2 && ~isempty(state)
                X = this.get_state_data( state );
            end
        end
        
        function visualize( this, states )
            figure;
            xrange = this.mStartDate : this.mEndDate;
            for k = 1 : length( this.mStateMobility )
                subplot(3, 4, k);
                plot( xrange, this.mStateMobility{k}{states, :}' );
                title( strrep(this.mStateMobility{k}.Properties.Description, '_', '-') );
                if k == 1
                    legend( states, 'Location', 'NorthWest' );
                end
                datetick('x','mm/dd', 'keepticks')
                l = axis; 
                l(1) = this.mStartDate; l(2) = this.mEndDate; 
                l(3) = min(this.mStateMobility{k}{states, :}) * 0.98;
                l(4) = max(this.mStateMobility{k}{states, :}) * 1.02;
                axis( l );
            end
            dcm = datacursormode(gcf);
            dcm.Enable = 'on';
            dcm.UpdateFcn = @COVID_Mobility.plotupdate;
        end
    end
    
    methods(Static)
        function txt = plotupdate(src, event)
            pos = get(event,'Position');
            temp = gca;
            if strcmp( temp.Title.String, 'Smoothened Mobiligy vs Processed LogR' )
                txt = {['x: ' num2str(pos(1))], ['y: ' num2str(pos(2))]};
            else
                txt = {['Date: ', datestr(pos(1), 'mm/dd' ), ' (idx=', num2str(src.Cursor.DataIndex), ')'], ['Value: ' num2str(pos(2))]};
            end
        end
    end
end
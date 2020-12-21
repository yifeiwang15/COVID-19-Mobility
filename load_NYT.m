function [dataLogDC, dataDC] = load_NYT(filename)

data = readtable( filename, 'HeaderLines', 1  );

dates = unique( data{:,1} );
varnames = cell(1, length(dates));
for k = 1 : length(dates)
    varnames{k} = sprintf( 'x%02d_%02d', dates(k).Month, dates(k).Day );
end
varnames = unique( varnames );
    
for r = 1 : size(data,1)
    switch data{r,2}{1}
        case 'Alabama'
            state_abbr = 'AL';
        case 'Alaska'
            state_abbr = 'AK';
        case 'Arizona'
            state_abbr = 'AZ';
        case 'Arkansas'
            state_abbr = 'AR';
        case 'California'
            state_abbr = 'CA';
        case 'Colorado'
            state_abbr = 'CO';
        case 'Connecticut'
            state_abbr = 'CT';
        case 'Delaware'
            state_abbr = 'DE';
        case 'District of Columbia'
            state_abbr = 'DC';
        case 'Florida'
            state_abbr = 'FL';
        case 'Georgia'
            state_abbr = 'GA';
        case 'Guam'
            state_abbr = 'GM';
        case 'Hawaii'
            state_abbr = 'HI';
        case 'Idaho'
            state_abbr = 'ID';
        case 'Illinois'
            state_abbr = 'IL';
        case 'Indiana'
            state_abbr = 'IN';
        case 'Iowa'
            state_abbr = 'IA';
        case 'Kansas'
            state_abbr = 'KS';
        case 'Kentucky'
            state_abbr = 'KY';
        case 'Louisiana'
            state_abbr = 'LA';
        case 'Maine'
            state_abbr = 'ME';
        case 'Maryland'
            state_abbr = 'MD';
        case 'Massachusetts'
            state_abbr = 'MA';
        case 'Michigan'
            state_abbr = 'MI';
        case 'Minnesota'
            state_abbr = 'MN';
        case 'Mississippi'
            state_abbr = 'MS';
        case 'Missouri'
            state_abbr = 'MO';
        case 'Montana'
            state_abbr = 'MT';
        case 'Nebraska'
            state_abbr = 'NE';
        case 'Nevada'
            state_abbr = 'NV';
        case 'New Hampshire'
            state_abbr = 'NH';
        case 'New Jersey'
            state_abbr = 'NJ';
        case 'New Mexico'
            state_abbr = 'NM';
        case 'New York'
            state_abbr = 'NY';
        case 'North Carolina'
            state_abbr = 'NC';
        case 'North Dakota'
            state_abbr = 'ND';
        case 'Northern Mariana Islands'
            state_abbr = 'NI';
        case 'Ohio'
            state_abbr = 'OH';
        case 'Oklahoma'
            state_abbr = 'OK';
        case 'Oregon'
            state_abbr = 'OR';
        case 'Pennsylvania'
            state_abbr = 'PA';
        case 'Puerto Rico'
            state_abbr = 'PR';
        case 'Rhode Island'
            state_abbr = 'RI';
        case 'South Carolina'
            state_abbr = 'SC';
        case 'South Dakota'
            state_abbr = 'SD';
        case 'Tennessee'
            state_abbr = 'TN';
        case 'Texas'
            state_abbr = 'TX';
        case 'Utah'
            state_abbr = 'UT';
        case 'Vermont'
            state_abbr = 'VT';
        case 'Virginia'
            state_abbr = 'VA';
        case 'Virgin Islands'
            state_abbr = 'VI';
        case 'Washington'
            state_abbr = 'WA';
        case 'West Virginia'
            state_abbr = 'WV';
        case 'Wisconsin'
            state_abbr = 'WI';
        case 'Wyoming'
            state_abbr = 'WY';
        otherwise
            disp( data{r,2}{1} );
            assert(false);
    end
    data{r,2}{1} = state_abbr;
end

rownames = unique( data{:,2} );

vartypes = cell(1, length(varnames));
for k = 1 : length( varnames )
    vartypes{k} = 'double';
end
outTable = table('Size', [length(rownames), length( varnames )], 'VariableType', vartypes, 'VariableNames', varnames, 'RowNames', rownames );

for k = 1 : size( data, 1 )
    varname = sprintf( 'x%02d_%02d', data{k,1}.Month, data{k,1}.Day );
    rowname = data{k, 2}{1};
    outTable(rowname, varname) = data(k,4);
end

dataDC = outTable;
for k = 1 : length(outTable.Properties.RowNames)
    sn = outTable.Properties.RowNames{k};
    temp = [0, outTable{sn, 2:end} - outTable{sn, 1:end-1}];
    if any(temp < 0)
        disp( [sn, ': ', num2str(sum(temp<0))] );
        temp = abs(temp); %% why absolute value?
    end
    dataDC{ sn, : } = temp;
end

dataLogDC = dataDC;
for k = 1 : length(dataLogDC.Properties.RowNames)
    sn = outTable.Properties.RowNames{k};
    flag = dataLogDC{ sn, : } > 0;
    dataLogDC{ sn, flag } = log( dataDC{sn, flag} );
end

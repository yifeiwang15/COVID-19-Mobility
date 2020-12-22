# COVID-19-Mobility
This is the MATLAB implementation of COVID-19 Trend Forecasting Using State-level Mobility and Policy.

This approach estimates the transmission rates via robust regression on local mobility statistics as well as local policies. Then the prediction of daily cases can be derived in an accumulated manner. Furthermore, a novel calibration step through solving an optimization problem is added to adjust the short-term influences of implicit population behaviors, like people's consciousness of sanitation and self-protection.



## Quick usage
This work uses matlab-R2020a for implementation. Run `run.m` to see the overall model performance on 51 states (including DC).

## Results
```
(Updated until 12.20)
Top: Prediction evaluations on nRMSE (Normalized rMSE) and relative accumulated log error (RALE). 
Bottom: Study of independent variables being identified as statistical significant.
```
![Overall performance](https://github.com/yifeiwang15/COVID-19-Mobility/blob/main/output.png)

```
One example showing the 14-day prediction of COVID-19 transmission rates and confirmed cases.
```
![Prediction visulization example](https://github.com/yifeiwang15/COVID-19-Mobility/blob/main/pred.png)


## Instructions to run
The `data` directory is expected to contain the following files: 
* 1 `us-states.csv` : [Daily confirmed cases](https://github.com/nytimes/covid-19-data).
* 2 `trips_state.csv`: The daily mobility file. Raw data is from [Trips by distance](https://data.bts.gov/Research-and-Statistics/Trips-by-Distance/w96p-f2qv) and is preprocessed by (Python 3.7):
```
import pandas as pd
import numpy as np
from datetime import datetime

df = pd.read_csv('Trips_by_Distance.csv')
state_table = df[df['Level']=='State']
dates = list(state_table['Date'])
check = [datetime.strptime(s, '%Y/%m/%d')>=datetime.strptime('2020/01/01', '%Y/%m/%d') for s in dates]
state_table = state_table.iloc[check, :]
state_table.to_csv('data/trips_state.csv',index=False)
```
After updating the lastest files for cases and mobility, run `run.m` to see the lastest prediction results and performance. 

# COVID-19-Mobility
This is the MATLAB implementation of COVID-19 Trend Forecasting Using State-level Mobility and Policy.

This approach estimates the transmission rates via robust regression on local mobility statistics as well as local policies. Then the prediction of daily cases can be derived in an accumulated manner. Furthermore, a novel calibration step through solving an optimization problem is added to adjust the short-term influences of implicit population behaviors, like people's consciousness of sanitation and self-protection. 

## Install
This work uses matlab-R2020a for implementation.

## Usage
Run run.m to see the overall model performance on 51 states (including DC).

% Example state matrix: Switches states when soft code 5 arrives.
%
% To send a soft code, you'll need access to the command line - so
% you can't use RunStateMachine(). Instead, create a TrialManagerObject:
% T = TrialManagerObject;
% Then, Run the state machine with:
% T.startTrial(sma);
% While the trial is running, send soft code 5 with:
% SendBpodSoftCode(5);
% When the trial is over, get the raw data with:
% RawEvents = T.getTrialData;
% Finally, clear the trial manager:
% clear T

sma = NewStateMatrix();

sma = AddState(sma, 'Name', 'Port1LightOn', ...
    'Timer', 1,...
    'StateChangeConditions', {'SoftCode5', 'Port3LightOn'},...
    'OutputActions', {'PWM1', 255});
sma = AddState(sma, 'Name', 'Port3LightOn', ...
    'Timer', 1,...
    'StateChangeConditions', {'Tup', '>exit'},...
    'OutputActions', {'PWM3', 255});
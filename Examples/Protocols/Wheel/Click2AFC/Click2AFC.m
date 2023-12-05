%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2022 Sanworks LLC, Rochester, New York, USA

----------------------------------------------------------------------------

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, version 3.

This program is distributed  WITHOUT ANY WARRANTY and without even the 
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
%}

function Click2AFC
% This protocol is a starting point for a stationary auditory 2AFC task, 
% using a wheel attached to a rotary encoder as the choice response interface.
% Each trial start is signaled via the Port 1 LED, and the subject must
% hold the wheel still until the LED turns off to continue the trial.
% Binaural streams of Poisson clicks are then played via the HiFi module's L+R channels. 
% The subject is rewarded for turning the wheel towards the faster-clicking side.
% Written by Josh Sanders, 6/2022.
%
% SETUP
% You will need:
% - A Bpod Finite State Machine (r1.0 or newer)
% - A Bpod Rotary Encoder Module (r2.0 or newer)
% - A Bpod HiFi module (r1.0 or newer)
% - A Bpod behavior port or lickometer
% - A port interface board
% - An amplified pair of speakers
% - A quadrature rotary encoder attached to a wheel the subject can turn to
%   indicate a choice
%
% > Connect the behavior port to the port interface board
% > Connect the port interface board to Behavior Port 1 on the state machine.
% > Connect the rotary encoder module to a state machine Module port.
% > Connect the HiFi module to a state machine Module port.
% > Connect the amplified speaker to the HiFi module
% > Connect the rotary encoder to the rotary encoder module
% > Make sure the liquid calibration table for port 1 has 
%   calibration curves with several points surrounding 3ul.
% > From the console, pair the HiFi and Rotary Encoder modules with their USB ports

global BpodSystem

%% Assert HiFi + Rotary Encoder modules are present + USB-paired (via USB button on console GUI)
BpodSystem.assertModule({'HiFi','RotaryEncoder'}, [1 1]); % The second argument [1 1] indicates that both HiFi and RotaryEncoder must be paired with their respective USB serial ports
% Create an instance of the HiFi module
H = BpodHiFi(BpodSystem.ModuleUSB.HiFi1); % The argument is the name of the HiFi module's USB serial port (e.g. COM3)
% Create an instance of the RotaryEncoder module
R = RotaryEncoderModule(BpodSystem.ModuleUSB.RotaryEncoder1); 
% Ensure Rotary Encoder module is version 2
if BpodSystem.Modules.HWVersion_Major(strcmp(BpodSystem.Modules.Name, 'RotaryEncoder1')) < 2
    error('Error: This protocol requires rotary encoder module v2 or newer');
end

%% Define task parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    S.GUI.RewardAmount = 3; %Unit = ?l
    S.GUI.InitDelay = 1; % How long the test subject must keep the wheel motionless to receive the stimulus. Unit = seconds
    S.GUI.ResponseTime = 5; % How long until the subject must make a choice, or forefeit the trial
    S.GUI.ErrorDelay = 3; % How long the subject must wait to start the next trial after an incorrect choice
    S.GUI.InitThreshold = 3; % How much the wheel may move during the initialization period without resetting the init delay. Units = degrees
    S.GUI.ChoiceThreshold = 40; % Wheel position in the correct or incorrect direction at which a choice is registered. Units = degrees (unsigned)
    S.GUI.StimTotalClickFreq = 100; % Total frequency of Poisson click generators on L+R channels. Unit = Hz
    S.GUI.StimSoundIntensity = 1; % Amplitude of the stimulus (poisson clicks). Unit = fraction of full-scale output of the audio system.
    S.GUI.ErrorSoundIntensity = 0.5; % White noise burst played on incorrect choice. Unit = fraction of full-scale output.
    S.GUI.NoiseMaskIntensity = 0.01; % A white noise mask that plays continuously. Unit = fraction of full-scale output.
    S.GUIPanels.Reward = {'RewardAmount'}; % GUIPanels organize the parameters into groups.
    S.GUIPanels.Time = {'InitDelay', 'ResponseTime', 'ErrorDelay'};
    S.GUIPanels.Wheel = {'InitThreshold', 'ChoiceThreshold'};
    S.GUIPanels.Sound = {'StimTotalClickFreq', 'StimSoundIntensity', 'ErrorSoundIntensity', 'NoiseMaskIntensity'};
    S.StimSamplingRate = 48000; % Sampling rate of audio. 48k is sufficient for poisson clicks, and reduces data synthesis + transfer time
end

%% Define trials
MaxTrials = 1000; % Maximum number of trials in the session. Session can be manually ended before MaxTrials from the console GUI.
TrialTypes = round(rand(1,MaxTrials)); % TrialType 0 = left correct, TrialType 1 = rightCorrect
EvidenceStrength = rand(1,MaxTrials); % Balance of underlying click rates favoring correct side. 0 = totally random, 
%                                       0.5 = 3x as many clicks on correct side, 1 = all clicks on correct side
%                                       Note: In production a uniform distrubution of EvidenceStrength results in too many easy trials.
CorrectDirection = TrialTypes; CorrectDirection(CorrectDirection == 0) = -1; % Correct response direction for each trial (-1 for left, 1 for right)
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
%-- Side outcome plot (a plugin included in the Bpod_Gen2 repository)
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [50 540 1100 250],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.08 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',TrialTypes);
%-- Last Trial encoder plot (an online plot included in the protocol folder)
BpodSystem.ProtocolFigures.EncoderPlotFig = figure('Position', [500 200 350 350],'name','Encoder plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.EncoderAxes = axes('Position', [.15 .15 .8 .8]);
LastTrialEncoderPlot(BpodSystem.GUIHandles.EncoderAxes, 'init', S.GUI.ChoiceThreshold);
%-- Parameter GUI
BpodParameterGUI('init', S); % Initialize parameter GUI plugin

%% Setup sound
% Configure HiFi module
H.SamplingRate = S.StimSamplingRate;
H.DigitalAttenuation_dB = -25; % Attenuate output (for headphones, for best results set to 0 in production and attenuate with speaker amp gain)
H.HeadphoneAmpEnabled = true; H.HeadphoneAmpGain = 25; % Configure headphone amplifier if using SD model
H.SynthWaveform = 'WhiteNoise'; % A synth waveform will be played continuously when other sounds are not playing
H.SynthAmplitude = S.GUI.NoiseMaskIntensity; % Set synth waveform intensity. The stimulus waveforms will have white noise added at this intensity 
                                             % for a seamless background noise mask
H.AMenvelope = 1/(H.SamplingRate*0.001):1/(H.SamplingRate*0.001):1; % Define 1ms linear envelope of amplitude coefficients, applied at sound onset 
                                                                    % + in reverse at sound offset. This helps avoid speaker 'pop'
% Generate feedback sounds for correct and error 
Background = GenerateWhiteNoise(H.SamplingRate, 0.3, S.GUI.NoiseMaskIntensity, 2);
CorrectSound = Background + [GenerateSineWave(H.SamplingRate, 1000, 0.1) GenerateSineWave(H.SamplingRate, 2000, 0.1) GenerateSineWave(H.SamplingRate, 3000, 0.1)];
ErrorSound = GenerateWhiteNoise(H.SamplingRate, S.GUI.ErrorDelay, S.GUI.ErrorSoundIntensity, 2);
% Load feedback sounds to the HiFi module
H.load(2, CorrectSound);
H.load(3, ErrorSound);
H.push; % Add any recently loaded sounds to the current sound set

%% Setup rotary encoder module
R.useAdvancedThresholds = 'on'; % Advanced thresholds are available on rotary encoder module r2.0 or newer.
                                % See notes in setAdvancedThresholds() function in /Modules/RotaryEncoderModule.m for parameters and usage
R.sendThresholdEvents = 'on'; % Enable sending threshold crossing events to state machine
R.startUSBStream; % Begin streaming position data to PC via USB

%% Main trial loop
for currentTrial = 1:MaxTrials
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    ValveTime = GetValveTimes(S.GUI.RewardAmount, 1); % Update reward amount
    [Waveform, WaveParams] = PoissonClickWaveform(EvidenceStrength(currentTrial)*CorrectDirection(currentTrial), S.GUI.StimTotalClickFreq, S.GUI.ResponseTime,...% First arg is the signed balance between click speed for L+R channels
                    H.SamplingRate, S.GUI.StimSoundIntensity, S.GUI.NoiseMaskIntensity); % Second arg: total click rate (Hz) to divide between L+R channels    
    
    H.load(1, Waveform); % Load this trial's Poisson click stream
    R.setAdvancedThresholds([-S.GUI.ChoiceThreshold S.GUI.ChoiceThreshold S.GUI.InitThreshold], [0 0 1], [0 0 S.GUI.InitDelay]); % Syntax: setAdvancedThresholds(thresholds, thresholdTypes, thresholdTimes)
    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 0
            LeftChoiceAction = 'LeftReward'; RightChoiceAction = 'Error'; 
        case 1
            LeftChoiceAction = 'Error'; RightChoiceAction = 'RightReward'; 
    end
    sma = NewStateMachine(); % Assemble new state machine description
    sma = SetCondition(sma, 1, 'Port1', 0); % Condition 1: Port 1 low (is out)
    sma = AddState(sma, 'Name', 'TrialStart', ...
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'ZeroEncoder'},...
        'OutputActions', {'HiFi1', '*', 'RotaryEncoder1', ['#' 0]}); 
    % 'HiFi1', '*' is equivalent to H.push() - adds any newly loaded sounds to the current sound set at their respective indexes
    % 'RotaryEncoder1' '#' marks a trial start timestamp in the rotary encoder data stream (for sync)
    % See https://sites.google.com/site/bpoddocumentation/user-guide/serial-interfaces for a list of all byte commands      
    sma = AddState(sma, 'Name', 'ZeroEncoder', ... % Turn on LED of port1. Wait for InitDelay seconds. Ensure that wheel does not move.
        'Timer', 0,...
        'StateChangeConditions', {'Tup', 'InitDelay'},...
        'OutputActions', {'RotaryEncoder1', '*Z'}); % '*' = push new thresholds to rotary encoder 'Z' = zero position  
    sma = AddState(sma, 'Name', 'InitDelay', ... % Turn on LED of port1. Wait for InitDelay seconds. Ensure that wheel does not move.
        'Timer', 0,...
        'StateChangeConditions', {'RotaryEncoder1_3', 'DeliverStimulus', 'RotaryEncoder1_4', 'DeliverStimulus'},...
        'OutputActions', {'LED', 1, 'RotaryEncoder1', [';' 4]}); % ';' = enable thresholds specified by bits of a byte. 4 = binary 100 (enable threshold# 3)                                      
    sma = AddState(sma, 'Name', 'DeliverStimulus', ...
        'Timer', S.GUI.ResponseTime,...
        'StateChangeConditions', {'RotaryEncoder1_1', LeftChoiceAction, 'RotaryEncoder1_2', RightChoiceAction, 'Tup', 'TimedOut'},...
        'OutputActions', {'RotaryEncoder1', ['Z;' 3], 'HiFi1', ['P' 0]}); % 'P' plays a sound, 0 is the sound index (sound 0 in Arduino is known in MATLAB as sound 1)
    sma = AddState(sma, 'Name', 'LeftReward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {'Valve1', 1, 'HiFi1', ['P' 1]}); % Sound 1 is reward feedback. Valve 1 is open during this state.
    sma = AddState(sma, 'Name', 'RightReward', ...
        'Timer', ValveTime,...
        'StateChangeConditions', {'Tup', 'Drinking'},...
        'OutputActions', {'Valve1', 1, 'HiFi1', ['P' 1]});
    sma = AddState(sma, 'Name', 'Drinking', ...
        'Timer', 0,...
        'StateChangeConditions', {'Condition1', 'DrinkingGrace', 'Condition2', 'DrinkingGrace'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'DrinkingGrace', ...
        'Timer', 0.5,...
        'StateChangeConditions', {'Tup', '>exit', 'Port1In', 'Drinking'},...
        'OutputActions', {});
    sma = AddState(sma, 'Name', 'Error', ...
        'Timer', S.GUI.ErrorDelay,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'HiFi1', ['P' 2]});
    sma = AddState(sma, 'Name', 'TimedOut', ...
        'Timer', S.GUI.ErrorDelay,...
        'StateChangeConditions', {'Tup', 'exit'},...
        'OutputActions', {'HiFi1', 'X'}); % 'X' cancels any ongoing sound on the HiFi module
    SendStateMachine(sma);
    RawEvents = RunStateMachine;
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.EvidenceStrength(currentTrial) = EvidenceStrength(currentTrial);
        BpodSystem.Data.CorrectDirection(currentTrial) = CorrectDirection(currentTrial);
        BpodSystem.Data.ClickWaveformParams{currentTrial} = WaveParams;
        BpodSystem.Data.EncoderData{currentTrial} = R.readUSBStream(); % Get rotary encoder data captured since last call to R.readUSBStream()
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        % Align this trial's rotary encoder timestamps to state machine trial-start (timestamp of '#' command sent from state machine to encoder module in 'TrialStart' state)
        BpodSystem.Data.EncoderData{currentTrial}.Times = BpodSystem.Data.EncoderData{currentTrial}.Times - BpodSystem.Data.EncoderData{currentTrial}.EventTimestamps(1); % Align timestamps to state machine's trial time 0
        BpodSystem.Data.EncoderData{currentTrial}.EventTimestamps = BpodSystem.Data.EncoderData{currentTrial}.EventTimestamps - BpodSystem.Data.EncoderData{currentTrial}.EventTimestamps(1); % Align event timestamps to state machine's trial time 0
        % Update rotary encoder plot
        TrialDuration = BpodSystem.Data.TrialEndTimestamp(currentTrial)-BpodSystem.Data.TrialStartTimestamp(currentTrial);
        LastTrialEncoderPlot(BpodSystem.GUIHandles.EncoderAxes, 'update', S.GUI.ChoiceThreshold, BpodSystem.Data.EncoderData{currentTrial},TrialDuration);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        H.stop; % Stop any ongoing sounds
        H.SynthAmplitude = 0; % Turn off white noise
        R.stopUSBStream; % Stop streaming positions from rotary encoder module
        return
    end
end
R.stopUSBStream;

function UpdateSideOutcomePlot(TrialTypes, Data) 
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials % Encode user data for side outcome plot plugin
    if ~isnan(Data.RawEvents.Trial{x}.States.Drinking(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Error(1))
        Outcomes(x) = 0;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.TimedOut(1))
        Outcomes(x) = 2;
    else
        Outcomes(x) = 3;
    end
end
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes);
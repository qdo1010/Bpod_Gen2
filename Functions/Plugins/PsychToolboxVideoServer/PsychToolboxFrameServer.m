% This class can store a library of up to 255 video frames, and display them when
% called by index. It assumes the PC has a second monitor.

% Usage:
% F = PsychToolboxFrameServer;
% MyFrame = round(rand(F.WindowSize(2),F.WindowSize(1)))*255; % Example frame. Frames must be matrices equal to the detected window dimensions in pixels. Each pixel brightness is in range [0-255]
% F.loadFrame(2, MyFrame); % Load MyFrame to position 2
% F.showFrame(2); % Shows Frame 2 on the screen
% F.showFrame(0); % Clears the screen

classdef PsychToolboxFrameServer < handle
    properties
        WindowSize % Auto-detected Window Resolution
    end
    properties (Access = private)
        Window % PsychToolbox Window object
        BlankScreen % A black screen matching the size of the monitor
        FrameTextures = cell(1,255);
    end
    methods  
        function obj = PsychToolboxFrameServer(varargin)
            Screen('Preference','SkipSyncTests', 1);
            [obj.WindowSize(1), obj.WindowSize(2)]=Screen('WindowSize', 2);
            obj.Window = Screen('OpenWindow',2);
            Frame = zeros(obj.WindowSize(2), obj.WindowSize(1));
            obj.BlankScreen = Screen('MakeTexture', obj.Window, Frame);
            Screen('DrawTexture', obj.Window, obj.BlankScreen);
            Screen('Flip', obj.Window);
        end
        function loadFrame(obj, frameIndex, frameData)
            if frameIndex < 1
                error('Error: frameIndex must be a positive integer');
            end
            Dims = size(frameData);
            if (Dims(1) ~= obj.WindowSize(2)) || (Dims(2) ~= obj.WindowSize(1))
                error(['Error: Frame matrices must be ' num2str(obj.WindowSize(2)) ' x ' num2str(obj.WindowSize(1))])
            end
            obj.FrameTextures{frameIndex} = Screen('MakeTexture', obj.Window, frameData);
        end
        function showFrame(obj,frameIndex)
            if frameIndex == 0
              Screen('DrawTexture', obj.Window, obj.BlankScreen);  
            else
                if isempty(obj.FrameTextures{frameIndex})
                    error(['Error: No frame loaded at position ' num2str(frameIndex) '.'])
                else
                    Screen('DrawTexture', obj.Window, obj.FrameTextures{frameIndex});
                end
            end
            Screen('Flip', obj.Window);
        end
        function delete(obj)
            Screen('CloseAll');
        end
    end
end
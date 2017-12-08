%{
----------------------------------------------------------------------------

This file is part of the Sanworks Bpod repository
Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

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

% This class controls the Bpod Ethernet module, with its EthernetModule firmware.
% Note: This class is NOT used if the module has SM_Via_Ethernet firmware.

% The Ethernet module runs an Ethernet server, for remote configuration. This 
% class connects to the Ethernet module as a client, to configure it before the 
% behavior session (or between trials). The module can also be configured 
% via USB like all other Bpod modules, if the object is initialized with a USB 
% port instead of an IP address.
% 
% The Ethernet module can connect to other instruments on
% the local network, acting as a client. Using this class, you can load
% a library of up to 255 byte-strings to control networked instruments.
% Each byte string has an index. During a trial, when the state machine sends 
% byte message ['M' Index] to the Ethernet module, the Ethernet module sends the
% message at position (Index) to the message's associated instrument with 
% low latency. Actual transmission time depends on network and remote server 
% configuration, but can be < 1ms.

classdef EthernetModule < handle
    properties
        Port % ArCOM Object wrapping USB or TCP/IP interface
        
    end
    properties (SetAccess = protected)
        FirmwareVersion = 0; % Firmware version of the Ethernet module
        IP % IP address of the Ethernet module
    end
    properties (Access = private)
        ModuleTCPPort = 11258; % Standard TCP port for Bpod Ethernet module
        CurrentFirmwareVersion = 1;
        Initialized = 0; % Set to 1 after constructor finishes running
    end
    methods
        function obj = EthernetModule(IPstring)
            obj.Port = ArCOMObject_Bpod(IPstring, 115200);
            obj.Port.write('H', 'uint8'); % Handshake
            response = obj.Port.read(1, 'uint8');
            if response ~= 'K'
                error(['Error: Device at IP:' IPstring ' did not return the correct handshake byte.'])
            end
            obj.Port.write('F', 'uint8'); % Get Firmware
            obj.FirmwareVersion = obj.Port.read(1, 'uint32');
            if obj.FirmwareVersion < obj.CurrentFirmwareVersion
                error(['Error: old firmware detected - v' obj.FirmwareVersion '. The current version is: ' obj.CurrentFirmwareVersion '. Please update the I2C messenger firmware using Arduino.'])
            end
            obj.Initialized = 1;
        end
        function obj = connect2Server(obj, IPstring, serverPort) % Connect as a client, to a remote server
            % IPstring is the remote instrument's IP address (given as a character string)
            % serverPort is the remote instrument's port (given as a double)
            IPbytes = obj.IPstring2Bytes(IPstring);
            serverPort = uint32(serverPort);
            obj.Port.write(['C' IPbytes serverPort], 'uint8');
            obj.receiveACK();
        end
        function obj = disconnectFromServer(obj, IPstring) % Disconnect from a remote server
            
        end
        function obj = loadMessage(obj, messageIndex, messageBytes, messageRemoteIP, messageRemotePort) 
            % Loads a single message destined for a single instrument to the module's message library
            % messageIndex is the index of the message (in range 0-255)
            % messageBytes is a string of bytes to send to the remote instrument
            % messageRemoteIP is an IP address (given as a character string) for the message.
            % messageRemotePort is a port (given as a double) for the message.
            
        end
        function obj = loadMessages(obj, messageCellArray, messageRemoteIPs, messageRemotePorts) 
            % Loads several messages at once, message index = position in cell array
            % messageRemoteIPs is a cell array of IP addresses (character strings) for each message.
            % messageRemotePorts is a cell array of ports (double type) for each message.
            
        end
        function delete(obj)
            obj.Port = []; % Trigger the ArCOM port's destructor function (closes and releases port)
        end
    end
    methods (Access = private)
        function Bytes = IPstring2Bytes(obj, IPstring)
            Dots = find(IPstring == '.');
            if length(Dots) ~= 3
                error('Error: The remote IP address must be of the form: W.X.Y.Z, where W,X,Y and Z are in range 0-255') 
            end
            % Actually convert!
        end
        function receiveACK(obj)
            Confirmed = obj.Port.read(1, 'uint8');
            if Confirmed ~= 1
                error('Error: The Ethernet module did not confirm the last instruction sent.');
            end
        end
    end
end
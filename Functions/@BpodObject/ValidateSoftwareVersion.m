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
function ValidateSoftwareVersion(obj)
Ver = BpodSoftwareVersion;
latestVersion = [];
[reply, status] = urlread(['https://raw.githubusercontent.com/sanworks/Bpod_Gen2/master/Functions/Internal%20Functions/BpodSoftwareVersion.m']);
verPos = find(reply == '=');
if ~isempty(verPos)
    verString = strtrim(reply(verPos(end)+1:end-1));
    latestVersion = str2double(verString);
end

if ~isempty(latestVersion)
    if Ver < latestVersion  
        disp( '***********************************************************')
        disp(['UPDATE NOTICE: Bpod Console v' sprintf('%3.2f', latestVersion) ' is available to download!'])
        disp( '***********************************************************')
    elseif Ver > latestVersion
        disp( '***********************************************************')
        disp(['NOTE: You are running a dev version of Bpod Console: ' sprintf('%3.2f', Ver) char(10)...
              'The latest stable release is: ' sprintf('%3.2f', latestVersion)])
        disp( '***********************************************************')
    end
end
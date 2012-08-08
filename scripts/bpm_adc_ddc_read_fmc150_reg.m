function [msg_type, valid_bytes, reg_value] = bpm_adc_ddc_read_fmc150_reg(chipselect, addr, verbose, timeout)
%   [msg_type, valid_bytes, reg_value] =
%       bpm_adc_ddc_read_fmc150_reg(chipselect, addr, verbose, timeout)
%
%   Script for reading FMC150 internal registers
%
%   ------------
%   |   Input  |
%   -----------------------------------------------------------------------
%   chipselect : FMC150 component selection. 
%                   -> 0x1 for CHIPSELECT_CDCE72010
%                   -> 0x2 for CHIPSELECT_ADS62P49
%                   -> 0x4 for CHIPSELECT_DAC3283
%                   -> 0x8 for CHIPSELECT_AMC7823
%   addr       : Address of the internal chip register selected.
%                   See components datasheet for more information.
%   verbose    : Enables debug information.
%                   -> '1' to few messages
%                   -> '2' to additional messages
%   timeout    : Maximum time (in miliseconds) to wait for a response from
%                   the BPM server
%   -----------------------------------------------------------------------
%   ------------
%   |  Output  |
%   -----------------------------------------------------------------------
%   msg_type    : Message type .
%                   -> 1: ASCII string
%                   -> 2: Register value
%   valid_bytes : Number of valid bytes in the last packet of the 
%                   transaction. Usually ignored.
%   value       : Requested register value
%   -----------------------------------------------------------------------

import java.net.Socket;
import java.net.InetSocketAddress; 
import java.io.*;

RESPONSE_PACKET_HEADER_SIZE = 8;
RESPONSE_PACKET_BUF_SIZE = 4096;
RESPONSE_PACKET_SIZE = (RESPONSE_PACKET_HEADER_SIZE + RESPONSE_PACKET_BUF_SIZE);
FMC150_READ_COMMAND = 4;

% default bpm server parameters
r.bpm_server.ip_address   = '10.0.18.100';
r.bpm_server.ip_port      = '8006';

% default value for verbose parameter
if (nargin < 4)
    timeout = 5000;                 % Set to zero to infinite wait
    if (nargin < 3)
        verbose = 0; 
    end
end

% Builds a socket address
socketAddress = InetSocketAddress(r.bpm_server.ip_address, str2double(r.bpm_server.ip_port)); 
% Unconnected socket
skt = Socket();

try
    skt.connect(socketAddress,timeout); 
catch err
    % Checks for timeout error and try again?'
    % Print error
    fprintf(1, '%s\n', err.identifier);
    error('TCP connection timeout');
end

if verbose
    fprintf(1, 'Connected to server\n');
end

% Get Socket I/O Stream          
r.bpm_server.socket.link.in = skt.getInputStream();
r.bpm_server.socket.link.intput_stream = DataInputStream(r.bpm_server.socket.link.in);
r.bpm_server.socket.link.data_reader = DataReader(r.bpm_server.socket.link.intput_stream);
r.bpm_server.socket.link.out = skt.getOutputStream();
r.bpm_server.socket.link.output_stream = DataOutputStream(r.bpm_server.socket.link.out);

% Builds packet to be sent over socket
packet  = typecast([uint8(0), uint8(0), uint8(0), uint8(FMC150_READ_COMMAND), ...
                    uint8(0), uint8(0), uint8(0), uint8(chipselect), ...
                    uint8(0), uint8(0), uint8(0), uint8(addr), ...
                    uint8(0), uint8(0), uint8(0), uint8(0)], 'uint8');

if verbose
    fprintf(1, 'Writing %d bytes\n', length(packet));
end

% Sends packet over socket
for i = 1:length(packet)
    r.bpm_server.socket.link.output_stream.writeByte(packet(i));
end
r.bpm_server.socket.link.output_stream.flush;

% Receive response packet of data
total_bytes_to_receive = sizeof('int32');
total_bytes_received = 0;

% pre allocate space
msg_data_in = int8(zeros(1, RESPONSE_PACKET_SIZE));                     % Raw data from socket
msg_header = int8(zeros(1, RESPONSE_PACKET_HEADER_SIZE));               % Packet header
% Position Calculation Data out
reg_value = uint32(zeros(1, sizeof('uint32')));

while( total_bytes_received < total_bytes_to_receive ) 
    try
        % While no header available
        bytes_available = r.bpm_server.socket.link.in.available();
        while(bytes_available < RESPONSE_PACKET_HEADER_SIZE)
            pause(1);
            bytes_available = r.bpm_server.socket.link.in.available();
            %fprintf(1, 'Reading %d bytes\n', bytes_available);
        end

        if verbose
            fprintf(1, '------------------------------\n%d bytes avaiable for header reading\n', bytes_available);
        end

        % Read header bytes from socket
        %for i = 1:RESPONSE_PACKET_HEADER_SIZE
        %    msg_data_in(i) = r.bpm_server.socket.link.intput_stream.readByte;
        %end
        msg_data_in = r.bpm_server.socket.link.data_reader.readBuffer(RESPONSE_PACKET_HEADER_SIZE);
             
        if verbose
            fprintf(1, 'Read %d bytes from socket\n', RESPONSE_PACKET_HEADER_SIZE);
        end

        % Convert header to big endian (unpack)
        for i = 1:(RESPONSE_PACKET_HEADER_SIZE/2)
            msg_header(i) = msg_data_in(4-i+1);
            msg_header(i+4) = msg_data_in(4-i+5);
        end

        msg_type = typecast(msg_header(1:4), 'uint32');
        valid_bytes = typecast(msg_header(5:8), 'uint32');
        
        if verbose
            fprintf(1, 'Message type = %u\n', msg_type);
            fprintf(1, 'Valid bytes = %u\n', valid_bytes);
        end

        % Wait for payload
        bytes_available = r.bpm_server.socket.link.in.available();
        while(bytes_available < valid_bytes)
            pause(1);
            bytes_available = r.bpm_server.socket.link.in.available();
            %fprintf(1, 'Reading %d bytes\n', bytes_available);
        end
   
        if verbose
            fprintf(1, '%d bytes avaiable for payload reading\n', bytes_available);
            fprintf(1, 'Read %d bytes from socket\n', valid_bytes);
        end
        
        %for i = 1:valid_bytes
        %    msg_data_in(i) = r.bpm_server.socket.link.intput_stream.readByte;
        %end
        msg_data_in = r.bpm_server.socket.link.data_reader.readBuffer(valid_bytes);

        % Output register value to variable reg_value
        reg_value = typecast(msg_data_in(1:4), 'uint32');

        total_bytes_received = total_bytes_received + valid_bytes;

        if verbose
            fprintf(1, 'Accumulated payload bytes received = %u\n------------------------------\n', total_bytes_received);
        end

        % Print error or verbose messages
        if (msg_type == 1)
            fprintf('BPM acquisition error: %s\n', char(msg_data_in));
            break;
         % Only prints the data if requested by user
        elseif verbose == 2
            % print data
            fprintf(1, 'reg @0x%08X: 0x%08X\n', addr, reg_value);
        end
    catch err
        if ~isempty(skt)
            skt.close;
        end

        % Print error
        fprintf(1, '%s\n', err.identifier);

        % Try to acquire data again
        pause(1);
    end
end

% End gracefully
skt.close;
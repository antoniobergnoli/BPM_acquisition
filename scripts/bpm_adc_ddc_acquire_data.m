function [msg_type, valid_bytes, dma_ovf, adc_a, adc_b, sum, pos_x, pos_y, pos_z] = bpm_adc_ddc_acquire_data(nr_samples, which, verbose, timeout)
%   [msg_type, valid_bytes, adc_a, adc_b, sum, pos_x, pos_y, pos_z] =
%       bpm_adc_ddc_acquire_data(nr_samples, which, verbose, timeout)
%
%   Script de comunicação com servidor BPM para aquisição de dados
%
%   ------------
%   |   Input  |
%   -----------------------------------------------------------------------
%   nr_samples : Número de amostras a serem adquiridas. Limitada de acordo 
%                   com o parâmetro 'which'.
%                   -> 2097152 amostras para dados advindos do ADC
%                       (which = 1)
%                   -> 524288 amostras para dados advindos do processamento
%                       de posição (which = 2)
%   which      : Seleção do tipo de dado.
%                   -> '1' para dados advindos do ADC (Raw ADC Data)
%                   -> '2' para dados advindos do processamento de posição
%                       (DDC + Delta Over Sigma)
%   verbose    : Habilita modo com informações de debug.
%                   -> '1' para poucas informações
%                   -> '2' para informações adicionais
%   timeout    : Tempo maximo à espera da conexão TCP com o servidor BPM
%   -----------------------------------------------------------------------
%   ------------
%   |  Output  |
%   -----------------------------------------------------------------------
%   msg_type    : Tipo da mensagem contida no pacote de retorno.
%                   Normalmente ignorado.
%                   -> 1: Mensagem (string) em formato padrão ASCII
%                   -> 2: Valor de registrador
%                   -> 3: Novos dados advindos do ADC. Nova Transação
%                   -> 4: Dados do ADC pertencentes à uma transação anterior
%                   -> 5: Novos dados advindos do processamento de posição
%                   -> 6: Dados do processamento de posição
%                           pertencentes à uma transação anterior
%   valid_bytes : Número de bytes válidos no último pacote da transação.
%                   Normalmente ignorado.
%   dma_ovf     : Indica se houve overflow na operação de aquisição.
%                   -> 0: Overflow não detectado
%                   -> 1: Overflow detectado
%   adc_a       : Dados referentes ao canal A do ADC
%   adc_b       : Dados referentes ao canal B do ADC
%   sum         : Soma dos quatro canais de medidas de posição.
%   pos_x       : Medida de posição no eixo x
%   pos_y       : Medida de posição no eixo y
%   pos_z       : Medida de posição no eixo z
%   -----------------------------------------------------------------------

import java.net.Socket;
import java.net.InetSocketAddress; 
import java.io.*;

RESPONSE_PACKET_HEADER_SIZE = 8;
RESPONSE_PACKET_BUF_SIZE = 4096;
RESPONSE_PACKET_SIZE = (RESPONSE_PACKET_HEADER_SIZE + RESPONSE_PACKET_BUF_SIZE);
TWO_EXP_26 = 67108864;
% Bits in Matlab starts at 1, not at 0 as VHDL
DEVICE_DMA_COMPLETE_BIT = 1;
DEVICE_DMA_OVF_BIT = 2;
% BPM sensitivity
KX = 10000;
KY = 10000;
KZ = 10000;
%COMMAND_PACKET_SIZE = 16;

% default bpm server parameters
r.bpm_server.ip_address   = '10.0.18.100';
r.bpm_server.ip_port      = '8006';

% default value for verbose parameter
if (nargin < 4)
    timeout = 5000;                 % Set to zero to infinite wait
    if (nargin < 3)
        verbose = 0; 
        if(nargin < 2 || which ~= 1 || which ~= 2)
            which = 1;              % set to 1 for ADC, 2 for DDC
        end
    end
end

% Low level to the max! FIX!
if which == 1                           % RAW ADC Data
    GET_SAMPLES_COMM = 3;
    SAMPLE_SIZE = 4;                    % Sample size in bytes
    % Base Device Addresses
    DEVICE_BASEADDR = uint32(hex2dec('71000000'));
    % Register Offset. "0000000001"
    DEVICE_STATUS_REG = 4*uint32(hex2dec('9'));
elseif which == 2                       % Position Calculation Data
    GET_SAMPLES_COMM = 7;
    SAMPLE_SIZE = 16;                   % Sample size in bytes
    % Base Device Addresses
    DEVICE_BASEADDR = uint32(hex2dec('7E820000'));
    % Register Offset. "0100000000"
    DEVICE_STATUS_REG = 4*uint32(hex2dec('1'));
end

% Convert nr_samples to byte vector
samples = typecast(uint32(nr_samples), 'uint8');
samples_packed = zeros(1,length(samples),'uint8');

% Convert (pack) to little endian
for i = 1:length(samples)
    samples_packed(i) = samples(length(samples)-i+1);
end

% Clear status regs
%[~, ~, msg_out] = bpm_adc_ddc_write_soft_reg(DEVICE_BASEADDR + DEVICE_STATUS_REG, 0);
%disp(char(msg_out));

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
    error('TCP connection timeout\n');
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
packet  = typecast([uint8(0), uint8(0), uint8(0), uint8(GET_SAMPLES_COMM), ...
                    uint8(0), uint8(0), uint8(0), uint8(0), ...
                    uint8(0), uint8(0), uint8(0), uint8(0), ...
                    samples_packed], 'uint8');

if verbose
    fprintf(1, 'Writing %d bytes\n', length(packet));
end

% Sends packet over socket
for i = 1:length(packet)
    r.bpm_server.socket.link.output_stream.writeByte(packet(i));
end
r.bpm_server.socket.link.output_stream.flush;

% Receive response packet of data
total_bytes_to_receive = uint32(nr_samples)*SAMPLE_SIZE;
total_bytes_received = 0;

% pre allocate space
msg_data_in = int8(zeros(1, RESPONSE_PACKET_SIZE));                     % Raw data from socket
msg_header = int8(zeros(1, RESPONSE_PACKET_HEADER_SIZE));               % Packet header
% Position Calculation Data out
sum = int32(zeros(1, ceil(double(total_bytes_to_receive)/SAMPLE_SIZE)));         % Samples
pos_x = single(zeros(1, ceil(double(total_bytes_to_receive)/SAMPLE_SIZE)));         % Samples
pos_y = single(zeros(1, ceil(double(total_bytes_to_receive)/SAMPLE_SIZE)));         % Samples
pos_z = single(zeros(1, ceil(double(total_bytes_to_receive)/SAMPLE_SIZE)));         % Samples
pos_x_temp = single(zeros(1, ceil(double(total_bytes_to_receive)/SAMPLE_SIZE)));         % Samples
pos_y_temp = single(zeros(1, ceil(double(total_bytes_to_receive)/SAMPLE_SIZE)));         % Samples
pos_z_temp = single(zeros(1, ceil(double(total_bytes_to_receive)/SAMPLE_SIZE)));         % Samples
% RAW ADC Data out
adc_a = int16(zeros(1, ceil(double(total_bytes_to_receive)/SAMPLE_SIZE)));         % Samples
adc_b = int16(zeros(1, ceil(double(total_bytes_to_receive)/SAMPLE_SIZE)));         % Samples

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
        
         % Read payload bytes from socket. TODO: Implement a java wrapper
         % class to read all bytes at once
        %for i = 1:valid_bytes
        %    msg_data_in(i) = r.bpm_server.socket.link.intput_stream.readByte;
        %end
        msg_data_in = r.bpm_server.socket.link.data_reader.readBuffer(valid_bytes);

        % Just group the raw bytes into 16-bit data.
        % Odd indexes(1,3,5,...)   |     Even Indexes(2,4,6,...)
        % Channel A                |     Channel B
		% Conversion from fixed point FIX26_24 to decimal (double)
        if which == 1           % ADC
            for i = 1:(valid_bytes/SAMPLE_SIZE)
                adc_a(i+(total_bytes_received/SAMPLE_SIZE)) = typecast(msg_data_in((i-1)*SAMPLE_SIZE+3:(i-1)*SAMPLE_SIZE+4), 'int16');
                adc_b(i+(total_bytes_received/SAMPLE_SIZE)) = typecast(msg_data_in((i-1)*SAMPLE_SIZE+1:(i-1)*SAMPLE_SIZE+2), 'int16');
            end
        elseif which == 2       % DDC
            for i = 1:(valid_bytes/SAMPLE_SIZE)
                sum(i+(total_bytes_received/SAMPLE_SIZE)) = (typecast(msg_data_in((i-1)*SAMPLE_SIZE+13:(i-1)*SAMPLE_SIZE+16), 'int32'));
                pos_x_temp(i+(total_bytes_received/SAMPLE_SIZE)) = single(typecast(msg_data_in((i-1)*SAMPLE_SIZE+9:(i-1)*SAMPLE_SIZE+12), 'int32'))/TWO_EXP_26;
                pos_y_temp(i+(total_bytes_received/SAMPLE_SIZE)) = single(typecast(msg_data_in((i-1)*SAMPLE_SIZE+5:(i-1)*SAMPLE_SIZE+8), 'int32'))/TWO_EXP_26;
                pos_z_temp(i+(total_bytes_received/SAMPLE_SIZE)) = single(typecast(msg_data_in((i-1)*SAMPLE_SIZE+1:(i-1)*SAMPLE_SIZE+4), 'int32'))/TWO_EXP_26;
            end   
            
            % Account for BPM sensitivity
            pos_x = KX.*pos_x_temp;
            pos_y = KY.*pos_y_temp;
            pos_z = KZ.*pos_z_temp; 
        end

        total_bytes_received = total_bytes_received + valid_bytes;

        if verbose
            fprintf(1, 'Accumulated payload bytes received = %u\n------------------------------\n', total_bytes_received);
        end

        % Print error or verbose messages
        if (msg_type == 1)
            fprintf('BPM acquisition error: %s\n', char(msg_data_in(1:end)));
            break;
         % Only prints the data if requested by user
        elseif (verbose == 2)
            if which == 1          %% ADC
                for i = 1:(uint32(total_bytes_received)/SAMPLE_SIZE)
                    % print data
                    fprintf(1, '%d:\t%5d\t%5d\n', i, adc_a(i), adc_b(i));
                end   
            elseif which == 2      %% DDC
                for i = 1:(uint32(total_bytes_received)/SAMPLE_SIZE)
                    % print data
                    fprintf(1, '%d:\t%f\t%f\%f\n', i, pos_x(i), pos_y(i), pos_z(i));
                end
            end
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

% Check for DMA overflow
%[~, ~, status_reg] = bpm_adc_ddc_read_soft_reg(DEVICE_BASEADDR + DEVICE_STATUS_REG);
%disp(status_reg);
dma_ovf = 0;%bitget(uint32(status_reg), DEVICE_DMA_OVF_BIT);

%if (dma_ovf == 1)
%    disp('DMA Overflow detected! Data might be corrupted');
%end

% End gracefully
skt.close;
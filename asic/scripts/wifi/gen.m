%% Wi-Fi IQ Test Vector Generator
%
% Generates a complete IEEE 802.11 Wi-Fi packet, adds noise, and creates
% an 8-bit signed I/Q test vector suitable for FPGA/RTL simulation.
%
% Output format:
%   I0, Q0, I1, Q1, I2, Q2, ...
%
% Sample rate:
%   20 MSPS complex baseband
%
% Requires:
%   MATLAB
%   WLAN Toolbox
%
% Output:
%   wifi_iq.bin

clear;
clc;
close all;

%% Configuration

% Wi-Fi configuration
cfg = wlanNonHTConfig;

cfg.MCS = 3;
cfg.ChannelBandwidth = 'CBW20';
cfg.PSDULength = 100;       % PSDU length in bytes

% IQ quantization
IQ_WIDTH = 8;

% Noise before/after packet
NUM_NOISE_BEFORE = 5000;
NUM_NOISE_AFTER  = 5000;

% AWGN applied to the Wi-Fi packet
SNR_DB = 20;

% Random seed for repeatable test vectors
rng(1);

%% Generate random Wi-Fi payload

% PSDU is specified as bits
psdu = randi([0 1], cfg.PSDULength * 8, 1);

%% Generate complete Wi-Fi waveform

% tx is complex baseband IQ data
tx = wlanWaveformGenerator(psdu, cfg);

% Normalize the packet
tx = tx / max(abs(tx));

%% Add AWGN to the Wi-Fi packet

rx_packet = awgn(tx, SNR_DB, 'measured');

%% Generate noise before and after the packet

noise_before = 0.02 * ...
    (randn(NUM_NOISE_BEFORE, 1) + ...
     1j * randn(NUM_NOISE_BEFORE, 1));

noise_after = 0.02 * ...
    (randn(NUM_NOISE_AFTER, 1) + ...
     1j * randn(NUM_NOISE_AFTER, 1));

%% Create complete received sample stream

rx = [
    noise_before
    rx_packet
    noise_after
];

%% Normalize complete waveform

% Keep the waveform safely inside the signed 8-bit range.
rx = rx / max(abs(rx));

%% Convert complex IQ to signed integers

MAX_VALUE = 2^(IQ_WIDTH - 1) - 1;

I = int8(round(real(rx) * MAX_VALUE));
Q = int8(round(imag(rx) * MAX_VALUE));

%% Interleave I and Q

% Output:
%
%   I0
%   Q0
%   I1
%   Q1
%   I2
%   Q2
%   ...

iq = zeros(2 * length(rx), 1, 'int8');

iq(1:2:end) = I;
iq(2:2:end) = Q;

%% Write binary IQ file

filename = 'wifi_iq.bin';

fid = fopen(filename, 'wb');

if fid == -1
    error('Could not open output file.');
end

fwrite(fid, iq, 'int8');

fclose(fid);

%% Display information

sample_rate = wlanSampleRate(cfg);

fprintf('\n');
fprintf('========================================\n');
fprintf(' Wi-Fi IQ Test Vector\n');
fprintf('========================================\n');
fprintf('Sample rate       : %.2f MSPS\n', sample_rate / 1e6);
fprintf('IQ width          : %d bits\n', IQ_WIDTH);
fprintf('MCS               : %d\n', cfg.MCS);
fprintf('Bandwidth         : %s\n', cfg.ChannelBandwidth);
fprintf('PSDU length       : %d bytes\n', cfg.PSDULength);
fprintf('SNR               : %.1f dB\n', SNR_DB);
fprintf('Packet samples    : %d\n', length(tx));
fprintf('Noise before      : %d samples\n', NUM_NOISE_BEFORE);
fprintf('Noise after       : %d samples\n', NUM_NOISE_AFTER);
fprintf('Total samples     : %d\n', length(rx));
fprintf('Output file       : %s\n', filename);
fprintf('========================================\n');

%% Plot I/Q waveform

figure;

subplot(2,1,1);
plot(I);
grid on;
title('Received I Samples');
xlabel('Sample');
ylabel('Amplitude');

subplot(2,1,2);
plot(Q);
grid on;
title('Received Q Samples');
xlabel('Sample');
ylabel('Amplitude');

%% Plot magnitude

figure;

plot(abs(rx));
grid on;

title('Wi-Fi IQ Magnitude');
xlabel('Sample');
ylabel('|IQ|');

%% Plot constellation

figure;

% Only plot packet samples so the surrounding noise does not dominate.
plot(real(rx_packet), imag(rx_packet), '.');

axis equal;
grid on;

title('Wi-Fi Packet IQ');
xlabel('I');
ylabel('Q');

%% Mark packet boundaries

packet_start = NUM_NOISE_BEFORE + 1;
packet_end = packet_start + length(rx_packet) - 1;

fprintf('\nPacket starts at sample : %d\n', packet_start);
fprintf('Packet ends at sample   : %d\n', packet_end);
fprintf('Packet length           : %d samples\n', length(rx_packet));

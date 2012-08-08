function [adc_a, adc_b, sum, pos_x, pos_y, pos_z] = bpm_adc_ddc_plot_data(nr_samples, fadc, which, nr_iterations, verbose)
%   [adc_a, adc_b, sum, pos_x, pos_y, pos_z] =
%       bpm_adc_ddc_plot_data(nr_samples, fadc, which, nr_iterations, verbose)
%
%   Plot script for BPM data
%
%   ------------
%   |   Input  |
%   -----------------------------------------------------------------------
%   nr_samples : Number of samples to be acquired. Bounded to parameter 
%                   'which'
%                   -> 2097152 samples to data from ADC (which = 1)
%                   -> 524288 samples to data data from Position 
%                       Calculation (which = 2)
%   fadc       : ADC Sampling frequency (MHz). Only used for accurate axis 
%                   information
%   which      : Data type selection.
%                   -> '1' to data from ADC (Raw ADC Data)
%                   -> '2' to data from Postition Calculation processing
%                       (DDC + Delta Over Sigma)
%   nr_iterations : Number of consecutive plots
%                   -> < 0 for continuous plot
%                   -> > 0 for a specific numver of plots
%   verbose    : Enables debug information.
%                   -> '1' to few messages
%                   -> '2' to additional messages
%   -----------------------------------------------------------------------
%   ------------
%   |  Output  |
%   -----------------------------------------------------------------------
%   adc_a       : Channel A RAW ADC Data.
%   adc_b       : Channel B RAW ADC Data.
%   sum         : Sum of the four ADC channels.
%   pos_x       : X axis position measurement
%   pos_y       : Y axis position measurement
%   pos_z       : Z axis position measurement
%   -----------------------------------------------------------------------    

n_bits = 14;
adc_a_fullscale = 2^(n_bits-1);
adc_b_fullscale = 2^(n_bits-1);

% default value for verbose parameter
if (nargin < 5)
    verbose = 0;
    if (nargin < 4)
        nr_iterations = 10;                 % Set to negative to infinite interations
        if (nargin < 3 || which ~= 1 || which ~= 2) 
            which = 1;                    % set to 1 for ADC, 2 for DDC
        end
    end
end

if (nr_iterations < 0)
    nr_iterations = 1;
    decrement = 0;
else
    decrement = 1;
end

while (nr_iterations > 0)
    % Acquire data
    [type, ~, ~, adc_a, adc_b, sum, pos_x, pos_y, pos_z] = bpm_adc_ddc_acquire_data(nr_samples, which, verbose);

    % if type is 1 there ir nothing to plot
    if type == 1
        break;
    end

    % Plot BPM data separately
    figure(1);

    if which == 1
        % Time Domain Channel A ADC Plot
        a = subplot(2,2,1); plot(adc_a);
        title(a, 'Channel A Time Domain Plot');
        xlabel(a, 'Sample number');
        ylabel(a, 'Magnitude (ADC counts)');

        % Frequency Domain Channel A ADC Plot
        npts=length(adc_a);
        y = double(adc_a)/adc_a_fullscale;
        window = hann(npts)';
        fft_y=abs(fft(y.*window));
        npts_plot=ceil((npts+ 1)/2);
        freq = linspace(0, fadc, npts+1);
        b = subplot(2,2,2); plot(freq(1:npts_plot),10*log10(2/npts*fft_y(1:npts_plot)));
        title(b, 'Channel A Frequency Domain Plot');
        xlabel(b, 'Frequency (MHz)');
        ylabel(b, 'Magnitude (dB)');
        axis([0 freq(npts_plot) -80 0]);

        % Time Domain Channel B ADC Plot
        c = subplot(2,2,3);  plot(adc_b);
        title(c, 'Channel B Time Domain Plot');
        xlabel(c, 'Sample number');   
        ylabel(c, 'Magnitude (ADC counts)');

        % Frequency Domain Channel B ADC Plot
        npts=length(adc_b);
        y = double(adc_b)/adc_b_fullscale;
        window = hann(npts)';
        fft_y=abs(fft(y.*window));
        npts_plot=ceil((npts+ 1)/2);
        freq = linspace(0, fadc, npts+1);
        d = subplot(2,2,4); plot(freq(1:npts_plot),10*log10(2/npts*fft_y(1:npts_plot)));
        title(d, 'Channel B Frequency Domain Plot');
        xlabel(d, 'Frequency (MHz)');
        ylabel(d, 'Magnitude (dB)');
        axis([0 freq(npts_plot) -80 0]);

    elseif which == 2
        a = subplot(4,1,1); a_plot = plot(pos_x);
        set(a, 'YTickLabel', num2str(get(a, 'YTick')', '%.7f'));
        title(a, 'X Position Plot');
        xlabel(a, 'Sample number');
        ylabel(a, 'Offset (um)');
        set(a_plot,'Color','red','LineWidth',1);

        b = subplot(4,1,2); b_plot = plot(pos_y);
        set(b, 'YTickLabel', num2str(get(b, 'YTick')', '%.7f'));
        title(b, 'Y Position Plot');
        xlabel(b, 'Sample number');   
        ylabel(b, 'Offset (um)');
        set(b_plot, 'Color', 'blue', 'LineWidth', 1);

        c = subplot(4,1,3); c_plot = plot(pos_z);
        set(c, 'YTickLabel', num2str(get(c, 'YTick')', '%.7f'));
        title(c, 'Z Position Plot');
        xlabel(c, 'Sample number');   
        ylabel(c, 'Offset (um)');
        set(c_plot, 'Color', 'green', 'LineWidth', 1);  

        d = subplot(4,1,4); d_plot = plot(sum(1:end));
        set(d, 'YTickLabel', num2str(get(d, 'YTick')', '%d'));
        title(d, 'Sum Plot');
        xlabel(d, 'Sample number');   
        ylabel(d, 'Offset(um)');
        set(d_plot, 'Color', 'cyan', 'LineWidth', 1);  
    end

    if decrement
        nr_iterations = nr_iterations - 1;
    end
end
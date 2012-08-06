function [adc_a, adc_b, sum, pos_x, pos_y, pos_z] = bpm_adc_ddc_plot_data(nr_samples, fadc, which, nr_iterations, verbose)
%   [adc_a, adc_b, sum, pos_x, pos_y, pos_z] =
%       bpm_adc_ddc_plot_data(nr_samples, fadc, which, nr_iterations, verbose)
%
%   Script de plotagem de dados do BPM
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
%   fadc       : Frequência de amostragem (em MHz) do ADC. Usado apenas para
%                   plotagem adequada.
%   which      : Seleção do tipo de dado.
%                   -> '1' para dados advindos do ADC (Raw ADC Data)
%                   -> '2' para dados advindos do processamento de posição
%                       (DDC + Delta Over Sigma)
%   nr_iterations : Número de plotagens consecutivas.
%                   -> < 0 para plotagem contínua
%                   -> > 0 para número específico de plotagens
%   verbose    : Habilita modo com informações de debug.
%                   -> '1' para poucas informações
%                   -> '2' para informações adicionais
%   -----------------------------------------------------------------------
%   ------------
%   |  Output  |
%   -----------------------------------------------------------------------
%   adc_a       : Dados referentes ao canal A do ADC
%   adc_b       : Dados referentes ao canal B do ADC
%   sum         : Soma dos quatro canais de medidas de posição.
%   pos_x       : Medida de posição no eixo x
%   pos_y       : Medida de posição no eixo y
%   pos_z       : Medida de posição no eixo z
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
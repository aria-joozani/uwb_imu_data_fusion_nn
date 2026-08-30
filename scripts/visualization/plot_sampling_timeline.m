function plot_sampling_timeline(t_acc, t_gyro, t_vicon, t_uwb, t_window)
% plot_sampling_timeline
% Visualize sampling instants of multiple sensors with bold markers
% and vertical stems connecting each sample to the time axis.

    if nargin < 5
        t_window = [];
    end

    % ensure column vectors
    t_acc   = t_acc(:);
    t_gyro  = t_gyro(:);
    t_vicon = t_vicon(:);
    t_uwb   = t_uwb(:);

    % apply time window if provided
    if ~isempty(t_window)
        tmin = t_window(1); tmax = t_window(2);
        t_acc   = t_acc(  t_acc   >= tmin & t_acc   <= tmax);
        t_gyro  = t_gyro( t_gyro  >= tmin & t_gyro  <= tmax);
        t_vicon = t_vicon(t_vicon >= tmin & t_vicon <= tmax);
        t_uwb   = t_uwb(  t_uwb   >= tmin & t_uwb   <= tmax);
    end

    % y-levels for each sensor
    y_acc   = 4;
    y_gyro  = 3;
    y_vicon = 2;
    y_uwb   = 1;

    figure('Name','Sampling Timeline of Sensors');
    hold on; grid on; box on;

    %% ----- ACC -----
    for i = 1:length(t_acc)
        plot([t_acc(i) t_acc(i)], [0 y_acc], 'Color',[0.2 0.2 0.2 0.3]);  % thin vertical line
    end
    scatter(t_acc, y_acc*ones(size(t_acc)), 40, 'filled');  % bold dot

    %% ----- GYRO -----
    for i = 1:length(t_gyro)
        plot([t_gyro(i) t_gyro(i)], [0 y_gyro], 'Color',[0.2 0.2 0.2 0.3]);
    end
    scatter(t_gyro, y_gyro*ones(size(t_gyro)), 40, 'filled');

    % ----- VICON -----
    for i = 1:length(t_vicon)
        plot([t_vicon(i) t_vicon(i)], [0 y_vicon], 'Color',[0.2 0.2 0.2 0.3]);
    end
    scatter(t_vicon, y_vicon*ones(size(t_vicon)), 60, 'filled');

    %% ----- UWB TDOA -----
    for i = 1:length(t_uwb)
        plot([t_uwb(i) t_uwb(i)], [0 y_uwb], 'Color',[0.2 0.2 0.2 0.3]);
    end
    scatter(t_uwb, y_uwb*ones(size(t_uwb)), 60, 'filled');

    %% Y labels
    yticks([1 2 3 4]);
    yticklabels({'UWB TDOA', 'Vicon', 'Gyro', 'Acc'});

    xlabel('Time (s)');
    ylabel('Sensors');
    title('Sampling timeline of Acc, Gyro');

    if ~isempty(t_window)
        xlim(t_window);
    end
end

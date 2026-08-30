function plot_pos_err(t, pos_error, Ppo)
    FONTSIZE = 18;
    if nargin < 3 || isempty(Ppo)
        Ppo = zeros(0, 9, 9);
    end

    D = size(Ppo, 1);
    delta_x = zeros(D,1);
    delta_y = zeros(D,1);
    delta_z = zeros(D,1);

    for i = 1:D
        delta_x(i) = sqrt(Ppo(i,1,1));
        delta_y(i) = sqrt(Ppo(i,2,2));
        delta_z(i) = sqrt(Ppo(i,3,3));
    end

    figure('Name','pos_error','Color','w','Position',[100 100 800 600]);

    subplot(3,1,1);
    title('Estimation Error', 'FontSize', FONTSIZE);
    plot(t, pos_error(:,1), 'Color', [0.27 0.51 0.71], 'LineWidth', 2); hold on;
    fill([t; flipud(t)], [3*delta_x; flipud(-3*delta_x)], ...
         'c', 'FaceAlpha', 0.3, 'EdgeColor','none');
    ylabel('error x [m]', 'FontSize', FONTSIZE);
    xlim([0 max(t)]);
    ylim([-0.35, 0.35]);

    subplot(3,1,2);
    plot(t, pos_error(:,2), 'Color', [0.27 0.51 0.71], 'LineWidth', 2); hold on;
    fill([t; flipud(t)], [3*delta_y; flipud(-3*delta_y)], ...
         'c', 'FaceAlpha', 0.3, 'EdgeColor','none');
    ylabel('error y [m]', 'FontSize', FONTSIZE);
    xlim([0 max(t)]);
    ylim([-0.35, 0.35]);

    subplot(3,1,3);
    plot(t, pos_error(:,3), 'Color', [0.27 0.51 0.71], 'LineWidth', 2); hold on;
    fill([t; flipud(t)], [3*delta_z; flipud(-3*delta_z)], ...
         'c', 'FaceAlpha', 0.3, 'EdgeColor','none');
    xlabel('time [s]', 'FontSize', FONTSIZE);
    ylabel('error z [m]', 'FontSize', FONTSIZE);
    xlim([0 max(t)]);
    ylim([-0.45, 0.45]);
end
function plot_pos(t, Xpo, t_vicon, pos_vicon)
    FONTSIZE = 18;

    figure('Color','w','Position',[100 100 800 600]);
    
    subplot(3,1,1);
    plot(t_vicon, pos_vicon(:,1), 'Color', [1 0.27 0], 'LineWidth', 2.5); hold on;
    plot(t, Xpo(:,1), 'Color', [0.25 0.41 0.88], 'LineWidth', 2.5);
    ylabel('X [m]', 'FontSize', FONTSIZE);
    title('Estimation results', 'FontSize', FONTSIZE);
    legend('Vicon ground truth', 'Estimate');
    xlim([0 max(t)]);

    subplot(3,1,2);
    plot(t_vicon, pos_vicon(:,2), 'Color', [1 0.27 0], 'LineWidth', 2.5); hold on;
    plot(t, Xpo(:,2), 'Color', [0.25 0.41 0.88], 'LineWidth', 2.5);
    ylabel('Y [m]', 'FontSize', FONTSIZE);
    xlim([0 max(t)]);

    subplot(3,1,3);
    plot(t_vicon, pos_vicon(:,3), 'Color', [1 0.27 0], 'LineWidth', 2.5); hold on;
    plot(t, Xpo(:,3), 'Color', [0.25 0.41 0.88], 'LineWidth', 2.5);
    xlabel('time [s]', 'FontSize', FONTSIZE);
    ylabel('Z [m]', 'FontSize', FONTSIZE);
    xlim([0 max(t)]);
end

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

    figure('Color','w','Position',[100 100 800 600]);

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

function plot_traj(pos_vicon, Xpo, anchor_pos)
    FONTSIZE = 18;
    figure('Color','w','Position',[100 100 800 600]);
    ax = axes('Projection','3d');

    hold on;
    plot3(pos_vicon(:,1), pos_vicon(:,2), pos_vicon(:,3), 'b', 'LineWidth', 2);
    plot3(Xpo(:,1), Xpo(:,2), Xpo(:,3), 'g', 'LineWidth', 3);
    scatter3(anchor_pos(:,1), anchor_pos(:,2), anchor_pos(:,3), ...
             100, 'filled', 'MarkerFaceColor', [0 0.5 0.5], 'MarkerEdgeAlpha',0.5);

    xlim([-3.5, 3.5]);
    ylim([-3.9, 3.9]);
    zlim([0, 3.0]);
    xlabel('X [m]', 'FontSize', FONTSIZE);
    ylabel('Y [m]', 'FontSize', FONTSIZE);
    zlabel('Z [m]', 'FontSize', FONTSIZE);
    legend('ground truth', 'estimation', 'anchors', 'FontSize', FONTSIZE, 'Location', 'best');

    view(24, -58);
    daspect([1 1 0.5]);
end

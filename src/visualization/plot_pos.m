function plot_pos(t, Xpo, t_vicon, pos_vicon)
    FONTSIZE = 18;

    figure('Name','pos','Color','w','Position',[100 100 800 600]);
    
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
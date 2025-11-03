function plot_traj(pos_vicon, Xpo, anchor_pos)
    FONTSIZE = 18;
    figure('Color','w','Position',[100 100 800 600]);
    %ax = axes('Projection','3d');

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

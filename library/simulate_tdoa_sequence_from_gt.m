function tdoa_sim = simulate_tdoa_sequence_from_gt(gt_data, tdoa_tags, anchor_pos)
    % gt_data: Nx4 matrix [time x y z]
    % tdoa_tags: Mx3 matrix [time, idA, idB]
    % anchor_pos: 8x3 matrix of anchor positions

    tdoa_sim = zeros(size(tdoa_tags, 1), 4); % [time, idA, idB, tdoa_val]

    for i = 1:size(tdoa_tags, 1)
        t = tdoa_tags(i, 1);
        idA = tdoa_tags(i, 2);
        idB = tdoa_tags(i, 3);

        tag_pos = gt_data(i, 2:4);
        tdoa_val = generate_tdoa_from_gt(tag_pos, anchor_pos(idA+1, :), anchor_pos(idB+1, :));
        tdoa_sim(i, :) = [t, idA, idB, tdoa_val];
    end
end
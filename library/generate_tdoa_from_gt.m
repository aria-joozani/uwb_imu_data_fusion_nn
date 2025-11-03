function tdoa_val = generate_tdoa_from_gt(tag_pos, anchor_A_pos, anchor_B_pos)
    % tag_pos: 1x3 position of tag [x y z]
    % anchor_A_pos: 1x3 position of anchor A [x y z]
    % anchor_B_pos: 1x3 position of anchor B [x y z]
    
    c = 299792458e-9; % speed of light in m/s
    d_A = norm(tag_pos - anchor_A_pos);
    d_B = norm(tag_pos - anchor_B_pos);
    
    tdoa_val = (d_B - d_A) ;
end
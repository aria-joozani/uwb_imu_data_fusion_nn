%w_vel = 0;
%w_pos = 0;
%w_att = 0;
%DEG_TO_RAD = pi / 180;

classdef ESKF < handle
    properties
        std_uwb_tdoa = sqrt(0.05);
        t_uv = [-0.01245; 0.00127; 0.0908];
        f
        omega
        q_list
        R_list
        Xpr
        Xpo
        Ppr
        Ppo
        R
        Fi
    end

    methods
        function obj = ESKF(X0, q0, P0, K)
            obj.f = zeros(K, 3);
            obj.omega = zeros(K, 3);
            obj.q_list = zeros(K, 4);
            obj.R_list = zeros(K, 3, 3);

            obj.Xpr = zeros(K, 6);
            obj.Xpo = zeros(K, 6);
            obj.Ppr = zeros(K, 9, 9);
            obj.Ppo = zeros(K, 9, 9);

            obj.Ppr(1, :, :) = P0;
            obj.Ppo(1, :, :) = P0;
            obj.Xpr(1, :) = X0';
            obj.Xpo(1, :) = X0';
            obj.q_list(1, :) = q0(:)';
            obj.R = quat2rotm(q0);

            obj.Fi = [zeros(3), zeros(3); eye(3), zeros(3); zeros(3), eye(3)];
        end

        function predict(obj, imu, dt, imu_check, k)
            % Process noise
            w_accxyz = 2;
            w_gyro_rpy = 0.1;   % rad/sec
            % Constants
            GRAVITY_MAGNITUDE = 9.81;
            e3 = [0; 0; 1];
            
            Vi = (w_accxyz^2)*(dt^2)*eye(3);
            Thetai = (w_gyro_rpy^2)*(dt^2)*eye(3);
            Qi = [Vi, zeros(3); zeros(3), Thetai];

            if imu_check
                omega_k = imu(4:6) * pi/180;
                obj.omega(k, :) = omega_k;
                Vpo = obj.Xpo(k-1, 4:6);
                f_k = imu(1:3) * GRAVITY_MAGNITUDE;
                obj.f(k, :) = f_k;
                dw = omega_k * dt;

                obj.Xpr(k, 1:3) = obj.Xpo(k-1, 1:3) + Vpo * dt + 0.5 * (obj.R * f_k' - GRAVITY_MAGNITUDE * e3)' * dt^2;
                obj.Xpr(k, 4:6) = obj.Xpo(k-1, 4:6) + (obj.R * f_k' - GRAVITY_MAGNITUDE * e3)' * dt;
                if obj.Xpr(k, 3) < 0
                    obj.Xpr(k, 3:6) = 0;
                end

                qk_1 = quaternion(obj.q_list(k-1, :));
                dqk = quaternion(obj.zeta(dw));
                q_pr = qk_1 * dqk;
                obj.q_list(k, :) = compact(q_pr);
                obj.R_list(k, :, :) = quat2rotm(compact(q_pr));
                obj.R = quat2rotm(compact(qk_1));

                Fx = eye(9);
                Fx(1:3, 4:6) = dt * eye(3);
                Fx(1:3, 7:9) = -0.5 * dt^2 * obj.R * obj.cross(f_k);
                Fx(4:6, 7:9) = -dt * obj.R * obj.cross(f_k);
                Fx(7:9, 7:9) = expm(obj.cross(dw));

                Ppo_km1 = squeeze(obj.Ppo(k-1, :, :));
                obj.Ppr(k, :, :) = Fx * Ppo_km1 * Fx' + obj.Fi * Qi * obj.Fi';
                obj.Ppr(k, :, :) = 0.5 * (squeeze(obj.Ppr(k, :, :)) + squeeze(obj.Ppr(k, :, :))');
            else
                Ppo_km1 = squeeze(obj.Ppo(k-1, :, :));
                obj.Ppr(k, :, :) = Ppo_km1 + obj.Fi * Qi * obj.Fi';
                obj.Ppr(k, :, :) = 0.5 * (squeeze(obj.Ppr(k, :, :)) + squeeze(obj.Ppr(k, :, :))');
                obj.omega(k, :) = obj.omega(k-1, :);
                obj.f(k, :) = obj.f(k-1, :);
                dw = obj.omega(k, :) * dt;
                Vpo = obj.Xpo(k-1, 4:6);
                obj.Xpr(k, 1:3) = obj.Xpo(k-1, 1:3) + Vpo * dt + 0.5 * (obj.R * obj.f(k, :)' - GRAVITY_MAGNITUDE * e3)' * dt^2;
                obj.Xpr(k, 4:6) = obj.Xpo(k-1, 4:6) + (obj.R * obj.f(k, :)' - GRAVITY_MAGNITUDE * e3)' * dt;
                qk_1 = quaternion(obj.q_list(k-1, :));
                dqk = quaternion(obj.zeta(dw));
                q_pr = qk_1 * dqk;
                obj.q_list(k, :) = compact(q_pr);
                obj.R_list(k, :, :) = quat2rotm(compact(q_pr));
            end
            obj.Xpo(k, :) = obj.Xpr(k, :);
            obj.Ppo(k, :, :) = obj.Ppr(k, :, :);
        end

        function UWB_correct(obj, uwb, anchor_position, k)
            an_A = anchor_position(uwb(1)+1, :);
            an_B = anchor_position(uwb(2)+1, :);

            qk_pr = quaternion(obj.q_list(k, :));
            C_iv = quat2rotm(compact(qk_pr));

            p_uwb = C_iv * obj.t_uv + obj.Xpr(k, 1:3)';
            d_A = norm(an_A - p_uwb');
            d_B = norm(an_B - p_uwb');
            predicted = d_B - d_A;
            err_uwb = uwb(3) - predicted;

            G = obj.computeG_grad(an_A, an_B, obj.t_uv, obj.Xpr(k, 1:3), obj.q_list(k, :));
            Q = obj.std_uwb_tdoa^2;
            Ppr_k = squeeze(obj.Ppr(k, :, :));
            M = G * Ppr_k * G' + Q;
            d_m = sqrt(err_uwb^2 / M);

            if d_m < 5
                Kk = (Ppr_k * G') / M;
                obj.Ppo(k, :, :) = (eye(9) - Kk * G) * Ppr_k;
                obj.Ppo(k, :, :) = 0.5 * (squeeze(obj.Ppo(k, :, :)) + squeeze(obj.Ppo(k, :, :))');
                derror = Kk * err_uwb;
                obj.Xpo(k, :) = obj.Xpr(k, :) + derror(1:6)';
                dq_k = quaternion(obj.zeta(derror(7:9)));
                qk_po = qk_pr * dq_k;
                obj.q_list(k, :) = compact(qk_po);
            else
                obj.Xpo(k, :) = obj.Xpr(k, :);
                obj.Ppo(k, :, :) = obj.Ppr(k, :, :);
            end
        end

        function G = computeG_grad(obj, an_A, an_B, t_uv, Xpr, q_k)
            % Ensure quaternion is valid
            qk_pr = quaternion(q_k);  % q_k must be 1×4
            C_iv = quat2rotm(compact(qk_pr));
        
            % Compute UWB sensor position in inertial frame
            p_uwb = C_iv * t_uv + Xpr';  % 3x1
        
            % Distance to anchors
            d_A = norm(p_uwb - an_A');
            d_B = norm(p_uwb - an_B');
        
            % Gradient w.r.t. position
            g_p = ((p_uwb - an_B') / d_B - (p_uwb - an_A') / d_A);  % 3x1
        
            % Gradient w.r.t. velocity (zero)
            g_v = zeros(3, 1);  % 3x1
        
            % Quaternion components
            q_w = q_k(1);
            q_v = q_k(2:4)';  % 3x1 column vector
        
            % Derivatives for quaternion-based rotation
            d_vec = q_w * t_uv + obj.cross(q_v) * t_uv;  % 3x1
            d_mat = q_v' * t_uv * eye(3) + q_v * t_uv' - t_uv * q_v' - q_w * obj.cross(t_uv);  % 3x3
        
            d_RVq = 2 * [d_vec, d_mat];  % 3x4
        
            % Gradient w.r.t. quaternion
            d_dist = ((p_uwb - an_B') / d_B - (p_uwb - an_A') / d_A);  % 3x1
            g_q = d_dist' * d_RVq;  % 1x4
        
            % Stack Jacobians (all as row vectors: 1x3, 1x3, 1x4)
            G_x = [g_p', g_v', g_q];  % CORRECT — horizontal 1x10 row vector
        
            % Small rotation quaternion derivative matrix (4x3)
            Q_dtheta = 0.5 * [
                -q_k(2), -q_k(3), -q_k(4);
                 q_w,   -q_k(4),  q_k(3);
                 q_k(4), q_w,    -q_k(2);
                -q_k(3), q_k(2),  q_w
            ];  % 4x3
        
            % Total gradient matrix: dx = [dp; dv; dtheta] → size 10×1
            G_dx = blkdiag(eye(6), Q_dtheta);  % 10x3
        
            % Final UWB observation Jacobian
            G = G_x * G_dx;  % G_x: 1x10, G_dx: 10x3 ⇒ G: 1x3
        end


        function vx = cross(~, v)
            v = v(:);
            vx = [0, -v(3), v(2); v(3), 0, -v(1); -v(2), v(1), 0];
        end

        function dq = zeta(obj, phi)
            phi_norm = norm(phi);
            if phi_norm == 0
                dq = [1, 0, 0, 0];
            else
                dq_xyz = (phi * sin(0.5 * phi_norm)) / phi_norm;
                dq = [cos(0.5 * phi_norm), dq_xyz(1), dq_xyz(2), dq_xyz(3)];
            end
        end
    end
end


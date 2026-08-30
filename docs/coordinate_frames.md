# Coordinate frames and conventions

## Summary

The active code assumes that surveyed anchors, Vicon position, ESKF position, and plotted trajectories already share one local Cartesian frame. It does not load or apply an explicit survey-to-Vicon transform. The processed survey files therefore carry a critical implicit transformation whose generating code is absent.

Frame names such as ENU or NED do not appear in the implementation. This review uses neutral names and marks unsupported details `UNKNOWN`.

## Frame inventory

| Frame | Evidence | Origin | Axis orientation | Units | Status |
| --- | --- | --- | --- | --- | --- |
| Local/Vicon world frame `W` | `pose_x/y/z`, `pos_vicon`, anchor plots, ESKF state | `UNKNOWN`; likely motion-capture/survey origin | x/y directions `UNKNOWN`; code treats +z as up | metres | active |
| IMU/body frame `B` | accelerometer/gyro xyz; ESKF rotation | sensor/body origin `UNKNOWN` | raw sensor axes `UNKNOWN`; at identity initialization, +Bz is treated as +Wz | g, deg/s | active |
| UWB tag frame/origin `U` | lever arm `t_uv` | UWB antenna phase centre | orientation assumed fixed to body; exact axes `UNKNOWN` | metres | active |
| Anchor local frames `A_i` | processed survey quaternions | each anchor | `UNKNOWN` | quaternion | loaded but unused |
| Raw survey frame `S` | `survey-results/raw-data/*.txt` | survey marker layout | `UNKNOWN` | raw marker coordinates appear millimetres for Vicon markers and metres for UWB-frame/anchor values | preprocessing only; transform code absent |
| Plot frame | `plot_traj` axes | same as local/Vicon frame | x/y/z labels only | metres | visualization |

There is no evidence supporting an ENU, NED, latitude/longitude, or Earth-fixed frame.

## Local/Vicon world frame

The processed anchor positions range roughly from -4 m to +4 m in x/y and 0.15 m to 3.2 m in z. Vicon pose and ESKF position are compared by direct subtraction:

```matlab
pos_error = eskf.Xpo(:,1:3) - interp_gt;
```

This proves the implementation assumes both arrays are in the same frame and units. It does not prove that the assumption is physically correct.

The ESKF uses:

```matlab
specific_acceleration_world = R * f_body - 9.81 * [0;0;1]
```

Therefore the implementation treats positive world z as upward and gravity as negative z. That is compatible with a local z-up frame, but x/y compass directions remain `UNKNOWN`.

## Survey-to-world relation

Each processed file `anchor_const*_survey.txt` supplies:

```text
an0_p,... through an7_p,...
an0_quat,... through an7_quat,...
```

`data_extractor.m` copies processed positions directly into `anchor_position`. Raw survey files contain Vicon marker coordinates, a small UWB dataset frame marker set, and measured anchor marker/antenna points. Processed positions differ slightly from raw antenna coordinates, indicating an external rigid transformation or survey fit.

```text
Raw survey -> processed anchor position/quaternion transform: UNKNOWN
Transform implementation: not present
Transform direction: UNKNOWN
Fit residual/uncertainty: UNKNOWN
```

The NPZ files may contain supporting transformation data, but no repository code reads them. They require a separate provenance inspection before changing anchor geometry.

## Body/IMU to world rotation

The ESKF stores a MATLAB quaternion and obtains:

```matlab
C_iv = quat2rotm(compact(q));
p_uwb_world = C_iv * t_uv + position_world;
```

The variable name and multiplication imply `C_iv` maps a vector expressed in the vehicle/body frame to the inertial/world frame:

```text
v_W = C_WB * v_B
```

This direction is an inference from use, not documented metadata. The same `R` maps measured body specific force into world coordinates during propagation.

The nominal quaternion is updated by right multiplication:

```matlab
q_k = q_{k-1} * delta_q(omega_B * dt)
```

This is consistent with body-frame incremental rotation under one common convention, but the error-state sign convention must be verified against the transition Jacobian.

## Quaternion conventions

Two different storage orders appear:

| Source | Order | Use |
| --- | --- | --- |
| Raw Vicon fields | `[qx qy qz qw]` by column names | extracted, never used by ESKF |
| Processed anchor survey comments/data structure | `[qx qy qz qw]` | loaded, never used |
| ESKF `q0`, `q_list`, MATLAB `quaternion` | `[qw qx qy qz]` scalar-first | active propagation/correction |

No code converts Vicon/anchor quaternions into ESKF order because those quaternions are not currently used. Future use must not pass `[qx qy qz qw]` directly into the ESKF.

Euler angles are not used, so Euler order and degrees/radians are not applicable to the active pipeline.

## UWB tag lever arm

The class constant is:

```text
t_uv = [-0.01245, 0.00127, 0.0908]^T m
```

It is rotated by `C_iv` and added to nominal platform position. This implies a vector from the position-state origin (probably IMU/body origin) to the UWB antenna, expressed in the body frame.

```text
Exact source/measurement of lever arm: UNKNOWN
Body-axis definition: UNKNOWN
Position-state physical origin: UNKNOWN
```

## TDoA pair convention

The active ring ordering is:

```text
7 -> 0
0 -> 1
1 -> 2
2 -> 3
3 -> 4
4 -> 5
5 -> 6
6 -> 7
```

Dataset generation and ESKF define the measurement for `(A,B)` as:

```text
z_AB = distance(tag, B) - distance(tag, A)
```

The NLS helper defines its prediction as `distance(tag,A)-distance(tag,B)`, the opposite convention. This is a mathematical sign issue, not a coordinate-frame rotation.

## IMU units and axes

- Accelerometer values are treated as g and converted with 9.81 m/s^2 per g.
- Gyroscope values are treated as degrees/s and converted to radians/s.
- No accelerometer or gyro bias frame/state exists.
- No sensor mounting rotation is applied before ESKF use.
- At the fixed identity initial attitude, a stationary sample near `[0,0,1] g` cancels world gravity. This implies assumed initial alignment of body +z with world +z.

Whether all flights actually begin at that alignment is `UNKNOWN`.

## Visualization conventions

`plot_traj` labels x/y/z in metres and constrains:

```text
x: [-3.5, 3.5]
y: [-3.9, 3.9]
z: [0, 3.0]
```

The fixed limits clip some surveyed anchors (coordinates exceed those bounds) and do not define axis semantics. The view angle and z aspect ratio are presentation choices only.

## Required frame verification

Before changing transforms:

1. recover or document the raw-survey-to-processed-anchor transformation;
2. identify Vicon world origin and x/y directions from experiment metadata;
3. confirm IMU/body axis definitions and sensor mounting;
4. confirm whether ESKF quaternion maps body to world or world to body;
5. confirm lever-arm direction and origin;
6. create known-vector rotation tests and compare Vicon orientation after correct component reordering;
7. verify all four constellations are expressed in the same Vicon/local convention.

Until then, all refactoring must preserve current transform order and quaternion handling exactly.

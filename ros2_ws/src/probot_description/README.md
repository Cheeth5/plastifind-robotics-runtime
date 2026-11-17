# PRO-BOT simulation baseline

This is the first simplified simulation description for the original PRO-BOT.

## Provisional dimensions
- Chassis envelope: 0.72 x 0.50 m; visual body height: 0.18 m.
- Four wheels: 0.23 m diameter.
- Four-wheel skid-steer layout; front and rear wheels on each side are intended to be driven together.
- Approximate wheel positions and mass/inertia values are placeholders for initial visualization only.
- LiDAR and camera frames are placeholders; no sensor plugins or realistic sensor outputs are configured yet.

## Important limitations
This package currently provides a URDF/Xacro visual and collision model, a basic Gazebo test world, and a robot_state_publisher launch file. It does **not** yet implement motor dynamics, ros2_control, Gazebo drive plugins, LiDAR/camera simulation, SLAM, Nav2, or validated physical inertias. Those are subsequent milestones.

Replace placeholder geometry, mass, inertias, sensor poses, and collection mechanism geometry when verified measurements or CAD exports are available.

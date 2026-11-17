# PlastiFind Robotics Runtime

Private runtime repository for the PlastiFind Digital Engineering Lab.

## Runtime baseline

- Ubuntu 24.04 through the official ROS image
- ROS 2 Jazzy
- Gazebo Harmonic integration through `ros_gz`
- Nav2 navigation stack
- SLAM Toolbox
- robot_localization
- Xacro, robot_state_publisher, joint_state_publisher
- ros2_control and ros2_controllers

This is a headless container runtime. The Digital Lab web interface should render CAD and simulation results in its browser-based 3D viewer; it should not depend on a desktop Gazebo GUI.

## CI validation

The GitHub Actions workflow builds the Docker image for validation only. It does not publish the image to a registry and does not deploy Azure resources.

## Workspace

Add ROS 2 packages under `ros2_ws/src/`. The Docker build installs package dependencies with rosdep and builds the workspace with colcon when package manifests are present.

## Important limitations

- No Azure compute resource is created by this repository.
- No Azure Storage credentials, API keys, or other secrets belong in Git.
- CI validates that the image can be built; it does not prove that a robot model, world, SLAM map, or Nav2 mission is configured.
- CPU-only container execution is the initial target. GPU-dependent workloads and large-scale AI training require a separate capacity and cost review.

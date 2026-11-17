#!/usr/bin/env bash
set -euo pipefail

source "/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash"

echo "PlastiFind Robotics Runtime"
echo "ROS distribution: ${ROS_DISTRO:-jazzy}"
echo "ROS 2 CLI: $(ros2 --help >/dev/null 2>&1 && echo available)"
echo
echo "Checking core packages:"
for package in ros_gz_sim nav2_bringup slam_toolbox robot_localization xacro controller_manager; do
  if ros2 pkg prefix "$package" >/dev/null 2>&1; then
    printf '  [OK] %s\n' "$package"
  else
    printf '  [MISSING] %s\n' "$package"
  fi
done

echo
echo "Gazebo executable:"
if command -v gz >/dev/null 2>&1; then
  gz sim --versions 2>/dev/null || gz --version || true
else
  echo "Gazebo CLI not found in PATH"
fi

echo
echo "This check verifies installed runtime components only; it does not launch a simulation."

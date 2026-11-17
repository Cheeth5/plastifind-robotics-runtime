#!/usr/bin/env bash
set -euo pipefail

source "/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash"

echo "PlastiFind Robotics Runtime"
echo "ROS distribution: ${ROS_DISTRO:-jazzy}"
echo
echo "Checking installed ROS packages:"
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
  gz --version || true
else
  echo "Gazebo CLI not found in PATH"
fi

echo
echo "This check verifies installed components only; it does not launch a simulation."

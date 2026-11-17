#!/usr/bin/env bash
set -e

source "/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash"

if [[ -f "${PLASTIFIND_ROS_WS:-/opt/plastifind/ros2_ws}/install/setup.bash" ]]; then
  source "${PLASTIFIND_ROS_WS:-/opt/plastifind/ros2_ws}/install/setup.bash"
fi

exec "$@"

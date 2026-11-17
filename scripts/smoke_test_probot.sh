#!/usr/bin/env bash
# Headless end-to-end smoke test for the provisional PRO-BOT Gazebo model.
set -eo pipefail

source "/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash"
if [[ -f "${PLASTIFIND_ROS_WS:-/opt/plastifind/ros2_ws}/install/setup.bash" ]]; then
  source "${PLASTIFIND_ROS_WS:-/opt/plastifind/ros2_ws}/install/setup.bash"
fi

LOG_FILE="/tmp/probot-gazebo-smoke.log"
rm -f "$LOG_FILE"

echo "Starting headless PRO-BOT Gazebo simulation..."
ros2 launch probot_model simulation.launch.py >"$LOG_FILE" 2>&1 &
LAUNCH_PID=$!

cleanup() {
  if kill -0 "$LAUNCH_PID" 2>/dev/null; then
    kill "$LAUNCH_PID" 2>/dev/null || true
    wait "$LAUNCH_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# ROS 2 CLI renders ListControllers as Python-style objects:
# ControllerState(name='...', state='active', ...). Count the two
# required controller names explicitly; do not count output lines.
count_required_active_controllers() {
  printf '%s\n' "$1" |
    grep -oE "name='(joint_state_broadcaster|diff_drive_controller)', state='active'" |
    wc -l || true
}

echo "Waiting for ROS 2 Control and both wheel controllers..."
DEADLINE=$((SECONDS + 150))
CONTROLLER_OUTPUT=""
ACTIVE_COUNT=0

while (( SECONDS < DEADLINE )); do
  if ! kill -0 "$LAUNCH_PID" 2>/dev/null; then
    echo "Simulation launch exited before controllers became active."
    cat "$LOG_FILE"
    exit 1
  fi

  if ros2 service list 2>/dev/null | grep -q '^/controller_manager/list_controllers$'; then
    CONTROLLER_OUTPUT="$(ros2 service call \
      /controller_manager/list_controllers \
      controller_manager_msgs/srv/ListControllers "{}" 2>&1 || true)"

    ACTIVE_COUNT="$(count_required_active_controllers "$CONTROLLER_OUTPUT")"
    if [[ "$ACTIVE_COUNT" -ge 2 ]]; then
      break
    fi
  fi

  sleep 3
done

if [[ "$ACTIVE_COUNT" -lt 2 ]]; then
  echo "Timed out waiting for both required controllers to become active."
  echo "Last controller response:"
  printf '%s\n' "$CONTROLLER_OUTPUT"
  echo "Gazebo/ROS launch log:"
  cat "$LOG_FILE"
  exit 1
fi

echo "Both required controllers are active."
echo "Checking simulated joint-state publication..."
if ! timeout 20s ros2 topic echo --once /joint_states sensor_msgs/msg/JointState >/tmp/probot-joint-states.log 2>&1; then
  echo "No /joint_states message received."
  cat "$LOG_FILE"
  cat /tmp/probot-joint-states.log
  exit 1
fi

echo "Checking differential-drive odometry..."
if ! timeout 20s ros2 topic echo --once /diff_drive_controller/odom nav_msgs/msg/Odometry >/tmp/probot-odom.log 2>&1; then
  echo "No differential-drive odometry message received."
  cat "$LOG_FILE"
  cat /tmp/probot-odom.log
  exit 1
fi

echo "PRO-BOT Gazebo smoke test PASSED."
echo "Both wheel controllers are active; joint states and odometry are publishing."

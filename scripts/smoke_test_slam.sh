#!/usr/bin/env bash
# Runtime test: move the simulated PRO-BOT and require a real SLAM OccupancyGrid.
set -eo pipefail
source "/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash"
if [[ -f "${PLASTIFIND_ROS_WS:-/opt/plastifind/ros2_ws}/install/setup.bash" ]]; then
  source "${PLASTIFIND_ROS_WS:-/opt/plastifind/ros2_ws}/install/setup.bash"
fi
LOG_FILE="/tmp/probot-slam-smoke.log"
rm -f "$LOG_FILE"
echo "Starting PRO-BOT simulation with SLAM Toolbox..."
ros2 launch probot_model mapping.launch.py >"$LOG_FILE" 2>&1 &
LAUNCH_PID=$!
cleanup() {
  if kill -0 "$LAUNCH_PID" 2>/dev/null; then
    kill "$LAUNCH_PID" 2>/dev/null || true
    wait "$LAUNCH_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT
echo "Waiting for wheel controllers..."
DEADLINE=$((SECONDS + 150))
ACTIVE=0
while (( SECONDS < DEADLINE )); do
  if ! kill -0 "$LAUNCH_PID" 2>/dev/null; then
    echo "Mapping launch exited unexpectedly."
    cat "$LOG_FILE"
    exit 1
  fi
  if ros2 service list 2>/dev/null | grep -q '^/controller_manager/list_controllers$'; then
    OUT="$(ros2 service call /controller_manager/list_controllers controller_manager_msgs/srv/ListControllers "{}" 2>&1 || true)"
    if printf '%s' "$OUT" | grep -q "name='diff_drive_controller', state='active'"; then
      ACTIVE=1
      break
    fi
  fi
  sleep 3
done
if [[ "$ACTIVE" -ne 1 ]]; then
  echo "Differential-drive controller did not become active."
  cat "$LOG_FILE"
  exit 1
fi
echo "Driving a short controlled arc to generate scan motion for SLAM..."
timeout 12s ros2 topic pub -r 10 /diff_drive_controller/cmd_vel_unstamped geometry_msgs/msg/Twist "{linear: {x: 0.12}, angular: {z: 0.18}}" >/tmp/probot-slam-drive.log 2>&1 || DRIVE_STATUS=$?
if [[ "${DRIVE_STATUS:-0}" -ne 0 && "${DRIVE_STATUS:-0}" -ne 124 && "${DRIVE_STATUS:-0}" -ne 130 ]]; then
  echo "Velocity command failed."
  cat /tmp/probot-slam-drive.log
  cat "$LOG_FILE"
  exit 1
fi
echo "Checking for a real SLAM map..."
if ! timeout 45s ros2 topic echo --once /map nav_msgs/msg/OccupancyGrid >/tmp/probot-slam-map.log 2>&1; then
  echo "SLAM Toolbox did not publish /map OccupancyGrid."
  echo "--- SLAM/Gazebo log ---"
  cat "$LOG_FILE"
  echo "--- map topic diagnostic ---"
  ros2 topic list 2>&1 || true
  exit 1
fi
grep -q "resolution:" /tmp/probot-slam-map.log
grep -q "data:" /tmp/probot-slam-map.log
echo "SLAM runtime smoke test PASSED: /map OccupancyGrid received after robot motion."

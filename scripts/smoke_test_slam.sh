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
echo "Waiting for wheel controllers and SLAM node..."
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
echo "Verifying LiDAR frame ID before mapping..."
timeout 12s ros2 topic echo --once /scan sensor_msgs/msg/LaserScan >/tmp/probot-slam-scan.log 2>&1
if ! grep -q "frame_id: lidar_link" /tmp/probot-slam-scan.log; then
  echo "LiDAR frame_id is not lidar_link; SLAM cannot resolve the sensor transform."
  grep -m1 "frame_id:" /tmp/probot-slam-scan.log || true
  cat "$LOG_FILE"
  exit 1
fi
echo "LiDAR frame is correct. Driving a controlled arc while SLAM receives scans..."
timeout 25s ros2 topic pub -r 10 /diff_drive_controller/cmd_vel_unstamped geometry_msgs/msg/Twist "{linear: {x: 0.12}, angular: {z: 0.18}}" >/tmp/probot-slam-drive.log 2>&1 || DRIVE_STATUS=$?
if [[ "${DRIVE_STATUS:-0}" -ne 0 && "${DRIVE_STATUS:-0}" -ne 124 && "${DRIVE_STATUS:-0}" -ne 130 ]]; then
  echo "Velocity command failed."
  cat /tmp/probot-slam-drive.log
  cat "$LOG_FILE"
  exit 1
fi
echo "Checking for a real SLAM map..."
if ! timeout 75s ros2 topic echo --once /map nav_msgs/msg/OccupancyGrid >/tmp/probot-slam-map.log 2>&1; then
  echo "SLAM Toolbox did not publish /map OccupancyGrid."
  echo "--- ROS nodes ---"
  ros2 node list 2>&1 || true
  echo "--- ROS topics ---"
  ros2 topic list -t 2>&1 || true
  echo "--- /scan publisher/subscriber info ---"
  ros2 topic info /scan --verbose 2>&1 || true
  echo "--- one LiDAR message (frame_id and ranges) ---"
  timeout 8s ros2 topic echo --once /scan sensor_msgs/msg/LaserScan 2>&1 || true
  echo "--- SLAM node parameters ---"
  ros2 param get /slam_toolbox scan_topic 2>&1 || true
  ros2 param get /slam_toolbox base_frame 2>&1 || true
  echo "--- odom to base transform ---"
  timeout 8s ros2 run tf2_ros tf2_echo odom base_footprint 2>&1 || true
  echo "--- SLAM/Gazebo log ---"
  cat "$LOG_FILE"
  exit 1
fi
grep -q "resolution:" /tmp/probot-slam-map.log
grep -q "data:" /tmp/probot-slam-map.log
echo "SLAM runtime smoke test PASSED: /map OccupancyGrid received after robot motion."

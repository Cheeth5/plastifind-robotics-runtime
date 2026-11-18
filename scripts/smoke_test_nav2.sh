#!/usr/bin/env bash
# End-to-end Nav2 test: map with SLAM, activate Nav2, and reach a navigation goal.
set -eo pipefail
source "/opt/ros/${ROS_DISTRO:-jazzy}/setup.bash"
source "${PLASTIFIND_ROS_WS:-/opt/plastifind/ros2_ws}/install/setup.bash"

MAP_LOG=/tmp/probot-nav2-mapping.log
NAV_LOG=/tmp/probot-nav2-navigation.log
rm -f "$MAP_LOG" "$NAV_LOG"

cleanup() {
  for pid in "${NAV_PID:-}" "${MAP_PID:-}"; do
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
    fi
  done
}
trap cleanup EXIT

echo "Starting Gazebo and SLAM mapping..."
ros2 launch probot_model mapping.launch.py >"$MAP_LOG" 2>&1 &
MAP_PID=$!

echo "Waiting for live SLAM OccupancyGrid..."
MAP_READY=0
DEADLINE=$((SECONDS + 150))
while (( SECONDS < DEADLINE )); do
  if ! kill -0 "$MAP_PID" 2>/dev/null; then
    echo "Mapping process exited before publishing /map."
    cat "$MAP_LOG"
    exit 1
  fi
  if timeout 5s ros2 topic echo --once /map nav_msgs/msg/OccupancyGrid >/tmp/probot-nav2-map.log 2>&1; then
    MAP_READY=1
    break
  fi
  sleep 2
done
if [[ "$MAP_READY" -ne 1 ]]; then
  echo "SLAM did not provide a map to Nav2."
  cat "$MAP_LOG"
  exit 1
fi

echo "Preparing complete Nav2 Jazzy parameters with PRO-BOT frame/topic overrides..."
python3 /opt/plastifind/scripts/prepare_nav2_params.py

echo "Starting Nav2 navigation servers..."
ros2 launch probot_model navigation.launch.py >"$NAV_LOG" 2>&1 &
NAV_PID=$!

echo "Waiting for Nav2 lifecycle activation and NavigateToPose action server..."
NAV_READY=0
DEADLINE=$((SECONDS + 150))
while (( SECONDS < DEADLINE )); do
  if ! kill -0 "$NAV_PID" 2>/dev/null; then
    echo "Nav2 launch exited unexpectedly."
    cat "$NAV_LOG"
    exit 1
  fi
  ACTIONS="$(ros2 action list 2>/dev/null || true)"
  CTRL="$(timeout 5s ros2 lifecycle get /controller_server 2>&1 || true)"
  PLAN="$(timeout 5s ros2 lifecycle get /planner_server 2>&1 || true)"
  if printf '%s' "$ACTIONS" | grep -q '^/navigate_to_pose$' &&
     printf '%s' "$CTRL" | grep -q 'active' &&
     printf '%s' "$PLAN" | grep -q 'active'; then
    NAV_READY=1
    break
  fi
  sleep 3
done
if [[ "$NAV_READY" -ne 1 ]]; then
  echo "Nav2 servers did not become active."
  ros2 node list 2>&1 || true
  ros2 lifecycle get /controller_server 2>&1 || true
  ros2 lifecycle get /planner_server 2>&1 || true
  cat "$NAV_LOG"
  exit 1
fi

echo "Sending a real NavigateToPose goal in the mapped arena..."
GOAL_OUTPUT="$(timeout 100s ros2 action send_goal /navigate_to_pose nav2_msgs/action/NavigateToPose "{pose: {header: {frame_id: map}, pose: {position: {x: -0.5, y: 1.5, z: 0.0}, orientation: {x: 0.0, y: 0.0, z: 0.0, w: 1.0}}}}" 2>&1 || true)"
printf '%s\n' "$GOAL_OUTPUT"
if ! printf '%s' "$GOAL_OUTPUT" | grep -q 'SUCCEEDED'; then
  echo "Nav2 did not report a successful navigation goal."
  echo "--- Navigation log ---"
  cat "$NAV_LOG"
  echo "--- Mapping log ---"
  cat "$MAP_LOG"
  exit 1
fi

echo "Nav2 runtime smoke test PASSED: NavigateToPose goal returned SUCCEEDED."

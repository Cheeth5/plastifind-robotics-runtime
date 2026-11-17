#!/usr/bin/env bash
set -euo pipefail

source /opt/ros/jazzy/setup.bash

ROBOT_DIR="/opt/plastifind/ros2_ws/src/probot_description"

echo "Validating PRO-BOT Xacro..."
xacro \
  "$ROBOT_DIR/urdf/probot.urdf.xacro" \
  controller_params_file:="$ROBOT_DIR/config/probot_controllers.yaml" \
  > /tmp/probot.urdf

echo "Checking robot links, joints and control plugin..."
python3 - <<'PY'
import xml.etree.ElementTree as ET

root = ET.parse("/tmp/probot.urdf").getroot()

assert root.tag == "robot", "Invalid URDF root"

required_links = {
    "base_link",
    "base_footprint",
    "front_left_wheel",
    "front_right_wheel",
    "rear_left_wheel",
    "rear_right_wheel",
}

actual_links = {link.attrib["name"] for link in root.findall("link")}
assert required_links.issubset(actual_links), "Missing robot links"

required_joints = {
    "front_left_wheel_joint",
    "front_right_wheel_joint",
    "rear_left_wheel_joint",
    "rear_right_wheel_joint",
}

actual_joints = {joint.attrib["name"] for joint in root.findall("joint")}
assert required_joints.issubset(actual_joints), "Missing wheel joints"

control = root.find("ros2_control")
assert control is not None, "Missing ROS 2 Control block"

plugins = [
    plugin.text
    for plugin in root.findall(".//ros2_control/hardware/plugin")
]
assert "gz_ros2_control/GazeboSimSystem" in plugins, "Missing Gazebo control plugin"

print("PRO-BOT URDF validation passed.")
PY

echo "Validating Gazebo world XML..."
python3 - <<'PY'
import xml.etree.ElementTree as ET

root = ET.parse(
    "/opt/plastifind/ros2_ws/src/probot_description/worlds/probot_test_world.sdf"
).getroot()

assert root.tag == "sdf", "Invalid SDF root"
assert root.find("world") is not None, "Missing Gazebo world"

print("Gazebo world XML validation passed.")
PY

echo "Checking launch file syntax..."
python3 -m py_compile "$ROBOT_DIR/launch/simulation.launch.py"

echo "PRO-BOT description validation completed successfully."

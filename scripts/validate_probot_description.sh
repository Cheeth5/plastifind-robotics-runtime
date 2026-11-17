#!/usr/bin/env bash
set -eo pipefail
source /opt/ros/jazzy/setup.bash
ROBOT_DIR="/opt/plastifind/ros2_ws/src/probot_description"
echo "Validating PRO-BOT Xacro..."
xacro "$ROBOT_DIR/urdf/probot.urdf.xacro" controller_params_file:="$ROBOT_DIR/config/probot_controllers.yaml" > /tmp/probot.urdf
python3 - <<'PY'
import xml.etree.ElementTree as ET
root = ET.parse("/tmp/probot.urdf").getroot()
assert root.tag == "robot", "Invalid URDF root"
required_links = {"base_link","base_footprint","front_left_wheel","front_right_wheel","rear_left_wheel","rear_right_wheel","lidar_link","imu_link","camera_link"}
assert required_links.issubset({x.attrib["name"] for x in root.findall("link")}), "Missing robot links"
required_joints = {"front_left_wheel_joint","front_right_wheel_joint","rear_left_wheel_joint","rear_right_wheel_joint"}
assert required_joints.issubset({x.attrib["name"] for x in root.findall("joint")}), "Missing wheel joints"
assert root.find("ros2_control") is not None, "Missing ROS 2 Control block"
plugins = [x.text for x in root.findall(".//ros2_control/hardware/plugin")]
assert "gz_ros2_control/GazeboSimSystem" in plugins, "Missing Gazebo control plugin"
print("PRO-BOT URDF validation passed.")
PY
echo "Validating Gazebo arena and scenario assets..."
python3 - <<'PY'
import xml.etree.ElementTree as ET
path = "/opt/plastifind/ros2_ws/src/probot_description/worlds/probot_test_world.sdf"
root = ET.parse(path).getroot()
assert root.tag == "sdf", "Invalid SDF root"
world = root.find("world")
assert world is not None, "Missing Gazebo world"
models = {m.attrib["name"] for m in world.findall("model")}
required = {"ground","north_wall","south_wall","east_wall","west_wall","central_obstacle","side_obstacle","plastic_bottle_01","plastic_bottle_02","plastic_bottle_03","human_littering_target"}
missing = required - models
assert not missing, f"Missing scenario models: {sorted(missing)}"
print(f"Gazebo world validation passed: {len(models)} models including bottles, obstacles and human proxy.")
PY
echo "Checking launch file syntax..."
python3 -m py_compile "$ROBOT_DIR/launch/simulation.launch.py"
echo "PRO-BOT description validation completed successfully."

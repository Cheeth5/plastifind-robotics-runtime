#!/usr/bin/env python3
"""Static validation for PRO-BOT SLAM and Nav2 configuration files."""
import pathlib
import yaml

root = pathlib.Path("/opt/plastifind/ros2_ws/src/probot_description")
slam = yaml.safe_load((root / "config/slam_toolbox.yaml").read_text())
nav2 = yaml.safe_load((root / "config/nav2_params.yaml").read_text())
p = slam["slam_toolbox"]["ros__parameters"]
assert p["mode"] == "mapping"
assert p["scan_topic"] == "/scan"
assert (p["map_frame"], p["odom_frame"], p["base_frame"]) == ("map", "odom", "base_footprint")
for node in ("amcl", "controller_server", "local_costmap", "global_costmap", "planner_server", "behavior_server", "waypoint_follower"):
    assert node in nav2, f"Missing Nav2 node configuration: {node}"
assert nav2["local_costmap"]["local_costmap"]["ros__parameters"]["obstacle_layer"]["scan"]["topic"] == "/scan"
assert nav2["global_costmap"]["global_costmap"]["ros__parameters"]["static_layer"]["plugin"] == "nav2_costmap_2d::StaticLayer"
print("PRO-BOT SLAM and Nav2 configuration validation passed.")
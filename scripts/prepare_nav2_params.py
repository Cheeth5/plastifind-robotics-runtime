#!/usr/bin/env python3
"""Merge Nav2's complete Jazzy defaults with the PRO-BOT overrides."""
import copy
import os
import yaml

default_path = "/opt/ros/jazzy/share/nav2_bringup/params/nav2_params.yaml"
override_path = "/opt/plastifind/ros2_ws/install/probot_model/share/probot_model/config/nav2_params.yaml"
output_path = "/tmp/probot_nav2_params.yaml"

with open(default_path, encoding="utf-8") as stream:
    params = yaml.safe_load(stream)
with open(override_path, encoding="utf-8") as stream:
    overrides = yaml.safe_load(stream)

def deep_merge(target, source):
    for key, value in source.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            deep_merge(target[key], value)
        else:
            target[key] = copy.deepcopy(value)

deep_merge(params, overrides)

def set_param(node, key, value):
    params.setdefault(node, {}).setdefault("ros__parameters", {})[key] = value

set_param("bt_navigator", "robot_base_frame", "base_footprint")
set_param("bt_navigator", "odom_topic", "/diff_drive_controller/odom")
set_param("controller_server", "odom_topic", "/diff_drive_controller/odom")
set_param("local_costmap", "local_costmap", {}) if False else None
params["local_costmap"]["local_costmap"]["ros__parameters"]["robot_base_frame"] = "base_footprint"
params["global_costmap"]["global_costmap"]["ros__parameters"]["robot_base_frame"] = "base_footprint"
params["behavior_server"]["ros__parameters"]["robot_base_frame"] = "base_footprint"
params["behavior_server"]["ros__parameters"]["local_frame"] = "odom"
params["behavior_server"]["ros__parameters"]["global_frame"] = "map"
params["velocity_smoother"]["ros__parameters"]["odom_topic"] = "/diff_drive_controller/odom"
params["collision_monitor"]["ros__parameters"]["base_frame_id"] = "base_footprint"
# ros2_control diff_drive_controller subscribes in its namespace on ~/cmd_vel.
# With use_stamped_vel=false this is geometry_msgs/Twist at /diff_drive_controller/cmd_vel.
params["collision_monitor"]["ros__parameters"]["cmd_vel_out_topic"] = "/diff_drive_controller/cmd_vel"
params["docking_server"]["ros__parameters"]["base_frame"] = "base_footprint"
params["docking_server"]["ros__parameters"]["fixed_frame"] = "odom"

with open(output_path, "w", encoding="utf-8") as stream:
    yaml.safe_dump(params, stream, sort_keys=False)
print(f"Prepared merged Nav2 parameters: {output_path}")

import os
import yaml

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch_ros.actions import Node


def generate_launch_description():
    package_dir = get_package_share_directory('probot_model')
    slam_config = os.path.join(package_dir, 'config', 'slam_toolbox.yaml')
    simulation_launch = os.path.join(package_dir, 'launch', 'simulation.launch.py')

    with open(slam_config, 'r', encoding='utf-8') as config_file:
        slam_parameters = yaml.safe_load(config_file)['slam_toolbox']['ros__parameters']

    # Keep the complete tuned configuration, and explicitly pass the parameters
    # that SLAM Toolbox must have at startup as ROS command-line overrides.
    required_parameters = [
        'use_sim_time:=true',
        'mode:=mapping',
        'map_frame:=map',
        'odom_frame:=odom',
        'base_frame:=base_footprint',
        'scan_topic:=/scan',
    ]
    slam_arguments = ['--ros-args']
    for parameter in required_parameters:
        slam_arguments.extend(['-p', parameter])

    simulation = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(simulation_launch)
    )

    slam = Node(
        package='slam_toolbox',
        executable='async_slam_toolbox_node',
        name='slam_toolbox',
        output='screen',
        parameters=[slam_parameters, {'use_sim_time': True}],
        arguments=slam_arguments,
    )

    return LaunchDescription([simulation, slam])

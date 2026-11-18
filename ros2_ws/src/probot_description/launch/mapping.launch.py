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

    simulation = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(simulation_launch)
    )

    slam = Node(
        package='slam_toolbox',
        executable='async_slam_toolbox_node',
        name='slam_toolbox',
        output='screen',
        parameters=[slam_parameters, {'use_sim_time': True}]
    )

    return LaunchDescription([simulation, slam])
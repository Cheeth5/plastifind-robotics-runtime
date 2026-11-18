import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription
from launch.launch_description_sources import PythonLaunchDescriptionSource


def generate_launch_description():
    package_dir = get_package_share_directory('probot_model')
    slam_toolbox_dir = get_package_share_directory('slam_toolbox')

    simulation_launch = os.path.join(
        package_dir, 'launch', 'simulation.launch.py'
    )
    slam_launch = os.path.join(
        slam_toolbox_dir, 'launch', 'online_async_launch.py'
    )
    slam_config = os.path.join(
        package_dir, 'config', 'slam_toolbox.yaml'
    )

    simulation = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(simulation_launch)
    )

    # SLAM Toolbox's async node is a LifecycleNode. Its upstream launch
    # configures and activates it before it processes parameters and scans.
    slam = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(slam_launch),
        launch_arguments={
            'slam_params_file': slam_config,
            'use_sim_time': 'true',
            'autostart': 'true',
            'use_lifecycle_manager': 'false',
        }.items(),
    )

    return LaunchDescription([simulation, slam])

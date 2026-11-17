import os

from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription, TimerAction
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch_ros.actions import Node
from launch.substitutions import Command
from launch_ros.parameter_descriptions import ParameterValue


def generate_launch_description():
    package_dir = get_package_share_directory('probot_description')
    gazebo_dir = get_package_share_directory('ros_gz_sim')

    robot_description_file = os.path.join(
        package_dir, 'urdf', 'probot.urdf.xacro'
    )
    world_file = os.path.join(
        package_dir, 'worlds', 'probot_test_world.sdf'
    )
    controller_config = os.path.join(
        package_dir, 'config', 'probot_controllers.yaml'
    )

    robot_description = ParameterValue(
        Command([
            'xacro ',
            robot_description_file,
            ' controller_params_file:=',
            controller_config
        ]),
        value_type=str
    )

    # Server-only mode is intentional: cloud CI and container execution
    # must not require a desktop, X server, or GPU-backed GUI.
    gazebo = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(gazebo_dir, 'launch', 'gz_sim.launch.py')
        ),
        launch_arguments={
            'gz_args': ['-s -r ', world_file]
        }.items()
    )

    robot_state_publisher = Node(
        package='robot_state_publisher',
        executable='robot_state_publisher',
        parameters=[{
            'robot_description': robot_description,
            'use_sim_time': True
        }],
        output='screen'
    )

    spawn_robot = Node(
        package='ros_gz_sim',
        executable='create',
        arguments=[
            '-name', 'probot',
            '-topic', 'robot_description',
            '-x', '0',
            '-y', '0',
            '-z', '0'
        ],
        output='screen'
    )

    joint_state_broadcaster = Node(
        package='controller_manager',
        executable='spawner',
        arguments=[
            'joint_state_broadcaster',
            '--controller-manager', '/controller_manager',
            '--param-file', controller_config
        ],
        output='screen'
    )

    diff_drive_controller = Node(
        package='controller_manager',
        executable='spawner',
        arguments=[
            'diff_drive_controller',
            '--controller-manager', '/controller_manager',
            '--param-file', controller_config
        ],
        output='screen'
    )

    start_controllers = TimerAction(
        period=8.0,
        actions=[
            joint_state_broadcaster,
            diff_drive_controller
        ]
    )

    return LaunchDescription([
        gazebo,
        robot_state_publisher,
        spawn_robot,
        start_controllers
    ])

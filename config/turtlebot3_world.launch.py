#!/usr/bin/env python3
"""Launch the TurtleBot 3 world.

Adds two things to the launch file shipped with turtlebot3_simulations:

    gui:=false      run the simulation without the Gazebo window
    world markers   publish the world geometry for Foxglove

Closing the Gazebo window leaves the simulation running.
"""

import os

from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import (
    AppendEnvironmentVariable,
    DeclareLaunchArgument,
    ExecuteProcess,
    IncludeLaunchDescription,
)
from launch.conditions import IfCondition
from launch.launch_description_sources import PythonLaunchDescriptionSource
from launch.substitutions import LaunchConfiguration


def generate_launch_description():
    turtlebot3_gazebo = get_package_share_directory('turtlebot3_gazebo')
    ros_gz_sim = get_package_share_directory('ros_gz_sim')
    launch_file_dir = os.path.join(turtlebot3_gazebo, 'launch')
    this_dir = os.path.dirname(os.path.realpath(__file__))

    use_sim_time = LaunchConfiguration('use_sim_time', default='true')
    gui = LaunchConfiguration('gui', default='true')
    x_pose = LaunchConfiguration('x_pose', default='-2.0')
    y_pose = LaunchConfiguration('y_pose', default='-0.5')

    world = os.path.join(turtlebot3_gazebo, 'worlds', 'turtlebot3_world.world')

    gzserver_cmd = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(ros_gz_sim, 'launch', 'gz_sim.launch.py')
        ),
        launch_arguments={
            'gz_args': ['-r -s -v2 ', world],
            'on_exit_shutdown': 'true',
        }.items(),
    )

    # on_exit_shutdown must be an explicit 'false': closing the Gazebo
    # window must leave the simulation running
    gzclient_cmd = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(ros_gz_sim, 'launch', 'gz_sim.launch.py')
        ),
        condition=IfCondition(gui),
        launch_arguments={
            'gz_args': '-g -v2 ',
            'on_exit_shutdown': 'false',
        }.items(),
    )

    robot_state_publisher_cmd = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(launch_file_dir, 'robot_state_publisher.launch.py')
        ),
        launch_arguments={'use_sim_time': use_sim_time}.items(),
    )

    spawn_turtlebot_cmd = IncludeLaunchDescription(
        PythonLaunchDescriptionSource(
            os.path.join(launch_file_dir, 'spawn_turtlebot3.launch.py')
        ),
        launch_arguments={'x_pose': x_pose, 'y_pose': y_pose}.items(),
    )

    # The spawn pose is passed through so the world frame lines up with odom
    world_markers_cmd = ExecuteProcess(
        cmd=[
            'python3',
            os.path.join(this_dir, 'world_markers.py'),
            '--ros-args',
            '-p',
            ['x_pose:=', x_pose],
            '-p',
            ['y_pose:=', y_pose],
        ],
        output='screen',
    )

    set_env_vars_resources = AppendEnvironmentVariable(
        'GZ_SIM_RESOURCE_PATH', os.path.join(turtlebot3_gazebo, 'models')
    )

    ld = LaunchDescription()

    ld.add_action(
        DeclareLaunchArgument(
            'gui', default_value='true', description='Open the Gazebo window'
        )
    )
    ld.add_action(
        DeclareLaunchArgument(
            'x_pose',
            default_value='-2.0',
            description='Robot spawn position, x',
        )
    )
    ld.add_action(
        DeclareLaunchArgument(
            'y_pose',
            default_value='-0.5',
            description='Robot spawn position, y',
        )
    )

    ld.add_action(set_env_vars_resources)
    ld.add_action(gzserver_cmd)
    ld.add_action(gzclient_cmd)
    ld.add_action(spawn_turtlebot_cmd)
    ld.add_action(robot_state_publisher_cmd)
    ld.add_action(world_markers_cmd)

    return ld

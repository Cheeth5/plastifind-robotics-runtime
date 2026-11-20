# PlastiFind Digital Lab — headless robotics runtime
# ROS 2 Jazzy targets Ubuntu 24.04; ros_gz provides the Gazebo Harmonic bridge.
FROM ros:jazzy-ros-base

ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip \
    python3-yaml \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool \
    git curl wget build-essential cmake \
    ros-jazzy-ros-gz \
    ros-jazzy-navigation2 \
    ros-jazzy-nav2-bringup \
    ros-jazzy-slam-toolbox \
    ros-jazzy-robot-localization \
    ros-jazzy-xacro \
    ros-jazzy-robot-state-publisher \
    ros-jazzy-joint-state-publisher \
    ros-jazzy-ros2-control \
    ros-jazzy-ros2-controllers \
    ros-jazzy-gz-ros2-control \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/plastifind
COPY ros2_ws/ /opt/plastifind/ros2_ws/
COPY scripts/ /opt/plastifind/scripts/
COPY docker/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh \
    /opt/plastifind/scripts/healthcheck.sh \
    /opt/plastifind/scripts/validate_probot_description.sh \
    /opt/plastifind/scripts/validate_slam_config.py \
    && source /opt/ros/jazzy/setup.bash \
    && cd /opt/plastifind/ros2_ws \
    && rosdep update \
    && rosdep install --from-paths src --ignore-src -r -y \
    && colcon build --symlink-install \
    && /opt/plastifind/scripts/validate_probot_description.sh \
    && /opt/plastifind/scripts/validate_slam_config.py

ENV ROS_DISTRO=jazzy
ENV RMW_IMPLEMENTATION=rmw_fastrtps_cpp
ENV PLASTIFIND_ROS_WS=/opt/plastifind/ros2_ws

ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash"]
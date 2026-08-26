##############
# Base image #
##############
FROM osrf/ros:jazzy-desktop-full AS base

LABEL description="ROS 2 Turtlebot 3 Jazzy docker image"
LABEL version="1.0"

ARG AMENT_WORKSPACE_DIR="/turtlebot_ws"
WORKDIR $AMENT_WORKSPACE_DIR

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
        apt-get -y --quiet --no-install-recommends install \
    # Core dependencies
    git \
    mesa-utils \
    python3-colcon-clean \
    python3-colcon-common-extensions \
    python3-osrf-pycommon \
    python3-vcstool \
    # Dev tools
    nano \
    ack \
    bmon \
    cloc \
    gdb \
    htop \
    iperf3 \
    iputils-ping \
    net-tools \
    plocate \
    psmisc \
    tmux \
    xterm \
    # ROS dependencies
    ros-"$ROS_DISTRO"-compressed-image-transport \
    ros-"$ROS_DISTRO"-compressed-depth-image-transport \
    ros-"$ROS_DISTRO"-image-transport \
    ros-"$ROS_DISTRO"-point-cloud-transport \
    ros-"$ROS_DISTRO"-point-cloud-transport-plugins \
    ros-"$ROS_DISTRO"-rmw-zenoh-cpp \
    # ROS tools
    ros-"$ROS_DISTRO"-rqt-common-plugins \
    ros-"$ROS_DISTRO"-rqt-robot-steering \
    ros-"$ROS_DISTRO"-rqt-tf-tree \
    ros-"$ROS_DISTRO"-rviz2 \
    ros-"$ROS_DISTRO"-foxglove-bridge \
    # Turtlebot 3 pc setup
    ros-"$ROS_DISTRO"-cartographer \
    ros-"$ROS_DISTRO"-cartographer-ros \
    ros-"$ROS_DISTRO"-navigation2 \
    ros-"$ROS_DISTRO"-nav2-bringup \
    # Perception + Apriltags
    ros-"$ROS_DISTRO"-apriltag-ros \
 && rm -rf /var/lib/apt/lists/*

# Setup Zenoh ROS2 RMW
ENV RMW_IMPLEMENTATION=rmw_zenoh_cpp

# Enable ROS log colorised output
ENV RCUTILS_COLORIZED_OUTPUT=1

# -----------------------------------------------------------------------

#####################
# Development layer #
#####################
FROM base AS dev

# Clone turtlebot3 repo dependencies not available through apt
COPY ./src/.repos $AMENT_WORKSPACE_DIR/src/.repos
RUN vcs import --input src/.repos src

# # Source ROS setup for dependencies and build our code
RUN . /opt/ros/"$ROS_DISTRO"/setup.sh \
    && colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release

# Copy pre-configured rviz layout configuration
COPY ./config/default.rviz /root/.rviz2/default.rviz

RUN echo "alias rsource='source ${AMENT_WORKSPACE_DIR}/install/setup.bash'" >> /root/.bashrc \
 && echo "alias rbuild='(cd ${AMENT_WORKSPACE_DIR} && colcon build --symlink-install)'" >> /root/.bashrc \
 && echo "alias rclean='(cd ${AMENT_WORKSPACE_DIR} && colcon clean workspace -y)'" >> /root/.bashrc \
 && echo "rsource || source /opt/ros/${ROS_DISTRO}/setup.bash" >> /root/.bashrc

# Don't run any ROS commands by default
CMD ["bash"]

# -----------------------------------------------------------------------

#####################
# Runtime layer #
#####################
FROM dev AS runtime

CMD ["bash"]

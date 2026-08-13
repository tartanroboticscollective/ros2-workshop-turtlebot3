##############
# Base image #
##############
FROM ros:jazzy-ros-base AS base

LABEL description="ROS 2 Turtlebot 3 Jazzy docker image"
LABEL version="1.0"

ARG AMENT_WORKSPACE_DIR="/turtlebot_ws"
WORKDIR $AMENT_WORKSPACE_DIR

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
        apt-get -y --quiet --no-install-recommends install \
    # Full desktop install (rviz, demos, tutorials, ...)
    ros-"$ROS_DISTRO"-desktop-full \
    # Core dependencies
    git \
    mesa-utils \
    python3-colcon-clean \
    python3-colcon-common-extensions \
    python3-osrf-pycommon \
    python3-vcstool \
    # Dev tools
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
 && rm -rf /var/lib/apt/lists/*

######################
# Browser-based GUI  #
######################
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive \
        apt-get -y --quiet --no-install-recommends install \
    dbus-x11 \
    novnc \
    openbox \
    tigervnc-common \
    tigervnc-standalone-server \
    websockify \
    x11-xserver-utils \
 && rm -rf /var/lib/apt/lists/*

COPY docker/start-gui.sh /usr/local/bin/start-gui
RUN chmod +x /usr/local/bin/start-gui

# Render to the container's own X server
ENV DISPLAY=:1
ENV QT_X11_NO_MITSHM=1

# Setup Zenoh ROS2 RMW
ENV RMW_IMPLEMENTATION=rmw_zenoh_cpp

# Enable ROS log colorised output
ENV RCUTILS_COLORIZED_OUTPUT=1

# -----------------------------------------------------------------------

#####################
# Development layer #
#####################
FROM base AS dev

# Clone turtlebot3 repo dependencies not available through apt and build
# them. The sources are dropped afterwards; the workspace src directory is
# mounted from the host at runtime.
COPY ./src/.repos $AMENT_WORKSPACE_DIR/src/.repos
RUN vcs import --input src/.repos src \
 && . /opt/ros/"$ROS_DISTRO"/setup.sh \
 && colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release \
 && find src -mindepth 1 -maxdepth 1 ! -name .repos -exec rm -rf {} +

# Copy pre-configured rviz layout, launch files and visualisation config
COPY ./config/default.rviz /root/.rviz2/default.rviz
COPY ./config $AMENT_WORKSPACE_DIR/config

RUN echo "alias rsource='source ${AMENT_WORKSPACE_DIR}/install/setup.bash'" >> /root/.bashrc \
 && echo "alias rbuild='(cd ${AMENT_WORKSPACE_DIR} && colcon build --cmake-args -DCMAKE_BUILD_TYPE=Release)'" >> /root/.bashrc \
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

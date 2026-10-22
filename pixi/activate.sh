# Workshop environment, sourced by pixi on activation

# Setup Zenoh ROS2 RMW
export RMW_IMPLEMENTATION=rmw_zenoh_cpp
export ZENOH_ROUTER_CONFIG_URI="$PIXI_PROJECT_ROOT/zenoh/ROUTER_CONFIG.json5"
export ZENOH_SESSION_CONFIG_URI="$PIXI_PROJECT_ROOT/zenoh/SESSION_CONFIG.json5"

# Enable ROS log colorised output
export RCUTILS_COLORIZED_OUTPUT=1

# Keep Gazebo transport on loopback, multicast discovery fails on some networks
export GZ_IP="${GZ_IP:-127.0.0.1}"

export TURTLEBOT3_MODEL="${TURTLEBOT3_MODEL:-burger_cam}"

# Workshop packages, once built with `pixi run build`
if [ -f "$PIXI_PROJECT_ROOT/install/setup.sh" ]; then
    . "$PIXI_PROJECT_ROOT/install/setup.sh"
fi

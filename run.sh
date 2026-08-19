#!/bin/bash
# ----------------------------------------------------------------
# Build podman dev stage and add local code for live development
# ----------------------------------------------------------------

BASH_CMD="ros2 run rmw_zenoh_cpp rmw_zenohd"
TURTLEBOT3_MODEL=burger

# Function to print usage
usage() {
    echo "
Usage: run.sh [-b|bash] [-h|--help]

Where:
    -b | bash       Open bash in podman container
    -h | --help     Show this help message
    "
    exit 1
}

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -b|bash)
            BASH_CMD=bash
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
    shift
done

# GUI setup
xhost + >/dev/null

# Run podman image with local code volumes for development
podman run -it --root /disk/scratch/$USER/root --rm --net host --privileged \
    --name ros2-workshop-turtlebot3 \
    -e DISPLAY="$DISPLAY" -v /tmp/.X11-unix/:/tmp/.X11-unix \
    -e QT_X11_NO_MITSHM=1 \
    -e XAUTHORITY="${XAUTHORITY}" \
    -e XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    -e TURTLEBOT3_MODEL="$TURTLEBOT3_MODEL" \
    -v ./config/default.rviz:/root/.rviz2/default.rviz \
    -v ./src:/turtlebot_ws/src \
    docker.io/tartanroboticscollective/ros2-workshop-turtlebot3 $BASH_CMD

#!/bin/bash
# ----------------------------------------------------------------
# Build docker dev stage and add local code for live development
# ----------------------------------------------------------------

BASH_CMD="ros2 run rmw_zenoh_cpp rmw_zenohd"
TURTLEBOT3_MODEL=burger

# Function to print usage
usage() {
    echo "
Usage: dev.sh [-b|bash] [-h|--help]

Where:
    -b | bash       Open bash in docker container (Default in dev.sh)
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

# Build docker image up to dev stage
DOCKER_BUILDKIT=1 docker build \
    -t ros2-workshop-turtlebot3:latest-dev \
    -f docker/Dockerfile --target dev .

# GUI setup
xhost + >/dev/null

# Run docker image with local code volumes for development
docker run -it --rm --net host --privileged \
    --name ros2-workshop-turtlebot3 \
    -e DISPLAY="$DISPLAY" -v /tmp/.X11-unix/:/tmp/.X11-unix \
    -e QT_X11_NO_MITSHM=1 \
    -e XAUTHORITY="${XAUTHORITY}" \
    -e XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    -e TURTLEBOT3_MODEL="$TURTLEBOT3_MODEL" \
    -v /dev:/dev \
    -v /tmp:/tmp \
    -v /etc/localtime:/etc/localtime:ro \
    -v ./config:/turtlebot_ws/config \
    -v ./src:/turtlebot_ws/src \
    ros2-workshop-turtlebot3:latest-dev $BASH_CMD

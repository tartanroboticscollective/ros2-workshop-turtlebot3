#!/bin/bash
# ----------------------------------------------------------------
# Build docker dev stage and add local code for live development
# ----------------------------------------------------------------

BASH_CMD="bash"
TURTLEBOT3_MODEL=burger

# Function to print usage
usage() {
    echo "
Usage: run.sh [-b|bash] [-h|--help]

Where:
    -b | bash       Open bash in docker container
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

# Run docker image with local code volumes for development
docker exec -it ros2-workshop-turtlebot3 $BASH_CMD

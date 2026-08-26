#!/bin/bash
# ----------------------------------------------------------------
# Attach to already running workshop docker container
# ----------------------------------------------------------------

BASH_CMD="bash"
TURTLEBOT3_MODEL=burger_cam

# Function to print usage
usage() {
    echo "
Usage: attach.sh [-b|bash] [-m|--model] turtlebot3_model [-h|--help]

Where:
    -b | bash       Open bash in docker container (Default in attach.sh)
    -m | --model    Set turtlebot3 model (e.g. "burger_cam" or "waffle_pi")
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
        -m|--model)
            if [[ -n "$2" && "$2" != -* ]]; then
                TURTLEBOT3_MODEL="$2"
                shift
            else
                echo "Error: Missing turtlebot3 model name after $1"
                usage
            fi
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

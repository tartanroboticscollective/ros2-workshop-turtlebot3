#!/usr/bin/env bash
# ----------------------------------------------------------------
# Run Simulation - Real Teleop session
# ----------------------------------------------------------------

TURTLEBOT3_MODEL=waffle_pi
TURTLEBOT3_IP=""

# Function to print usage
usage() {
    cat <<EOF
Usage: start_realteleop.sh -ip <ip> [-m|--model <model>] [-h|--help]

Options:
    -m, --model <model>    Set the TurtleBot3 model:
                           burger_cam or waffle_pi

    -ip <ip>               IP address of the remote Zenoh router.
                           Required.

    -h, --help             Show this help message.

Examples:
    start_realteleop.sh -ip 192.168.0.1
    start_realteleop.sh -ip 192.168.0.1 -m burger_cam
    start_realteleop.sh --model waffle_pi -ip 192.168.0.1
EOF
    exit 1
}

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -m|--model)
            if [[ -n "$2" && "$2" != -* ]]; then
                case "$2" in
                    burger_cam|waffle_pi)
                        TURTLEBOT3_MODEL="$2"
                        shift 2
                        ;;
                    *)
                        echo "Error: Invalid turtlebot3 model '$2'"
                        usage
                        ;;
                esac
            else
                echo "Error: Missing turtlebot3 model name after $1"
                usage
            fi
            ;;

        -ip)
            if [[ -n "$2" && "$2" != -* ]]; then
                TURTLEBOT3_IP="$2"
                shift 2
            else
                echo "Error: Missing IP address after $1"
                usage
            fi
            ;;

        -h|--help)
            usage
            ;;

        *)
            break
            ;;
    esac
done

if [ -z "${TURTLEBOT3_IP}" ]; then
    echo "Error: Missing turtlebot3 ip, please use -ip followed by the Turtlebot's ip"
    usage
fi

SESSION_NAME="ros2-workshop"
CONTAINER_NAME="ros2-workshop-turtlebot3"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
WS_PATH="${SCRIPT_PATH%/*/*}"

# ================================================================
# Docker helpers
# ================================================================

wait_for_container() {
    echo "Waiting for container '$CONTAINER_NAME' to be running..."

    while true; do
        if docker ps \
            --filter "name=^${CONTAINER_NAME}$" \
            --filter "status=running" \
            --format '{{.Names}}' |
        grep -qx "$CONTAINER_NAME"
        then
            echo "Container '$CONTAINER_NAME' is running."
            return 0
        fi

        sleep 1
    done
}

exec_in_container() {
    docker exec -it "$CONTAINER_NAME" bash -ic "$1"
}


# ================================================================
# Commands run by individual panes
# ================================================================

case "${1:-}" in

    terminal)
        wait_for_container
        echo "Opening shell in $CONTAINER_NAME..."
        exec docker exec -it "$CONTAINER_NAME" /bin/bash
        ;;

    zenoh)
        echo "Running run.sh..."
        $WS_PATH/docker/run.sh -m $TURTLEBOT3_MODEL -j $TURTLEBOT3_IP
        ;;

    teleop)
        wait_for_container
        echo "Starting TurtleBot3 teleop..."
        exec_in_container "ros2 run turtlebot3_teleop teleop_keyboard --ros-args"
        ;;

    # gazebo)
    #     wait_for_container
    #     echo "Starting TurtleBot3 Gazebo..."
    #     exec_in_container "ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py"
    #     ;;

    rviz)
        wait_for_container
        echo "Starting RViz2..."
        exec_in_container "ros2 run rviz2 rviz2 --ros-args -p use_sim_time:=true"
        ;;

    "")
        # Main launcher.
        ;;

    *)
        echo "Unknown command: $1"
        exit 1
        ;;

esac


# ================================================================
# Create tmux session
#
# ┌──────────────────────────────────┬─────────────────┐
# │                                  │                 │
# │          Main terminal           │     Teleop      │
# │                                  │                 │
# ├──────────────────┬───────────────┼─────────────────┤
# │      Zenoh       │     RViz2     │     EMPTY       │
# └──────────────────┴───────────────┴─────────────────┘
# ================================================================

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    exec tmux attach-session -t "$SESSION_NAME"
fi

tmux new-session -d -s "$SESSION_NAME"

# Main / Zenoh
MAIN_PANE=$(tmux display-message -p -t "$SESSION_NAME:0.0" '#{pane_id}')

ZENOH_PANE=$(tmux split-window \
    -v -t "$MAIN_PANE" -l '30%' -P -F '#{pane_id}')

# Main / Teleop
TELEOP_PANE=$(tmux split-window \
    -h -t "$MAIN_PANE" -l '33%' -P -F '#{pane_id}')

# Zenoh / RViz2 / EMPTY
RVIZ_PANE=$(tmux split-window \
    -h -t "$ZENOH_PANE" -l '66%' -P -F '#{pane_id}')

GAZEBO_PANE=$(tmux split-window \
    -h -t "$RVIZ_PANE" -l '50%' -P -F '#{pane_id}')


# ================================================================
# Start pane processes
# ================================================================

tmux send-keys -t "$MAIN_PANE" \
    "bash '$SCRIPT_PATH' -ip $TURTLEBOT3_IP terminal" C-m

tmux send-keys -t "$TELEOP_PANE" \
    "bash '$SCRIPT_PATH' -ip $TURTLEBOT3_IP teleop" C-m

tmux send-keys -t "$ZENOH_PANE" \
    "bash '$SCRIPT_PATH' -ip $TURTLEBOT3_IP zenoh" C-m

tmux send-keys -t "$RVIZ_PANE" \
    "bash '$SCRIPT_PATH' -ip $TURTLEBOT3_IP rviz" C-m

tmux send-keys -t "$GAZEBO_PANE" \
    "bash '$SCRIPT_PATH' -ip $TURTLEBOT3_IP terminal" C-m


# Start with keyboard focus on Teleop.
tmux select-pane -t "$TELEOP_PANE"

exec tmux attach-session -t "$SESSION_NAME"

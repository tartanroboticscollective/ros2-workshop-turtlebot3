#!/usr/bin/env bash

SESSION_NAME="ros2-workshop"
CONTAINER_NAME="ros2-workshop-turtlebot3"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"


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
        ./run.sh
        ;;

    teleop)
        wait_for_container
        echo "Starting TurtleBot3 teleop..."
        exec_in_container "ros2 run turtlebot3_teleop teleop_keyboard"
        ;;

    gazebo)
        wait_for_container
        echo "Starting TurtleBot3 Gazebo..."
        exec_in_container "ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py"
        ;;

    cartographer)
        wait_for_container
        echo "Starting Cartographer..."
        exec_in_container "ros2 launch turtlebot3_cartographer cartographer.launch.py"
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
# │      Zenoh       │ Cartographer  │     Gazebo      │
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

# Zenoh / Cartographer / Gazebo
CARTOGRAPHER_PANE=$(tmux split-window \
    -h -t "$ZENOH_PANE" -l '66%' -P -F '#{pane_id}')

GAZEBO_PANE=$(tmux split-window \
    -h -t "$CARTOGRAPHER_PANE" -l '50%' -P -F '#{pane_id}')


# ================================================================
# Start pane processes
# ================================================================

tmux send-keys -t "$MAIN_PANE" \
    "bash '$SCRIPT_PATH' terminal" C-m

tmux send-keys -t "$MAIN_PANE" \
    "ros2 run nav2_map_server map_saver_cli -f /turtlebot_ws/maps/map"

tmux send-keys -t "$TELEOP_PANE" \
    "bash '$SCRIPT_PATH' teleop" C-m

tmux send-keys -t "$ZENOH_PANE" \
    "bash '$SCRIPT_PATH' zenoh" C-m

tmux send-keys -t "$CARTOGRAPHER_PANE" \
    "bash '$SCRIPT_PATH' cartographer" C-m

tmux send-keys -t "$GAZEBO_PANE" \
    "bash '$SCRIPT_PATH' gazebo" C-m


# Start with keyboard focus on Teleop.
tmux select-pane -t "$TELEOP_PANE"

exec tmux attach-session -t "$SESSION_NAME"

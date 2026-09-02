#!/usr/bin/env bash

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
        if podman --root /disk/scratch/$USER/root ps \
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
    podman exec --root /disk/scratch/$USER/root -it "$CONTAINER_NAME" bash -ic "$1"
}


# ================================================================
# Commands run by individual panes
# ================================================================

case "${1:-}" in

    terminal)
        wait_for_container
        echo "Opening shell in $CONTAINER_NAME..."
        exec podman exec -it --root /disk/scratch/$USER/root "$CONTAINER_NAME" /bin/bash
        ;;

    zenoh)
        echo "Running run.sh..."
        $WS_PATH/docker/run.sh
        ;;

    teleop)
        wait_for_container
        echo "Starting TurtleBot3 teleop..."
        exec_in_container "ros2 run turtlebot3_teleop teleop_keyboard --ros-args -p use_sim_time:=true"
        ;;

    gazebo)
        wait_for_container
        echo "Starting TurtleBot3 Gazebo..."
        exec_in_container "ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py"
        ;;

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
# │      Zenoh       │     RViz2     │     Gazebo      │
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

# Zenoh / RViz2 / Gazebo
RVIZ_PANE=$(tmux split-window \
    -h -t "$ZENOH_PANE" -l '66%' -P -F '#{pane_id}')

GAZEBO_PANE=$(tmux split-window \
    -h -t "$RVIZ_PANE" -l '50%' -P -F '#{pane_id}')


# ================================================================
# Start pane processes
# ================================================================

tmux send-keys -t "$MAIN_PANE" \
    "bash '$SCRIPT_PATH' terminal" C-m

tmux send-keys -t "$TELEOP_PANE" \
    "bash '$SCRIPT_PATH' teleop" C-m

tmux send-keys -t "$ZENOH_PANE" \
    "bash '$SCRIPT_PATH' zenoh" C-m

tmux send-keys -t "$RVIZ_PANE" \
    "bash '$SCRIPT_PATH' rviz" C-m

tmux send-keys -t "$GAZEBO_PANE" \
    "bash '$SCRIPT_PATH' gazebo" C-m


# Start with keyboard focus on Teleop.
tmux select-pane -t "$TELEOP_PANE"

exec tmux attach-session -t "$SESSION_NAME"

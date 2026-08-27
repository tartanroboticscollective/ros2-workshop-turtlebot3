#!/usr/bin/env bash

SESSION_NAME="ros2-join"
CONTAINER_NAME="ros2-workshop-turtlebot3"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
WS_PATH="${SCRIPT_PATH%/*/*}"

TURTLE_NAME="turtle_$((1 + $RANDOM % 100000))"
RANDOM_X=$((1 + $RANDOM % 10))
RANDOM_Y=$((1 + $RANDOM % 10))
RANDOM_T=$(bc <<<"scale=2; $((1 + $RANDOM % 314)) / 100")

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
        $WS_PATH/docker/run.sh
        ;;

    teleop)
        wait_for_container
        echo "Starting Turtle teleop..."
        echo $2
        exec_in_container "ros2 run turtlesim turtle_teleop_key --ros-args --remap __node:=$2 --remap turtle1/cmd_vel:=$2/cmd_vel"
        ;;

    turtle_spawn)
        wait_for_container
        echo "Spawning new turtle..."
        exec_in_container "ros2 service call /spawn turtlesim/srv/Spawn \"{x: $RANDOM_X, y: $RANDOM_Y, theta: $RANDOM_T, name: '$2'}\""
        ;;

    rqt_graph)
        wait_for_container
        echo "Starting rqt_graph..."
        exec_in_container "rqt_graph"
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
# │      Zenoh       │   rqt_graph   │    TurtleSim    │
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

# Zenoh / rqt_graph / TurtleSim
# RQT_PANE=$(tmux split-window \
    #     -h -t "$ZENOH_PANE" -l '66%' -P -F '#{pane_id}')

TURTLE_SPAWN_PANE=$(tmux split-window \
    -h -t "$ZENOH_PANE" -l '50%' -P -F '#{pane_id}')


# ================================================================
# Start pane processes
# ================================================================

tmux send-keys -t "$MAIN_PANE" \
    "bash '$SCRIPT_PATH' terminal" C-m

tmux send-keys -t "$TELEOP_PANE" \
    "bash '$SCRIPT_PATH' teleop $TURTLE_NAME" C-m

tmux send-keys -t "$ZENOH_PANE" \
    "bash '$SCRIPT_PATH' zenoh" C-m

# tmux send-keys -t "$RQT_PANE" \
    #     "bash '$SCRIPT_PATH' rqt_graph" C-m

tmux send-keys -t "$TURTLE_SPAWN_PANE" \
    "bash '$SCRIPT_PATH' turtle_spawn $TURTLE_NAME" C-m


# Start with keyboard focus on Teleop.
tmux select-pane -t "$TELEOP_PANE"

exec tmux attach-session -t "$SESSION_NAME"

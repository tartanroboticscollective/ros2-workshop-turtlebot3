#!/usr/bin/env bash

# tiny fix amd gpu PLEASE DONT REMOVE
#xhost +


SESSION_NAME="ros2-workshop"
CONTAINER_NAME="ros2-workshop-turtlebot3"
COMPOSE_SERVICE="ros2-workshop-turtlebot3"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
WS_PATH="$(dirname "$SCRIPT_PATH")"
COMPOSE_FILE="$WS_PATH/docker/docker-compose.yml"
COMPOSE_ENV_FILE="$WS_PATH/docker/turtlebot.env"

# ================================================================
# Docker helpers
# ================================================================

compose() {
    env \
        "AMENT_WORKSPACE_DIR=/turtlebot_ws" \
        "DISPLAY=${DISPLAY:-:0}" \
        "GID=$(id -g)" \
        "ROBOT_IP=${ROBOT_IP:-127.0.0.1}" \
        "TURTLEBOT3_MODEL=burger" \
        "UID=$(id -u)" \
        "USERNAME=${USERNAME:-${USER:-developer}}" \
        "WS_PATH=$WS_PATH" \
        docker compose \
        --env-file "$COMPOSE_ENV_FILE" \
        -f "$COMPOSE_FILE" \
        "$@"
}

usage() {
    cat <<'EOF'
Usage: dev_session.sh [--stop]

  --stop    Stop the tmux session and run Docker Compose down.
EOF
}

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
    compose exec "$COMPOSE_SERVICE" bash -ic "$1"
}

start_zenoh() {
    wait_for_container

    if compose exec -T "$COMPOSE_SERVICE" pgrep -x rmw_zenohd >/dev/null 2>&1; then
        echo "Zenoh router is already running in $CONTAINER_NAME."
        return 0
    fi

    echo "Starting Zenoh router in $CONTAINER_NAME..."
    exec_in_container "exec ros2 run rmw_zenoh_cpp rmw_zenohd"
}

start_compose() {
    echo "Starting Docker Compose service '$COMPOSE_SERVICE'..."
    compose up --build --detach
}

stop_session() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "Stopping tmux session '$SESSION_NAME'..."
        tmux kill-session -t "$SESSION_NAME"
    fi

    echo "Stopping Docker Compose service '$COMPOSE_SERVICE'..."
    compose down
}


# ================================================================
# Commands run by individual panes
# ================================================================

case "${1:-}" in

    --stop)
        stop_session
        exit $?
        ;;

    -h|--help)
        usage
        exit 0
        ;;

    terminal)
        wait_for_container
        echo "Opening shell in $CONTAINER_NAME..."
        compose exec "$COMPOSE_SERVICE" /bin/bash
        exit $?
        ;;

    zenoh)
        start_zenoh
        exit $?
        ;;

    teleop)
        wait_for_container
        echo "Starting TurtleBot3 Burger teleop..."
        exec_in_container "ros2 run turtlebot3_teleop teleop_keyboard --ros-args -p use_sim_time:=true"
        exit $?
        ;;

    gazebo)
        wait_for_container
        echo "Starting TurtleBot3 Burger Gazebo..."
        exec_in_container "ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py"
        exit $?
        ;;

    rviz)
        wait_for_container
        echo "Starting RViz2..."
        exec_in_container "ros2 run rviz2 rviz2 --ros-args -p use_sim_time:=true"
        exit $?
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
# │          Main terminal           │      Zenoh      │
# │                                  │                 │
# │                                  ├─────────────────┤
# │                                  │       T2        │
# ├──────────────────────────────────┴─────────────────┤
# │     EMPTY                        |       T3        │
# └────────────────────────────────────────────────────┘
# ================================================================

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    exec tmux attach-session -t "$SESSION_NAME"
fi

start_compose || exit $?

tmux new-session -d -s "$SESSION_NAME"

# Main / Gazebo
MAIN_PANE=$(tmux display-message -p -t "$SESSION_NAME:0.0" '#{pane_id}')


# Main / Teleop
ZENOH_PANE=$(tmux split-window \
    -h -t "$MAIN_PANE" -P -F '#{pane_id}')


EMPTY_PANE=$(tmux split-window \
    -v -t "$MAIN_PANE" -P -F '#{pane_id}')

T_2=$(tmux split-window \
    -v -t "$ZENOH_PANE" -P -F '#{pane_id}')

T_3=$(tmux split-window \
    -v -t "$ZENOH_PANE" -P -F '#{pane_id}')



# ================================================================
# Start pane processes
# ================================================================

tmux send-keys -t "$MAIN_PANE" \
    "bash '$SCRIPT_PATH' terminal" C-m

tmux send-keys -t "$ZENOH_PANE" \
    "bash '$SCRIPT_PATH' zenoh" C-m

tmux send-keys -t "$EMPTY_PANE" \
    "bash '$SCRIPT_PATH' terminal" C-m

tmux send-keys -t "$T_2" \
    "bash '$SCRIPT_PATH' terminal" C-m

tmux send-keys -t "$T_3" \
    "bash '$SCRIPT_PATH' terminal" C-m


# Start with keyboard focus on Teleop.
tmux select-pane -t "$MAIN_PANE"

exec tmux attach-session -t "$SESSION_NAME"

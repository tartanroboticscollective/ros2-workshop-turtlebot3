#!/usr/bin/env bash

# tiny fix amd gpu PLEASE DONT REMOVE
if command -v xhost >/dev/null; then
    xhost +
fi


SESSION_NAME="ros2-workshop"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
WS_PATH="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"

export ROS_DOMAIN_ID=1
export TURTLEBOT3_MODEL=burger

## amd gazebo fix. PLEASE DONT REMOVE
export GZ_IP=127.0.0.1

# ================================================================
# Pixi helpers
# ================================================================

usage() {
    cat <<'EOF'
Usage: dev_session.sh [--stop]

  --stop    Stop the tmux session.
EOF
}

wait_for_zenoh() {
    echo "Waiting for the Zenoh router to be running..."

    # Wait for the router port (see zenoh/ROUTER_CONFIG.json5) to accept connections
    while ! (echo >/dev/tcp/127.0.0.1/7447) 2>/dev/null; do
        sleep 1
    done

    echo "Zenoh router is running."
}

run_in_pixi() {
    pixi run --manifest-path "$WS_PATH/pixi.toml" bash -c "$1"
}

open_pixi_shell() {
    pixi run --manifest-path "$WS_PATH/pixi.toml" bash --rcfile "$WS_PATH/pixi/bashrc" -i
}

start_zenoh() {
    if pgrep -x rmw_zenohd >/dev/null; then
        echo "Zenoh router is already running."
        return 0
    fi

    echo "Starting Zenoh router..."
    pixi run --manifest-path "$WS_PATH/pixi.toml" zenoh
}

stop_session() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "Stopping tmux session '$SESSION_NAME'..."
        tmux kill-session -t "$SESSION_NAME"
    fi
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
        wait_for_zenoh
        echo "Opening shell in the pixi environment..."
        open_pixi_shell
        exit $?
        ;;

    zenoh)
        start_zenoh
        exit $?
        ;;

    teleop)
        wait_for_zenoh
        echo "Starting TurtleBot3 Burger teleop..."
        run_in_pixi "ros2 run turtlebot3_teleop teleop_keyboard --ros-args -p use_sim_time:=true"
        exit $?
        ;;

    gazebo)
        wait_for_zenoh
        echo "Starting TurtleBot3 Burger Gazebo..."
        # gz sim survives the SIGHUP sent when the tmux session is killed,
        # so take down this pane's whole process group on exit
        trap 'kill -TERM -- -$$' EXIT
        run_in_pixi "ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py"
        exit $?
        ;;

    rviz)
        wait_for_zenoh
        echo "Starting RViz2..."
        run_in_pixi "ros2 run rviz2 rviz2 -d '$WS_PATH/config/default.rviz' --ros-args -p use_sim_time:=true"
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

# Install the pixi environment before starting any panes
pixi install --manifest-path "$WS_PATH/pixi.toml" || exit 1

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

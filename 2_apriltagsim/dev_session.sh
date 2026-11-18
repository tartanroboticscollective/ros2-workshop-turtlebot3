#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/../setup/common.sh"

SESSION_NAME="ros2-workshop"

export ROS_DOMAIN_ID=1
export TURTLEBOT3_MODEL=burger

# ================================================================
# Pixi helpers
# ================================================================

usage() {
    cat <<'EOF'
Usage: dev_session.sh [--stop]

  --stop    Stop the tmux session.
EOF
}

start_zenoh() {
    if pgrep -x rmw_zenohd >/dev/null; then
        echo "Zenoh router is already running."
        return 0
    fi

    echo "Starting Zenoh router..."
    pixi run zenoh
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
        pixi run workshop-shell
        exit $?
        ;;

    zenoh)
        start_zenoh
        exit $?
        ;;

    teleop)
        wait_for_zenoh
        echo "Starting TurtleBot3 Burger teleop..."
        pixi run teleop --ros-args -p use_sim_time:=true
        exit $?
        ;;

    gazebo)
        wait_for_zenoh
        echo "Starting TurtleBot3 Burger Gazebo..."
        run_gazebo
        exit $?
        ;;

    rviz)
        wait_for_zenoh
        echo "Starting RViz2..."
        pixi run rviz
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

new_session


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

start_pane "$MAIN_PANE" terminal
start_pane "$ZENOH_PANE" zenoh
start_pane "$EMPTY_PANE" terminal
start_pane "$T_2" terminal
start_pane "$T_3" terminal

# Start with keyboard focus on Teleop.
tmux select-pane -t "$MAIN_PANE"

exec tmux attach-session -t "$SESSION_NAME"

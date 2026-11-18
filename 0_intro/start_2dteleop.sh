#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/../setup/common.sh"

SESSION_NAME="ros2-workshop"

# ================================================================
# Commands run by individual panes
# ================================================================

case "${1:-}" in

    terminal)
        wait_for_zenoh
        clear
        echo "Opening shell in the pixi environment..."
        wait_and_set_top "TurtleSim"
        wait_and_set_top "rqt_graph"
        pixi run workshop-shell
        ;;

    zenoh)
        echo "Starting Zenoh router..."
        pixi run zenoh
        tmux kill-session -t "$SESSION_NAME"
        ;;

    teleop)
        wait_for_zenoh
        echo "Starting Turtle teleop..."
        pixi run turtlesim-teleop
        ;;

    turtlesim)
        wait_for_zenoh
        echo "Starting TurtleSim2D..."
        pixi run turtlesim
        ;;

    rqt_graph)
        wait_for_zenoh
        echo "Starting rqt_graph..."
        pixi run rqt-graph
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

new_session

# Main / Zenoh
ZENOH_PANE=$(tmux split-window \
    -v -t "$MAIN_PANE" -l '30%' -P -F '#{pane_id}')

# Main / Teleop
TELEOP_PANE=$(tmux split-window \
    -h -t "$MAIN_PANE" -l '33%' -P -F '#{pane_id}')

# Zenoh / rqt_graph / TurtleSim
RQT_PANE=$(tmux split-window \
    -h -t "$ZENOH_PANE" -l '66%' -P -F '#{pane_id}')

TURTLESIM_PANE=$(tmux split-window \
    -h -t "$RQT_PANE" -l '50%' -P -F '#{pane_id}')

# Prevent bash commands being sent before tmux panes are setup correctly
sleep 1

# ================================================================
# Start pane processes
# ================================================================

start_pane "$MAIN_PANE" terminal "Terminal - Type here"
start_pane "$TELEOP_PANE" teleop "Keyboard Teleoperate"
start_pane "$ZENOH_PANE" zenoh "Zenoh - Router (Ctrl+C here to kill everything)"
start_pane "$RQT_PANE" rqt_graph "rqt_graph"
start_pane "$TURTLESIM_PANE" turtlesim "2D Turtlesim"

# Start with keyboard focus on Teleop.
attach_session "$TELEOP_PANE"

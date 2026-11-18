#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/../setup/common.sh"

SESSION_NAME="ros2-join"

TURTLE_NAME="turtle_$((1 + $RANDOM % 100000))"
RANDOM_X=$((1 + $RANDOM % 10))
RANDOM_Y=$((1 + $RANDOM % 10))
RANDOM_T=$(bc <<<"scale=2; $((1 + $RANDOM % 314)) / 100")

# ================================================================
# Commands run by individual panes
# ================================================================

case "${1:-}" in

    terminal)
        wait_for_zenoh
        clear
        echo "Opening shell in the pixi environment..."
        wait_and_set_top "rqt_graph"
        pixi run workshop-shell
        ;;

    zenoh)
        echo "Starting Zenoh router..."
        ZENOH_CONFIG_OVERRIDE='mode="router";connect/endpoints=["tcp/192.168.1.3:7447"]' \
            pixi run zenoh
        tmux kill-session -t "$SESSION_NAME"
        ;;

    teleop)
        wait_for_zenoh
        echo "Starting Turtle teleop..."
        echo $2
        pixi run turtlesim-teleop --ros-args --remap "__node:=$2" --remap "turtle1/cmd_vel:=$2/cmd_vel"
        ;;

    turtle_spawn)
        wait_for_zenoh
        echo "Spawning new turtle..."
        pixi run ros2 service call /spawn turtlesim/srv/Spawn "{x: $RANDOM_X, y: $RANDOM_Y, theta: $RANDOM_T, name: '$2'}"
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
# RQT_PANE=$(tmux split-window \
    #     -h -t "$ZENOH_PANE" -l '66%' -P -F '#{pane_id}')

TURTLE_SPAWN_PANE=$(tmux split-window \
    -h -t "$ZENOH_PANE" -l '50%' -P -F '#{pane_id}')

# Prevent bash commands being sent before tmux panes are setup correctly
sleep 1

# ================================================================
# Start pane processes
# ================================================================

start_pane "$MAIN_PANE" terminal "Terminal - Type here"
start_pane "$TELEOP_PANE" "teleop $TURTLE_NAME" "Keyboard Teleoperate"
start_pane "$ZENOH_PANE" zenoh "Zenoh - Router (Ctrl+C here to kill everything)"
# start_pane "$RQT_PANE" rqt_graph "rqt_graph"
start_pane "$TURTLE_SPAWN_PANE" "turtle_spawn $TURTLE_NAME" "2D Turtlesim spawn service"

# Start with keyboard focus on Teleop.
attach_session "$TELEOP_PANE"

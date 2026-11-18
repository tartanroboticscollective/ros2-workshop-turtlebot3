#!/usr/bin/env bash
# ----------------------------------------------------------------
# Run Simulation - 3D Navigation session
# ----------------------------------------------------------------

source "$(dirname "${BASH_SOURCE[0]}")/../setup/common.sh"

TURTLEBOT3_MODEL=waffle_pi
parse_model_option "$@"; shift $?

# Read by the TurtleBot3 launch files in every pane
export TURTLEBOT3_MODEL

SESSION_NAME="ros2-workshop"

# ================================================================
# Commands run by individual panes
# ================================================================

case "${1:-}" in

    terminal)
        wait_for_zenoh
        clear
        echo "Opening shell in the pixi environment..."
        wait_and_set_top "Gazebo"
        wait_and_set_top "RViz"
        pixi run workshop-shell
        ;;

    zenoh)
        echo "Starting Zenoh router..."
        pixi run zenoh
        tmux kill-session -t "$SESSION_NAME"
        ;;

    navigation)
        wait_for_zenoh
        echo "Starting TurtleBot3 navigation..."
        pixi run navigation
        ;;

    gazebo)
        wait_for_zenoh
        echo "Starting TurtleBot3 Gazebo..."
        run_gazebo
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
# │          Main terminal           │      Teleop     │
# │                                  │                 │
# ├──────────────────┬───────────────┼─────────────────┤
# │      Zenoh       │  Navigation   │     Gazebo      │
# └──────────────────┴───────────────┴─────────────────┘
# ================================================================

new_session

# Main / Zenoh
ZENOH_PANE=$(tmux split-window \
    -v -t "$MAIN_PANE" -l '30%' -P -F '#{pane_id}')

# Main / Teleop
TELEOP_PANE=$(tmux split-window \
    -h -t "$MAIN_PANE" -l '33%' -P -F '#{pane_id}')

# Zenoh / Navigation / Gazebo
NAVIGATION_PANE=$(tmux split-window \
    -h -t "$ZENOH_PANE" -l '66%' -P -F '#{pane_id}')

GAZEBO_PANE=$(tmux split-window \
    -h -t "$NAVIGATION_PANE" -l '50%' -P -F '#{pane_id}')

# Prevent bash commands being sent before tmux panes are setup correctly
sleep 1

# ================================================================
# Start pane processes
# ================================================================

ARGS="-m $TURTLEBOT3_MODEL"
start_pane "$MAIN_PANE" "$ARGS terminal" "Terminal - Save the map here!"
start_pane "$TELEOP_PANE" "$ARGS terminal" "Keyboard Teleoperate"
tmux send-keys -t "$TELEOP_PANE" \
    "echo 'WARNING: Running teleoperation while Navigation is running sends conflicting commands to the turtlebot!'" C-m \
    "pixi run teleop --ros-args -p use_sim_time:=true"
start_pane "$ZENOH_PANE" "$ARGS zenoh" "Zenoh - Router (Ctrl+C here to kill everything)"
start_pane "$NAVIGATION_PANE" "$ARGS navigation" "Navigation - Controls the Turtlebot"
start_pane "$GAZEBO_PANE" "$ARGS gazebo" "Gazebo - 3D Simulator"

# Start with keyboard focus on Navigation.
attach_session "$NAVIGATION_PANE"

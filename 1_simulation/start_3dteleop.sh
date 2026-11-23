#!/usr/bin/env bash
# ----------------------------------------------------------------
# Run Simulation - 3D Teleop session
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

    teleop)
        wait_for_zenoh
        echo "Starting TurtleBot3 teleop..."
        pixi run teleop --ros-args -p use_sim_time:=true
        ;;

    gazebo)
        wait_for_zenoh
        echo "Starting TurtleBot3 Gazebo..."
        run_gazebo
        ;;

    rviz)
        wait_for_zenoh
        echo "Starting RViz2..."
        pixi run rviz
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

new_session

# Main / Zenoh
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

# Prevent bash commands being sent before tmux panes are setup correctly
sleep 1

# ================================================================
# Start pane processes
# ================================================================

ARGS="-m $TURTLEBOT3_MODEL"
start_pane "$MAIN_PANE" "$ARGS terminal" "Terminal - Save the map here!"
start_pane "$TELEOP_PANE" "$ARGS teleop" "Keyboard Teleoperate"
start_pane "$ZENOH_PANE" "$ARGS zenoh" "Zenoh - Router (Ctrl+C here to kill everything)"
start_pane "$RVIZ_PANE" "$ARGS rviz" "RViz - ROS Data Visualiser"
start_pane "$GAZEBO_PANE" "$ARGS gazebo" "Gazebo - 3D Simulator"

# Start with keyboard focus on Teleop.
attach_session "$TELEOP_PANE"

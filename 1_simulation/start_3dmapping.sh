#!/usr/bin/env bash
# ----------------------------------------------------------------
# Run Simulation - 3D Mapping session
# ----------------------------------------------------------------

source "$(dirname "${BASH_SOURCE[0]}")/../setup/common.sh"

TURTLEBOT3_MODEL=waffle_pi
parse_model_option "$@"; shift $?

# Read by the TurtleBot3 launch files in every pane
export TURTLEBOT3_MODEL

SESSION_NAME="ros2-workshop"

# Command pre-typed (but not executed) in the main terminal pane
MAP_SAVE_CMD="pixi run map-save"

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

        # Pre-type the map-saving command once the pixi shell is up.
        # -l sends the text literally; no Enter (C-m) is sent, so the user
        # presses Enter when ready.
        if [[ -n "${TMUX_PANE:-}" ]]; then
            ( sleep 2; tmux send-keys -t "$TMUX_PANE" -l "$MAP_SAVE_CMD" ) &
        fi

        pixi run workshop-shell
        exit 0
        ;;

    zenoh)
        echo "Starting Zenoh router..."
        pixi run zenoh
        tmux kill-session -t "$SESSION_NAME"
        exit 0
        ;;

    teleop)
        wait_for_zenoh
        echo "Starting TurtleBot3 teleop..."
        pixi run teleop
        exit 0
        ;;

    gazebo)
        wait_for_zenoh
        echo "Starting TurtleBot3 Gazebo..."
        run_gazebo
        exit 0
        ;;

    cartographer)
        wait_for_zenoh
        echo "Starting Cartographer..."
        pixi run cartographer
        exit 0
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

new_session

# Main / Zenoh
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

# Prevent bash commands being sent before tmux panes are setup correctly
sleep 1

# ================================================================
# Start pane processes
# ================================================================

ARGS="-m $TURTLEBOT3_MODEL"
start_pane "$MAIN_PANE" "$ARGS terminal" "Terminal - Save the map here!"
start_pane "$TELEOP_PANE" "$ARGS teleop" "Keyboard Teleoperate"
start_pane "$ZENOH_PANE" "$ARGS zenoh" "Zenoh - Router (Ctrl+C here to kill everything)"
start_pane "$CARTOGRAPHER_PANE" "$ARGS cartographer" "Cartographer - Creates the map"
start_pane "$GAZEBO_PANE" "$ARGS gazebo" "Gazebo - 3D Simulator"

# Start with keyboard focus on Teleop.
attach_session "$TELEOP_PANE"

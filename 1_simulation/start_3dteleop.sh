#!/usr/bin/env bash
# ----------------------------------------------------------------
# Run Simulation - 3D Teleop session
# ----------------------------------------------------------------

TURTLEBOT3_MODEL=waffle_pi

# Function to print usage
usage() {
    echo "
Usage: start_3dteleop.sh [-m|--model] turtlebot3_model [-h|--help]

Where:
    -m | --model    Set turtlebot3 model (e.g. "burger_cam" or "waffle_pi")
    -h | --help     Show this help message
    "
    exit 1
}

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -m|--model)
            if [[ -n "$2" && "$2" != -* ]]; then
                TURTLEBOT3_MODEL="$2"
                shift
                shift
            else
                echo "Error: Missing turtlebot3 model name after $1"
                usage
            fi
            ;;
        -h|--help)
            usage
            ;;
    esac
    break
done

# Read by the TurtleBot3 launch files in every pane
export TURTLEBOT3_MODEL

SESSION_NAME="ros2-workshop"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
WS_PATH="${SCRIPT_PATH%/*/*}"

# ================================================================
# Pixi helpers
# ================================================================

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

# Keep GUI windows on top: wmctrl on Linux (X11), System Events on macOS
wait_and_set_top() {
    local title="$1"
    [[ -n "${SKIP_SET_TOP:-}" ]] && return 0
    if [[ "$(uname)" == "Darwin" ]]; then
        local result
        while true; do
            result=$(osascript "$WS_PATH/setup/raise_window.applescript" "$title" 2>&1)
            case "$result" in
                raised) return 0 ;;
                *"assistive access"*)
                    echo "To bring GUI windows to the front, allow your terminal app in"
                    echo "System Settings > Privacy & Security > Accessibility."
                    SKIP_SET_TOP=1
                    return 0
                    ;;
            esac
            sleep 1
        done
    fi
    command -v wmctrl >/dev/null || return 0
    while ! wmctrl -l | grep -q "$title"; do
        sleep 1
    done
    wmctrl -r "$title" -b add,above
}

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
        open_pixi_shell
        ;;

    zenoh)
        echo "Starting Zenoh router..."
        pixi run --manifest-path "$WS_PATH/pixi.toml" zenoh
        tmux kill-session -t "$SESSION_NAME"
        ;;

    teleop)
        wait_for_zenoh
        echo "Starting TurtleBot3 teleop..."
        run_in_pixi "ros2 run turtlebot3_teleop teleop_keyboard --ros-args -p use_sim_time:=true"
        ;;

    gazebo)
        wait_for_zenoh
        echo "Starting TurtleBot3 Gazebo..."
        # gz sim survives the SIGHUP sent when the tmux session is killed,
        # so take down this pane's whole process group on exit
        trap 'kill -TERM -- -$$' EXIT
        run_in_pixi "ros2 launch turtlebot3_gazebo turtlebot3_world.launch.py"
        ;;

    rviz)
        wait_for_zenoh
        echo "Starting RViz2..."
        run_in_pixi "ros2 run rviz2 rviz2 -d '$WS_PATH/config/default.rviz' --ros-args -p use_sim_time:=true"
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

# Install the pixi environment before starting any panes
pixi install --manifest-path "$WS_PATH/pixi.toml" || exit 1

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

# Prevent bash commands being sent before tmux panes are setup correctly
sleep 1

# ================================================================
# Start pane processes
# ================================================================

tmux send-keys -t "$MAIN_PANE" \
    "bash '$SCRIPT_PATH' -m $TURTLEBOT3_MODEL terminal" C-m

tmux send-keys -t "$TELEOP_PANE" \
    "bash '$SCRIPT_PATH' -m $TURTLEBOT3_MODEL teleop" C-m

tmux send-keys -t "$ZENOH_PANE" \
    "bash '$SCRIPT_PATH' -m $TURTLEBOT3_MODEL zenoh" C-m

tmux send-keys -t "$RVIZ_PANE" \
    "bash '$SCRIPT_PATH' -m $TURTLEBOT3_MODEL rviz" C-m

tmux send-keys -t "$GAZEBO_PANE" \
    "bash '$SCRIPT_PATH' -m $TURTLEBOT3_MODEL gazebo" C-m

# =============================================================================
# Display pane titles in pane borders
# =============================================================================

tmux select-pane -t "$MAIN_PANE"  -T "Terminal - Save the map here!"
tmux select-pane -t "$ZENOH_PANE"  -T "Zenoh - Router (Ctrl+C here to kill everything)"
tmux select-pane -t "$TELEOP_PANE"  -T "Keyboard Teleoperate"
tmux select-pane -t "$RVIZ_PANE"  -T "RViz - ROS Data Visualiser"
tmux select-pane -t "$GAZEBO_PANE"  -T "Gazebo - 3D Simulator"

tmux set-option -t "$SESSION_NAME" pane-border-status top

tmux set-option -t "$SESSION_NAME" pane-border-format \
    " #{pane_title} "

# Start with keyboard focus on Teleop.
tmux select-pane -t "$TELEOP_PANE"

exec tmux attach-session -t "$SESSION_NAME"

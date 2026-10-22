#!/usr/bin/env bash
# ----------------------------------------------------------------
# Run Simulation - Real Teleop session
# ----------------------------------------------------------------

TURTLEBOT3_MODEL=waffle_pi
TURTLEBOT3_IP=""

# Function to print usage
usage() {
    cat <<EOF
Usage: start_realteleop.sh -ip <ip> [-m|--model <model>] [-h|--help]

Options:
    -m, --model <model>    Set the TurtleBot3 model:
                           burger_cam or waffle_pi

    -ip <ip>               IP address of the remote Zenoh router.
                           Required.

    -h, --help             Show this help message.

Examples:
    start_realteleop.sh -ip 192.168.0.1
    start_realteleop.sh -ip 192.168.0.1 -m burger_cam
    start_realteleop.sh --model waffle_pi -ip 192.168.0.1
EOF
    exit 1
}

# Parse command-line options
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -m|--model)
            if [[ -n "$2" && "$2" != -* ]]; then
                case "$2" in
                    burger_cam|waffle_pi)
                        TURTLEBOT3_MODEL="$2"
                        shift 2
                        ;;
                    *)
                        echo "Error: Invalid turtlebot3 model '$2'"
                        usage
                        ;;
                esac
            else
                echo "Error: Missing turtlebot3 model name after $1"
                usage
            fi
            ;;

        -ip)
            if [[ -n "$2" && "$2" != -* ]]; then
                TURTLEBOT3_IP="$2"
                shift 2
            else
                echo "Error: Missing IP address after $1"
                usage
            fi
            ;;

        -h|--help)
            usage
            ;;

        *)
            break
            ;;
    esac
done

if [ -z "${TURTLEBOT3_IP}" ]; then
    echo "Error: Missing turtlebot3 ip, please use -ip followed by the Turtlebot's ip"
    usage
fi

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
        wait_and_set_top "RViz"
        wait_and_set_top "rqt_graph"
        open_pixi_shell
        ;;

    zenoh)
        echo "Starting Zenoh router..."
        ZENOH_CONFIG_OVERRIDE='mode="router";connect/endpoints=["tcp/'"$TURTLEBOT3_IP"':7447"]' \
            pixi run --manifest-path "$WS_PATH/pixi.toml" zenoh
        tmux kill-session -t "$SESSION_NAME"
        ;;

    teleop)
        wait_for_zenoh
        echo "Starting TurtleBot3 teleop..."
        run_in_pixi "ros2 run turtlebot3_teleop teleop_keyboard --ros-args"
        ;;

    rviz)
        wait_for_zenoh
        echo "Starting RViz2..."
        run_in_pixi "ros2 run rviz2 rviz2 -d '$WS_PATH/config/default.rviz' --ros-args -p use_sim_time:=true"
        ;;

    rqt_graph)
        wait_for_zenoh
        echo "Starting rqt_graph..."
        run_in_pixi "rqt_graph"
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
# │      Zenoh       │     RViz2     │    rqt_graph    │
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

# Zenoh / RViz2 / rqt_graph
RVIZ_PANE=$(tmux split-window \
    -h -t "$ZENOH_PANE" -l '66%' -P -F '#{pane_id}')

RQT_GRAPH=$(tmux split-window \
    -h -t "$RVIZ_PANE" -l '50%' -P -F '#{pane_id}')

# Prevent bash commands being sent before tmux panes are setup correctly
sleep 1

# ================================================================
# Start pane processes
# ================================================================

tmux send-keys -t "$MAIN_PANE" \
    "bash '$SCRIPT_PATH' -ip $TURTLEBOT3_IP -m $TURTLEBOT3_MODEL terminal" C-m

tmux send-keys -t "$TELEOP_PANE" \
    "bash '$SCRIPT_PATH' -ip $TURTLEBOT3_IP -m $TURTLEBOT3_MODEL teleop" C-m

tmux send-keys -t "$ZENOH_PANE" \
    "bash '$SCRIPT_PATH' -ip $TURTLEBOT3_IP -m $TURTLEBOT3_MODEL zenoh" C-m

tmux send-keys -t "$RVIZ_PANE" \
    "bash '$SCRIPT_PATH' -ip $TURTLEBOT3_IP -m $TURTLEBOT3_MODEL rviz" C-m

tmux send-keys -t "$RQT_GRAPH" \
    "bash '$SCRIPT_PATH' -ip $TURTLEBOT3_IP -m $TURTLEBOT3_MODEL rqt_graph" C-m

# =============================================================================
# Display pane titles in pane borders
# =============================================================================

tmux select-pane -t "$MAIN_PANE"  -T "Terminal - Type here"
tmux select-pane -t "$ZENOH_PANE"  -T "Zenoh - Router (Ctrl+C here to kill everything)"
tmux select-pane -t "$TELEOP_PANE"  -T "Keyboard Teleoperate"
tmux select-pane -t "$RVIZ_PANE"  -T "RViz - ROS Data Visualiser"
tmux select-pane -t "$RQT_GRAPH"  -T "rqt_graph"

tmux set-option -t "$SESSION_NAME" pane-border-status top

tmux set-option -t "$SESSION_NAME" pane-border-format \
    " #{pane_title} "

# Start with keyboard focus on Teleop.
tmux select-pane -t "$TELEOP_PANE"

exec tmux attach-session -t "$SESSION_NAME"

#!/usr/bin/env bash
# ----------------------------------------------------------------
# Run Simulation - Real Teleop session
# ----------------------------------------------------------------

source "$(dirname "${BASH_SOURCE[0]}")/../setup/common.sh"

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
        pixi run workshop-shell
        ;;

    zenoh)
        echo "Starting Zenoh router..."
        ZENOH_CONFIG_OVERRIDE='mode="router";connect/endpoints=["tcp/'"$TURTLEBOT3_IP"':7447"]' \
            pixi run zenoh
        tmux kill-session -t "$SESSION_NAME"
        ;;

    teleop)
        wait_for_zenoh
        echo "Starting TurtleBot3 teleop..."
        pixi run teleop
        ;;

    rviz)
        wait_for_zenoh
        echo "Starting RViz2..."
        pixi run rviz
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
# │      Zenoh       │     RViz2     │    rqt_graph    │
# └──────────────────┴───────────────┴─────────────────┘
# ================================================================

new_session

# Main / Zenoh
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

ARGS="-ip $TURTLEBOT3_IP -m $TURTLEBOT3_MODEL"
start_pane "$MAIN_PANE" "$ARGS terminal" "Terminal - Type here"
start_pane "$TELEOP_PANE" "$ARGS teleop" "Keyboard Teleoperate"
start_pane "$ZENOH_PANE" "$ARGS zenoh" "Zenoh - Router (Ctrl+C here to kill everything)"
start_pane "$RVIZ_PANE" "$ARGS rviz" "RViz - ROS Data Visualiser"
start_pane "$RQT_GRAPH" "$ARGS rqt_graph" "rqt_graph"

# Start with keyboard focus on Teleop.
attach_session "$TELEOP_PANE"

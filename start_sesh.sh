#!/usr/bin/env bash
# ================================================================
# ROS 2 Turtlebot 3 workshop launcher.
#
#   ./start_sesh.sh              Pull the prebuilt image and launch
#   ./start_sesh.sh --build      Use the locally built image
#   ./start_sesh.sh --vnc        Use Gazebo and RViz2 instead of Foxglove
#   ./start_sesh.sh --x11        Render GUIs on the host's X server
#   ./start_sesh.sh --stop       Tear everything down
#
# Opens a tmux session running Zenoh, Gazebo, teleop and a viewer.
# By default the robot is visualised in Foxglove at http://localhost:8080
# ================================================================

SESSION_NAME="ros2-workshop"
CONTAINER_NAME="ros2-workshop-turtlebot3"
VIEWER_NAME="ros2-workshop-foxglove"

REMOTE_IMAGE="ghcr.io/tartanroboticscollective/ros2-workshop-turtlebot3:latest"
LOCAL_IMAGE="ros2-workshop-turtlebot3:local"
VIEWER_IMAGE="ghcr.io/lichtblick-suite/lichtblick:latest"

NOVNC_PORT="${NOVNC_PORT:-6080}"
VNC_PORT="${VNC_PORT:-5901}"
ZENOH_PORT="${ZENOH_PORT:-7447}"
BRIDGE_PORT="${BRIDGE_PORT:-8765}"
VIEWER_PORT="${VIEWER_PORT:-8080}"
TURTLEBOT3_MODEL="${TURTLEBOT3_MODEL:-burger}"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${REPO_DIR}/$(basename "${BASH_SOURCE[0]}")"

ZENOH_CMD="ros2 run rmw_zenoh_cpp rmw_zenohd"
BRIDGE_CMD="ros2 launch foxglove_bridge foxglove_bridge_launch.xml"


# ================================================================
# Options
# ================================================================

usage() {
    echo "
Usage: start_sesh.sh [--build] [--vnc] [--x11] [--model NAME]
                     [--stop] [--help]

Where:
    --build         Use the image built by './dev.sh' instead of the
                    prebuilt one from the registry
    --vnc           Use Gazebo and RViz2 at http://localhost:${NOVNC_PORT}
                    instead of Foxglove
    --x11           Render GUIs on the host's X server instead of in
                    the browser. Linux only
    --model NAME    Turtlebot 3 model: burger (default), waffle, waffle_pi
    --stop          Stop the container and kill the tmux session
    --help          Show this help message
    "
    exit "${1:-1}"
}

BUILD_LOCALLY=0
GUI_MODE="foxglove"
PANE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --build)
            BUILD_LOCALLY=1
            ;;
        --foxglove)
            GUI_MODE="foxglove"
            ;;
        --vnc)
            GUI_MODE="vnc"
            ;;
        --x11)
            GUI_MODE="x11"
            ;;
        --model)
            [[ -n "${2:-}" ]] || { echo "--model needs a value"; usage; }
            TURTLEBOT3_MODEL="$2"
            shift
            ;;
        --stop)
            echo "Stopping container and tmux session..."
            docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1
            docker rm -f "$VIEWER_NAME" >/dev/null 2>&1
            tmux kill-session -t "$SESSION_NAME" >/dev/null 2>&1
            echo "Done."
            exit 0
            ;;
        --pane)
            [[ -n "${2:-}" ]] || usage
            PANE="$2"
            shift
            ;;
        -h|--help)
            usage 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
    shift
done

if [[ "$BUILD_LOCALLY" -eq 1 ]]; then
    IMAGE="$LOCAL_IMAGE"
else
    IMAGE="$REMOTE_IMAGE"
fi

PANE_ARGS=(--model "$TURTLEBOT3_MODEL")
[[ "$BUILD_LOCALLY" -eq 1 ]] && PANE_ARGS+=(--build)
[[ "$GUI_MODE" == "x11" ]] && PANE_ARGS+=(--x11)
[[ "$GUI_MODE" == "vnc" ]] && PANE_ARGS+=(--vnc)

GUI_URL="http://localhost:${NOVNC_PORT}/vnc.html?autoconnect=1&resize=scale"

# layoutUrl loads the workshop layout even when the browser has one saved.
# The config directory is mounted whole so edits to the layout are picked
# up without recreating the viewer.
LAYOUT_URL="http://localhost:${VIEWER_PORT}/config/foxglove-layout.json"
VIEWER_URL="http://localhost:${VIEWER_PORT}/?layoutUrl=${LAYOUT_URL}&ds=foxglove-websocket&ds.url=ws://localhost:${BRIDGE_PORT}"


# ================================================================
# Docker helpers
# ================================================================

ensure_image() {
    if [[ "$BUILD_LOCALLY" -eq 1 ]]; then
        LAUNCHING_SESSION=1 "$REPO_DIR/dev.sh" || exit 1
    elif ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
        echo "Pulling $IMAGE..."
        docker pull "$IMAGE" || {
            echo "Pull failed. Build the image instead with './dev.sh'."
            exit 1
        }
    fi
}

check_image() {
    [[ "$GUI_MODE" != "vnc" ]] && return 0

    if ! docker run --rm --entrypoint test "$IMAGE" \
        -x /usr/local/bin/start-gui >/dev/null 2>&1; then
        echo "
$IMAGE does not include the browser GUI.

Build a current image and launch it with:

    ./dev.sh
    ./start_sesh.sh --build
"
        exit 1
    fi
}

ensure_sources() {
    [[ -d "$REPO_DIR/src/turtlebot3" ]] && return 0

    echo "Importing workspace sources..."
    docker run --rm \
        -v "$REPO_DIR/src":/ws/src \
        -w /ws \
        "$IMAGE" \
        vcs import --input src/.repos src
}

network_args() {
    if [[ "$(uname -s)" == "Linux" ]]; then
        echo "--net host"
    else
        echo "-p ${NOVNC_PORT}:6080 -p ${VNC_PORT}:5901 -p ${ZENOH_PORT}:7447" \
            "-p ${BRIDGE_PORT}:8765"
    fi
}

# Foxglove viewer, served from its own container
ensure_viewer() {
    [[ "$GUI_MODE" == "foxglove" ]] || return 0

    docker rm -f "$VIEWER_NAME" >/dev/null 2>&1

    if ! docker image inspect "$VIEWER_IMAGE" >/dev/null 2>&1; then
        echo "Pulling $VIEWER_IMAGE..."
        docker pull "$VIEWER_IMAGE" || exit 1
    fi

    echo "Starting Foxglove viewer..."
    docker run -d --rm \
        --name "$VIEWER_NAME" \
        -p "${VIEWER_PORT}:8080" \
        -v "$REPO_DIR/config/foxglove-layout.json":/lichtblick/default-layout.json:ro \
        -v "$REPO_DIR/config":/src/config:ro \
        "$VIEWER_IMAGE" >/dev/null || exit 1
}

run_container() {
    local -a args=(
        -it --rm
        --name "$CONTAINER_NAME"
        -e TURTLEBOT3_MODEL="$TURTLEBOT3_MODEL"
        -v /etc/localtime:/etc/localtime:ro
        -v "$REPO_DIR/config":/turtlebot_ws/config
        -v "$REPO_DIR/src":/turtlebot_ws/src
    )
    local start_cmd="$ZENOH_CMD"

    # shellcheck disable=SC2207
    args+=($(network_args))

    if [[ "$GUI_MODE" == "x11" ]]; then
        if [[ "$(uname -s)" != "Linux" ]]; then
            echo "WARNING: --x11 requires Linux. Drop it to use the browser GUI."
        fi
        command -v xhost >/dev/null 2>&1 && xhost +local:root >/dev/null
        args+=(
            --privileged
            -e DISPLAY="$DISPLAY"
            -v /tmp/.X11-unix:/tmp/.X11-unix
            -v /dev:/dev
        )
    elif [[ "$GUI_MODE" == "vnc" ]]; then
        args+=(-e LIBGL_ALWAYS_SOFTWARE=1)
        start_cmd="start-gui; $start_cmd"
    fi

    docker run "${args[@]}" "$IMAGE" bash -ic "$start_cmd"
}

wait_for_container() {
    echo "Waiting for container '$CONTAINER_NAME' to be running..."

    while true; do
        if docker ps \
            --filter "name=^${CONTAINER_NAME}$" \
            --filter "status=running" \
            --format '{{.Names}}' |
        grep -qx "$CONTAINER_NAME"
        then
            echo "Container '$CONTAINER_NAME' is running."
            return 0
        fi

        sleep 1
    done
}

# GUI apps must not start before their X server accepts connections,
# and the viewer must not open before the bridge is listening.
wait_for_gui() {
    if [[ "$GUI_MODE" == "vnc" ]]; then
        echo "Waiting for the GUI server..."
        until docker exec "$CONTAINER_NAME" \
            test -e /tmp/.X11-unix/X1 >/dev/null 2>&1; do
            sleep 1
        done
    fi
}

wait_for_bridge() {
    [[ "$GUI_MODE" == "foxglove" ]] || return 0

    echo "Waiting for the Foxglove bridge..."
    until docker exec "$CONTAINER_NAME" \
        bash -c "exec 3<>/dev/tcp/127.0.0.1/8765" >/dev/null 2>&1; do
        sleep 1
    done
}

open_url() {
    if command -v open >/dev/null 2>&1; then
        open "$1" >/dev/null 2>&1 &
    elif command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$1" >/dev/null 2>&1 &
    fi
}

open_gui() {
    case "$GUI_MODE" in
        foxglove)
            echo "Foxglove: $VIEWER_URL"
            open_url "$VIEWER_URL"
            ;;
        vnc)
            echo "Gazebo and RViz2: $GUI_URL"
            open_url "$GUI_URL"
            ;;
    esac
}

exec_in_container() {
    docker exec -it "$CONTAINER_NAME" bash -ic "$1"
}


# ================================================================
# Commands run by individual panes
# ================================================================

case "$PANE" in

    terminal)
        wait_for_container
        wait_for_gui
        wait_for_bridge
        open_gui
        echo "Opening shell in $CONTAINER_NAME..."
        exec docker exec -it "$CONTAINER_NAME" /bin/bash
        ;;

    zenoh)
        echo "Starting container and Zenoh router..."
        run_container
        ;;

    teleop)
        wait_for_container
        echo "Starting TurtleBot3 teleop..."
        exec_in_container "ros2 run turtlebot3_teleop teleop_keyboard"
        ;;

    gazebo)
        wait_for_container
        wait_for_gui
        if [[ "$GUI_MODE" == "foxglove" ]]; then
            echo "Starting TurtleBot3 Gazebo (no window)..."
            exec_in_container \
                "ros2 launch /turtlebot_ws/config/turtlebot3_world.launch.py gui:=false"
        else
            echo "Starting TurtleBot3 Gazebo..."
            exec_in_container \
                "ros2 launch /turtlebot_ws/config/turtlebot3_world.launch.py"
        fi
        ;;

    rviz)
        wait_for_container
        wait_for_gui
        if [[ "$GUI_MODE" == "foxglove" ]]; then
            echo "Starting Foxglove bridge..."
            exec_in_container "$BRIDGE_CMD"
        else
            echo "Starting RViz2..."
            exec_in_container "rviz2"
        fi
        ;;

    "")
        # Main launcher, continues below.
        ;;

    *)
        echo "Unknown pane: $PANE"
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
# │      Zenoh       │  RViz2 or     │     Gazebo      │
# │                  │  Foxglove     │                 │
# └──────────────────┴───────────────┴─────────────────┘
# ================================================================

if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux is not installed. Install it with:"
    echo "  macOS:  brew install tmux"
    echo "  Ubuntu: sudo apt install tmux"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Start Docker Desktop (or the docker service)."
    exit 1
fi

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    exec tmux attach-session -t "$SESSION_NAME"
fi

ensure_image
check_image
ensure_sources
ensure_viewer

tmux new-session -d -s "$SESSION_NAME"

# Main / Zenoh
MAIN_PANE=$(tmux display-message -p -t "$SESSION_NAME:0.0" '#{pane_id}')

ZENOH_PANE=$(tmux split-window \
    -v -t "$MAIN_PANE" -p 30 -P -F '#{pane_id}')

# Main / Teleop
TELEOP_PANE=$(tmux split-window \
    -h -t "$MAIN_PANE" -p 33 -P -F '#{pane_id}')

# Zenoh / RViz2 / Gazebo
RVIZ_PANE=$(tmux split-window \
    -h -t "$ZENOH_PANE" -p 66 -P -F '#{pane_id}')

GAZEBO_PANE=$(tmux split-window \
    -h -t "$RVIZ_PANE" -p 50 -P -F '#{pane_id}')


# ================================================================
# Start pane processes
# ================================================================

launch_pane() {
    tmux send-keys -t "$1" \
        "bash '$SCRIPT_PATH' ${PANE_ARGS[*]} --pane $2" C-m
}

launch_pane "$MAIN_PANE" terminal
launch_pane "$TELEOP_PANE" teleop
launch_pane "$ZENOH_PANE" zenoh
launch_pane "$RVIZ_PANE" rviz
launch_pane "$GAZEBO_PANE" gazebo

# Start with keyboard focus on Teleop.
tmux select-pane -t "$TELEOP_PANE"

exec tmux attach-session -t "$SESSION_NAME"

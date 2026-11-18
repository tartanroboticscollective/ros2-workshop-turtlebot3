# Shared helpers for the tmux start scripts. Source it first thing:
#   source "$(dirname "${BASH_SOURCE[0]}")/../setup/common.sh"
# Runs with the system bash (3.2 on macOS): no bash-4-only features.

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)/$(basename "${BASH_SOURCE[1]}")"
WS_PATH="${SCRIPT_PATH%/*/*}"

# pixi finds pixi.toml from the workspace root
cd "$WS_PATH" || exit 1

usage() {
    echo "
Usage: $(basename "$SCRIPT_PATH") [-m|--model] turtlebot3_model [-h|--help]

Where:
    -m | --model    Set turtlebot3 model (e.g. \"burger_cam\" or \"waffle_pi\")
    -h | --help     Show this help message
    "
    exit 1
}

# Parse a leading "-m|--model <model>" or "-h|--help" into TURTLEBOT3_MODEL.
# Returns the number of arguments consumed: parse_model_option "$@"; shift $?
parse_model_option() {
    case "${1:-}" in
        -m|--model)
            if [[ -n "${2:-}" && "$2" != -* ]]; then
                TURTLEBOT3_MODEL="$2"
                return 2
            fi
            echo "Error: Missing turtlebot3 model name after $1"
            usage
            ;;
        -h|--help)
            usage
            ;;
    esac
    return 0
}

wait_for_zenoh() {
    echo "Waiting for the Zenoh router to be running..."

    # Wait for the router port (see zenoh/ROUTER_CONFIG.json5) to accept connections
    while ! (echo >/dev/tcp/127.0.0.1/7447) 2>/dev/null; do
        sleep 1
    done

    echo "Zenoh router is running."
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

run_gazebo() {
    # gz sim survives the SIGHUP sent when the tmux session is killed,
    # so take down this pane's whole process group on exit
    trap 'kill -TERM -- -$$' EXIT
    pixi run gazebo
}

# Attach to $SESSION_NAME if it already exists. Otherwise install the pixi
# environment, create the session detached and set MAIN_PANE to its first pane.
new_session() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        exec tmux attach-session -t "$SESSION_NAME"
    fi

    # Install the pixi environment from pixi.lock before starting any panes
    pixi install --locked || exit 1

    tmux new-session -d -s "$SESSION_NAME"
    MAIN_PANE=$(tmux display-message -p -t "$SESSION_NAME:0.0" '#{pane_id}')
}

# start_pane <pane> "<args to this script>" [title]
start_pane() {
    [[ -n "${3:-}" ]] && tmux select-pane -t "$1" -T "$3"
    tmux send-keys -t "$1" "bash '$SCRIPT_PATH' $2" C-m
}

# Show pane titles in the borders, focus <pane> and attach
attach_session() {
    tmux set-option -t "$SESSION_NAME" pane-border-status top
    tmux set-option -t "$SESSION_NAME" pane-border-format " #{pane_title} "
    tmux select-pane -t "$1"
    exec tmux attach-session -t "$SESSION_NAME"
}

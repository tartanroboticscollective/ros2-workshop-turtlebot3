#!/usr/bin/env bash
# ----------------------------------------------------------------
# Build the workshop image from this repository.
# ----------------------------------------------------------------

IMAGE="ros2-workshop-turtlebot3:local"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "
Usage: dev.sh [-h|--help]

Builds the workshop image and tags it $IMAGE.
Launch it with './start_sesh.sh --build'.

Where:
    -h | --help     Show this help message
    "
    exit "${1:-1}"
}

while [[ "$#" -gt 0 ]]; do
    case $1 in
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

echo "Building $IMAGE..."

DOCKER_BUILDKIT=1 docker build \
    -t "$IMAGE" \
    -f "$REPO_DIR/docker/Dockerfile" \
    --target dev \
    "$REPO_DIR" || exit 1

echo "Built $IMAGE."

# start_sesh.sh continues straight into launching the session.
if [[ -z "${LAUNCHING_SESSION:-}" ]]; then
    echo "
Start the workshop session with:

    ./start_sesh.sh --build
"
fi

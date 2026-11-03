#!/bin/bash

set -euo pipefail

IMAGE="$1"
CONTAINER="flask-app"
PORT="${APP_HOST_PORT:-80}"

mkdir -p "$HOME/.cicd"

# Save the currently running image
if docker ps -q --filter "name=^/${CONTAINER}$" | grep -q .; then

    CURRENT_ID=$(docker inspect --format='{{.Image}}' "$CONTAINER")

    CURRENT_TAG=$(docker image ls --no-trunc \
      --format '{{.Repository}}:{{.Tag}} {{.ID}}' |
      awk -v id="$CURRENT_ID" '$2==id {print $1; exit}')

    if [ -n "${CURRENT_TAG:-}" ]; then
        echo "$CURRENT_TAG" > "$HOME/.cicd/previous-image"
    fi
fi

# Download new image
docker pull "$IMAGE"

# Replace old container
docker rm -f "$CONTAINER" || true

# Start new container
docker run -d \
    --name "$CONTAINER" \
    --restart unless-stopped \
    -p "${PORT}:5000" \
    "$IMAGE"

# Health check
for i in $(seq 1 20); do

    if curl --fail --silent \
      "http://127.0.0.1:${PORT}/health"; then

        echo "Deployment successful"
        exit 0
    fi

    sleep 3
done

# Automatic rollback
echo "Deployment failed. Starting rollback."

if [ -s "$HOME/.cicd/previous-image" ]; then

    PREVIOUS_IMAGE=$(cat "$HOME/.cicd/previous-image")

    docker pull "$PREVIOUS_IMAGE"
    docker rm -f "$CONTAINER" || true

    docker run -d \
        --name "$CONTAINER" \
        --restart unless-stopped \
        -p "${PORT}:5000" \
        "$PREVIOUS_IMAGE"

    for i in $(seq 1 20); do
        if curl --fail --silent \
          "http://127.0.0.1:${PORT}/health"; then

            echo "Previous version restored"
            exit 1
        fi
        sleep 3
    done
fi

echo "Rollback failed or previous image unavailable"
exit 1

#!/bin/bash

set -euo pipefail

CONTAINER="flask-app"
PORT="${APP_HOST_PORT:-80}"

FILE="$HOME/.cicd/previous-image"

if [ ! -s "$FILE" ]; then
    echo "Previous image not found"
    exit 1
fi

IMAGE=$(cat "$FILE")

docker pull "$IMAGE"

docker rm -f "$CONTAINER" || true

docker run -d \
    --name "$CONTAINER" \
    --restart unless-stopped \
    -p "${PORT}:5000" \
    "$IMAGE"

for i in $(seq 1 20); do

    if curl --fail --silent \
      "http://127.0.0.1:${PORT}/health"; then

        echo "Rollback successful"
        exit 0
    fi

    sleep 3
done

echo "Rollback health check failed"
docker logs "$CONTAINER" || true
exit 1

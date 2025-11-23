#!/bin/bash

# Cloud Tasks Demo - Trigger Script
# This script creates sample tasks and adds them to the queue

set -e

echo "=================================="
echo "Cloud Tasks Demo - Create Task"
echo "=================================="
echo ""

# Load configuration
if [ -f config.env ]; then
  source config.env
else
  echo "Error: config.env not found. Please run ./setup.sh first"
  exit 1
fi

# Generate a unique task ID
TASK_ID="task-$(date +%s)-$RANDOM"

echo "Creating task: $TASK_ID"
echo "Queue: $QUEUE_NAME"
echo "Worker URL: $FUNCTION_URL"
echo ""

# Create task payload
PAYLOAD=$(cat <<EOF
{
  "image_id": "img-${RANDOM}",
  "operation": "resize",
  "dimensions": {
    "width": 800,
    "height": 600
  },
  "format": "jpg",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)

echo "Task Payload:"
echo "$PAYLOAD" | jq .
echo ""

# Create the task
gcloud tasks create-http-task ${TASK_ID} \
  --queue=${QUEUE_NAME} \
  --location=${REGION} \
  --url="${FUNCTION_URL}" \
  --method=POST \
  --header="Content-Type: application/json" \
  --body-content="${PAYLOAD}"

echo ""
echo "✓ Task created successfully!"
echo ""
echo "Monitor task processing:"
echo "1. View logs: gcloud functions logs read tasks-demo-worker --region=${REGION} --limit=10"
echo "2. List tasks: gcloud tasks list --queue=${QUEUE_NAME} --location=${REGION}"
echo "3. View queue: gcloud tasks queues describe ${QUEUE_NAME} --location=${REGION}"
echo ""

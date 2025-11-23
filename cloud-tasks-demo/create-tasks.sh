#!/bin/bash

# Cloud Tasks Demo - Bulk Task Creation Script
# This script creates multiple tasks to demonstrate rate limiting

set -e

# Load configuration
if [ -f config.env ]; then
  source config.env
else
  echo "Error: config.env not found. Please run ./setup.sh first"
  exit 1
fi

# Get number of tasks from argument (default to 10)
NUM_TASKS=${1:-10}

echo "=================================="
echo "Cloud Tasks Demo - Bulk Creation"
echo "=================================="
echo ""
echo "Creating $NUM_TASKS tasks..."
echo "Queue: $QUEUE_NAME"
echo ""

# Array of operations to simulate different task types
OPERATIONS=("resize" "thumbnail" "resize" "thumbnail" "resize")

# Create tasks
for i in $(seq 1 $NUM_TASKS); do
  TASK_ID="bulk-task-$(date +%s)-${i}-$RANDOM"
  
  # Randomly select an operation
  OP_INDEX=$((RANDOM % ${#OPERATIONS[@]}))
  OPERATION=${OPERATIONS[$OP_INDEX]}
  
  # Create task payload
  PAYLOAD=$(cat <<EOF
{
  "image_id": "img-bulk-${i}",
  "operation": "${OPERATION}",
  "dimensions": {
    "width": $((200 + RANDOM % 1000)),
    "height": $((200 + RANDOM % 1000))
  },
  "format": "jpg",
  "batch_id": "batch-$(date +%s)",
  "task_number": ${i}
}
EOF
)
  
  # Create the task (suppress output for bulk operations)
  gcloud tasks create-http-task ${TASK_ID} \
    --queue=${QUEUE_NAME} \
    --location=${REGION} \
    --url="${FUNCTION_URL}" \
    --method=POST \
    --header="Content-Type: application/json" \
    --body-content="${PAYLOAD}" \
    --quiet
  
  echo "[$i/$NUM_TASKS] Created task: $TASK_ID (${OPERATION})"
  
  # Small delay to avoid overwhelming the API
  sleep 0.1
done

echo ""
echo "✓ Created $NUM_TASKS tasks successfully!"
echo ""
echo "Note: The queue is configured to process max 5 tasks/second"
echo "All $NUM_TASKS tasks will be processed according to rate limits"
echo ""
echo "Monitor processing:"
echo "1. View logs: gcloud functions logs read tasks-demo-worker --region=${REGION} --limit=30"
echo "2. Check queue: gcloud tasks queues describe ${QUEUE_NAME} --location=${REGION}"
echo "3. List tasks: gcloud tasks list --queue=${QUEUE_NAME} --location=${REGION}"
echo ""

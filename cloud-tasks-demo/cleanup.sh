#!/bin/bash

# Cloud Tasks Demo - Cleanup Script
# This script removes all resources created by the setup script

set -e

echo "=================================="
echo "Cloud Tasks Demo - Cleanup"
echo "=================================="
echo ""

# Configuration
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
FUNCTION_NAME="tasks-demo-worker"
QUEUE_NAME="tasks-demo-queue"

echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Delete Cloud Tasks queue
echo "1. Deleting Cloud Tasks queue..."
if gcloud tasks queues describe ${QUEUE_NAME} --location=${REGION} --quiet 2>/dev/null; then
  # First, purge all tasks from the queue
  echo "  Purging tasks from queue..."
  gcloud tasks queues purge ${QUEUE_NAME} --location=${REGION} --quiet || true
  
  # Then delete the queue
  gcloud tasks queues delete ${QUEUE_NAME} --location=${REGION} --quiet
  echo "✓ Queue deleted"
else
  echo "Queue not found, skipping"
fi
echo ""

# Delete Cloud Function
echo "2. Deleting Cloud Function worker..."
if gcloud functions describe ${FUNCTION_NAME} --gen2 --region=${REGION} --quiet 2>/dev/null; then
  gcloud functions delete ${FUNCTION_NAME} \
    --gen2 \
    --region=${REGION} \
    --quiet
  echo "✓ Worker function deleted"
else
  echo "Worker function not found, skipping"
fi
echo ""

# Remove config file
echo "3. Removing configuration file..."
if [ -f config.env ]; then
  rm config.env
  echo "✓ config.env removed"
fi
echo ""

echo "=================================="
echo "Cleanup Complete!"
echo "=================================="
echo ""
echo "All resources have been removed."

#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status.

# Get the project ID
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"

# Build the container image
echo "Building container image..."
gcloud builds submit --tag gcr.io/$PROJECT_ID/cpu-demo app

# Deploy Service 1: CPU allocated only during request processing (default)
echo "Deploying throttled service..."
# Note: --cpu-throttling enables throttling (default behavior)
gcloud run deploy cpu-throttled \
    --image gcr.io/$PROJECT_ID/cpu-demo \
    --region $REGION \
    --platform managed \
    --allow-unauthenticated \
    --cpu-throttling

# Deploy Service 2: CPU always allocated
echo "Deploying always-on service..."
# Note: --no-cpu-throttling disables throttling (always on)
gcloud run deploy cpu-always-on \
    --image gcr.io/$PROJECT_ID/cpu-demo \
    --region $REGION \
    --platform managed \
    --allow-unauthenticated \
    --no-cpu-throttling

echo "Deployment complete!"
#!/bin/bash

# Cloud Scheduler Demo - Cleanup Script
# This script removes all resources created by the setup script

set -e

echo "=================================="
echo "Cloud Scheduler Demo - Cleanup"
echo "=================================="
echo ""

# Configuration
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
FUNCTION_NAME="scheduler-demo-function"
JOB_NAME="scheduler-demo-job"
SERVICE_ACCOUNT_NAME="scheduler-invoker"

echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Delete Cloud Scheduler job
echo "1. Deleting Cloud Scheduler job..."
if gcloud scheduler jobs describe ${JOB_NAME} --location=${REGION} --quiet 2>/dev/null; then
  gcloud scheduler jobs delete ${JOB_NAME} --location=${REGION} --quiet
  echo "✓ Scheduler job deleted"
else
  echo "Scheduler job not found, skipping"
fi
echo ""

# Delete Cloud Function
echo "2. Deleting Cloud Function..."
if gcloud functions describe ${FUNCTION_NAME} --gen2 --region=${REGION} --quiet 2>/dev/null; then
  gcloud functions delete ${FUNCTION_NAME} \
    --gen2 \
    --region=${REGION} \
    --quiet
  echo "✓ Cloud Function deleted"
else
  echo "Cloud Function not found, skipping"
fi
echo ""

# Delete service account
echo "3. Deleting service account..."
if gcloud iam service-accounts describe ${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com --quiet 2>/dev/null; then
  gcloud iam service-accounts delete ${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com --quiet
  echo "✓ Service account deleted"
else
  echo "Service account not found, skipping"
fi
echo ""

echo "=================================="
echo "Cleanup Complete!"
echo "=================================="
echo ""
echo "All resources have been removed."

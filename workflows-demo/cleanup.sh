#!/bin/bash

# Workflows Demo - Cleanup Script
# This script removes all resources created by the setup script

set -e

echo "=================================="
echo "Workflows Demo - Cleanup"
echo "=================================="
echo ""

# Configuration
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
WORKFLOW_NAME="order-processing-workflow"
FUNCTION_NAME="workflow-mock-api"

echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Delete the workflow
echo "1. Deleting workflow..."
if gcloud workflows describe ${WORKFLOW_NAME} --location=${REGION} --quiet 2>/dev/null; then
  gcloud workflows delete ${WORKFLOW_NAME} --location=${REGION} --quiet
  echo "✓ Workflow deleted"
else
  echo "Workflow not found, skipping"
fi
echo ""

# Delete mock API function
echo "2. Deleting mock API function..."
if gcloud functions describe ${FUNCTION_NAME} --gen2 --region=${REGION} --quiet 2>/dev/null; then
  gcloud functions delete ${FUNCTION_NAME} \
    --gen2 \
    --region=${REGION} \
    --quiet
  echo "✓ Mock API function deleted"
else
  echo "Mock API function not found, skipping"
fi
echo ""

# Remove config files
echo "3. Removing configuration files..."
if [ -f config.env ]; then
  rm config.env
  echo "✓ config.env removed"
fi

if [ -f api-endpoints.env ]; then
  rm api-endpoints.env
  echo "✓ api-endpoints.env removed"
fi
echo ""

echo "=================================="
echo "Cleanup Complete!"
echo "=================================="
echo ""
echo "All resources have been removed."

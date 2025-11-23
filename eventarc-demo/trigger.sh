#!/bin/bash

# Eventarc Demo - Trigger Script
# This script uploads a test file to trigger the Eventarc event

set -e

echo "=================================="
echo "Eventarc Demo - Upload Test File"
echo "=================================="
echo ""

# Load configuration
if [ -f config.env ]; then
  source config.env
else
  echo "Error: config.env not found. Please run ./setup.sh first"
  exit 1
fi

echo "Bucket: gs://${BUCKET_NAME}"
echo ""

# Create a test file
TEST_FILE="test-file-$(date +%s).txt"
echo "Creating test file: ${TEST_FILE}"

cat > ${TEST_FILE} << EOF
This is a test file for Eventarc demo.
Created at: $(date)
File name: ${TEST_FILE}

This file upload will trigger an Eventarc event that will be
delivered to the Cloud Run service for processing.
EOF

echo "✓ Test file created"
echo ""

# Upload the file to trigger the event
echo "Uploading file to gs://${BUCKET_NAME}/${TEST_FILE}..."
gsutil cp ${TEST_FILE} gs://${BUCKET_NAME}/

echo "✓ File uploaded"
echo ""

# Clean up local test file
rm ${TEST_FILE}

echo "=================================="
echo "Event Triggered!"
echo "=================================="
echo ""
echo "The file upload has triggered an Eventarc event."
echo "The Cloud Run service will process this event automatically."
echo ""
echo "View the processing logs:"
echo "  gcloud run services logs read ${SERVICE_NAME} --region=${REGION} --limit=20"
echo ""
echo "Or view in Cloud Console:"
echo "  https://console.cloud.google.com/run/detail/${REGION}/${SERVICE_NAME}/logs"
echo ""
echo "Upload more files to trigger additional events:"
echo "  gsutil cp myfile.txt gs://${BUCKET_NAME}/"
echo ""

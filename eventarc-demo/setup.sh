#!/bin/bash

# Eventarc Demo - Setup Script
# This script creates a Cloud Storage bucket, Cloud Run service, and Eventarc trigger

set -e

echo "=================================="
echo "Eventarc Demo - Setup"
echo "=================================="
echo ""

# Configuration
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
REGION="us-central1"
SERVICE_NAME="eventarc-demo-service"
BUCKET_NAME="${PROJECT_ID}-eventarc-demo-${RANDOM}"
TRIGGER_NAME="storage-event-trigger"

echo "Project ID: $PROJECT_ID"
echo "Project Number: $PROJECT_NUMBER"
echo "Region: $REGION"
echo "Bucket Name: $BUCKET_NAME"
echo ""

# Enable required APIs
echo "1. Enabling required APIs..."
gcloud services enable \
  eventarc.googleapis.com \
  run.googleapis.com \
  storage.googleapis.com \
  cloudbuild.googleapis.com \
  pubsub.googleapis.com \
  --quiet

echo "✓ APIs enabled"
echo ""

# Create Cloud Storage bucket
echo "2. Creating Cloud Storage bucket..."
gsutil mb -l ${REGION} gs://${BUCKET_NAME}
echo "✓ Bucket created: gs://${BUCKET_NAME}"
echo ""

# Build and deploy Cloud Run service
echo "3. Building and deploying Cloud Run service..."
echo "   (This may take a few minutes...)"
gcloud run deploy ${SERVICE_NAME} \
  --source=./service \
  --region=${REGION} \
  --platform=managed \
  --allow-unauthenticated \
  --quiet

echo "✓ Cloud Run service deployed"
echo ""

# Get service URL
SERVICE_URL=$(gcloud run services describe ${SERVICE_NAME} \
  --region=${REGION} \
  --format='value(status.url)')

echo "Service URL: $SERVICE_URL"
echo ""

# Grant necessary permissions to Eventarc service account
echo "4. Setting up IAM permissions..."
EVENTARC_SA="service-${PROJECT_NUMBER}@gcp-sa-eventarc.iam.gserviceaccount.com"

# Grant eventarc.eventReceiver role to invoke Cloud Run
gcloud run services add-iam-policy-binding ${SERVICE_NAME} \
  --member="serviceAccount:${EVENTARC_SA}" \
  --role="roles/run.invoker" \
  --region=${REGION} \
  --quiet

# Grant pubsub.publisher role for Storage events
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
  --member="serviceAccount:${EVENTARC_SA}" \
  --role="roles/eventarc.eventReceiver" \
  --quiet

echo "✓ IAM permissions configured"
echo ""

# Create Eventarc trigger for Cloud Storage events
echo "5. Creating Eventarc trigger..."
echo "   (This may take a few minutes...)"
gcloud eventarc triggers create ${TRIGGER_NAME} \
  --location=${REGION} \
  --destination-run-service=${SERVICE_NAME} \
  --destination-run-region=${REGION} \
  --event-filters="type=google.cloud.storage.object.v1.finalized" \
  --event-filters="bucket=${BUCKET_NAME}" \
  --service-account="${EVENTARC_SA}"

echo "✓ Eventarc trigger created"
echo ""

# Store configuration for other scripts
cat > config.env << EOF
export PROJECT_ID="${PROJECT_ID}"
export REGION="${REGION}"
export BUCKET_NAME="${BUCKET_NAME}"
export SERVICE_NAME="${SERVICE_NAME}"
export TRIGGER_NAME="${TRIGGER_NAME}"
EOF

echo "=================================="
echo "Setup Complete!"
echo "=================================="
echo ""
echo "Resources created:"
echo "- Storage Bucket: gs://${BUCKET_NAME}"
echo "- Cloud Run Service: ${SERVICE_NAME}"
echo "- Eventarc Trigger: ${TRIGGER_NAME}"
echo ""
echo "Trigger Configuration:"
gcloud eventarc triggers describe ${TRIGGER_NAME} --location=${REGION}
echo ""
echo "Next steps:"
echo "1. Run './trigger.sh' to upload a test file"
echo "2. Upload files: gsutil cp yourfile.txt gs://${BUCKET_NAME}/"
echo "3. View logs: gcloud run services logs read ${SERVICE_NAME} --region=${REGION} --limit=20"
echo ""

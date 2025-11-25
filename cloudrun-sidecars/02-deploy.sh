#!/bin/bash

# Get the project ID
PROJECT_ID=$(gcloud config get-value project)

# Replace PROJECT_ID in service.yaml and deploy
sed "s/PROJECT_ID/$PROJECT_ID/g" service.yaml | gcloud run services replace - --region us-central1

# Allow unauthenticated access
gcloud run services add-iam-policy-binding sidecar-demo \
    --region us-central1 \
    --member="allUsers" \
    --role="roles/run.invoker"

# Get the URL of the deployed service
SERVICE_URL=$(gcloud run services describe sidecar-demo --region us-central1 --format 'value(status.url)')

echo ""
echo "Service deployed to: $SERVICE_URL"
echo "Testing the service with curl..."
echo "--------------------------------------------------"
curl -s $SERVICE_URL
echo ""
echo "--------------------------------------------------"
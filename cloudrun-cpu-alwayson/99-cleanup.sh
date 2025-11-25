#!/bin/bash

# Get the project ID
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"

# Delete services
gcloud run services delete cpu-throttled --region $REGION --quiet
gcloud run services delete cpu-always-on --region $REGION --quiet

# Delete image
gcloud container images delete gcr.io/$PROJECT_ID/cpu-demo --quiet
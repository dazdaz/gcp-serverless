#!/bin/bash

# Get the project ID
PROJECT_ID=$(gcloud config get-value project)

# Delete the Cloud Run service
gcloud run services delete sidecar-demo --region us-central1 --quiet

# Delete the container images
gcloud container images delete gcr.io/$PROJECT_ID/sidecar-main-app --quiet
gcloud container images delete gcr.io/$PROJECT_ID/sidecar-sidecar --quiet
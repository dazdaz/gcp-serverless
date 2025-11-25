#!/bin/bash

# Get the project ID
PROJECT_ID=$(gcloud config get-value project)

# Build the main application container
echo "Building main-app..."
gcloud builds submit --tag gcr.io/$PROJECT_ID/sidecar-main-app main-app

# Build the sidecar container
echo "Building sidecar..."
gcloud builds submit --tag gcr.io/$PROJECT_ID/sidecar-sidecar sidecar
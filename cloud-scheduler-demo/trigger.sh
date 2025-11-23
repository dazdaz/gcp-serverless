#!/bin/bash

# Cloud Scheduler Demo - Manual Trigger Script
# This script manually triggers the scheduler job for immediate testing

set -e

echo "=================================="
echo "Cloud Scheduler Demo - Trigger"
echo "=================================="
echo ""

# Configuration
REGION="us-central1"
JOB_NAME="scheduler-demo-job"

echo "Manually triggering scheduler job..."
echo ""

# Trigger the job
gcloud scheduler jobs run ${JOB_NAME} --location=${REGION}

echo "✓ Job triggered"
echo ""
echo "View the execution:"
echo "1. Check logs: gcloud functions logs read scheduler-demo-function --region=${REGION} --limit=10"
echo "2. Or visit: https://console.cloud.google.com/cloudscheduler?project=$(gcloud config get-value project)"
echo ""
echo "Note: It may take a few seconds for the function to execute and logs to appear."

#!/bin/bash

REGION="us-central1"

# Get URLs
echo "Fetching service URLs..."
THROTTLED_URL=$(gcloud run services describe cpu-throttled --region $REGION --format 'value(status.url)' 2>/dev/null)
ALWAYS_ON_URL=$(gcloud run services describe cpu-always-on --region $REGION --format 'value(status.url)' 2>/dev/null)

if [ -z "$THROTTLED_URL" ]; then
    echo "Error: Could not find URL for service 'cpu-throttled'. Make sure it is deployed."
    exit 1
fi

if [ -z "$ALWAYS_ON_URL" ]; then
    echo "Error: Could not find URL for service 'cpu-always-on'. Make sure it is deployed."
    exit 1
fi

echo ""
echo "===================================================================================================="
echo "TEST 1: Throttled Service (CPU only during requests)"
echo "URL: $THROTTLED_URL"
echo "----------------------------------------------------------------------------------------------------"
echo "Explanation: In this mode, Cloud Run throttles the CPU to nearly zero when no request is being"
echo "processed. This means background threads (like our counter) will PAUSE between requests."
echo "We expect the 'Time since last background update' to be LARGE (approx. equal to the sleep time)."
echo "===================================================================================================="
echo ""
echo "1. Making first request to wake up/check status..."
curl -s $THROTTLED_URL | grep "Time since last background update"

echo ""
echo "2. Sleeping for 5 seconds (Background thread should be PAUSED)..."
sleep 5

echo ""
echo "3. Making second request..."
curl -s $THROTTLED_URL | grep "Time since last background update"
echo "   ^-- If this value is > 5.0, it confirms the CPU was throttled!"


echo ""
echo ""
echo "===================================================================================================="
echo "TEST 2: Always-On Service (CPU always allocated)"
echo "URL: $ALWAYS_ON_URL"
echo "----------------------------------------------------------------------------------------------------"
echo "Explanation: In this mode, CPU is allocated for the entire lifecycle of the instance."
echo "This means background threads will CONTINUE RUNNING even when no request is being processed."
echo "We expect the 'Time since last background update' to be SMALL (approx. 1 second)."
echo "===================================================================================================="
echo ""
echo "1. Making first request..."
curl -s $ALWAYS_ON_URL | grep "Time since last background update"

echo ""
echo "2. Sleeping for 5 seconds (Background thread should KEEP RUNNING)..."
sleep 5

echo ""
echo "3. Making second request..."
curl -s $ALWAYS_ON_URL | grep "Time since last background update"
echo "   ^-- If this value is small (~1.0), it confirms the CPU was active in the background!"
echo ""
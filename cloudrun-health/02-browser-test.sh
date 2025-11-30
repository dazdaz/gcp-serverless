#!/bin/bash
#
# Cloud Run Service Health Demo - Browser Test Script
#
# This script creates local proxies to the Cloud Run services,
# allowing you to test the services in a web browser without
# manually handling authentication tokens.
#
# Usage:
#   ./02-browser-test.sh
#
# This will start proxies on:
#   - http://localhost:8080 → us-central1 service
#   - http://localhost:8081 → europe-west1 service
#
# Press Ctrl+C to stop the proxies.
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SERVICE="health-demo"
REGION_A="us-central1"
REGION_B="europe-west1"
PORT_A=8080
PORT_B=8081

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Cloud Run Service Health Demo - Browser Test${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  This script creates local proxies to your Cloud Run services."
echo -e "  The proxies handle authentication automatically, so you can"
echo -e "  access the services directly in your web browser."
echo ""

# Check if services exist
URL_A=$(gcloud run services describe $SERVICE --region=$REGION_A --format='value(status.url)' 2>/dev/null || true)
URL_B=$(gcloud run services describe $SERVICE --region=$REGION_B --format='value(status.url)' 2>/dev/null || true)

if [ -z "$URL_A" ] || [ -z "$URL_B" ]; then
    echo -e "${RED}Error: Services not found. Run ./01-setup.sh first.${NC}"
    exit 1
fi

echo -e "${YELLOW}Starting local proxies...${NC}"
echo ""
echo -e "  ${GREEN}http://localhost:$PORT_A${NC} → $REGION_A ($URL_A)"
echo -e "  ${GREEN}http://localhost:$PORT_B${NC} → $REGION_B ($URL_B)"
echo ""
echo -e "${YELLOW}Open these URLs in your browser to test:${NC}"
echo ""
echo -e "  ${BLUE}Region A (us-central1):${NC}"
echo -e "    Main page:     ${GREEN}http://localhost:$PORT_A/${NC}"
echo -e "    Status API:    ${GREEN}http://localhost:$PORT_A/status${NC}"
echo -e "    Health check:  ${GREEN}http://localhost:$PORT_A/health${NC}"
echo ""
echo -e "  ${BLUE}Region B (europe-west1):${NC}"
echo -e "    Main page:     ${GREEN}http://localhost:$PORT_B/${NC}"
echo -e "    Status API:    ${GREEN}http://localhost:$PORT_B/status${NC}"
echo -e "    Health check:  ${GREEN}http://localhost:$PORT_B/health${NC}"
echo ""
echo -e "${YELLOW}To test failover:${NC}"
echo -e "  1. Open http://localhost:$PORT_A/ in your browser"
echo -e "  2. Use the web UI to toggle health status"
echo -e "  3. Watch the readiness probe status change"
echo ""
echo -e "${YELLOW}To run CLI tests while browser testing:${NC}"
echo -e "  Open a new terminal and run: ${GREEN}./03-test-failover.sh${NC}"
echo ""
echo -e "${RED}Press Ctrl+C to stop the proxies${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}Stopping proxies...${NC}"
    kill $PID_A 2>/dev/null
    kill $PID_B 2>/dev/null
    echo -e "${GREEN}Done.${NC}"
    exit 0
}

trap cleanup INT TERM

# Start proxies in background
gcloud run services proxy $SERVICE --region=$REGION_A --port=$PORT_A 2>&1 | sed "s/^/[$REGION_A] /" &
PID_A=$!

gcloud run services proxy $SERVICE --region=$REGION_B --port=$PORT_B 2>&1 | sed "s/^/[$REGION_B] /" &
PID_B=$!

# Wait for proxies
wait
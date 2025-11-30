#!/bin/bash
#
# Cloud Run Service Health Demo - Failover Test Script
#
# This script demonstrates the multi-region failover capabilities by:
# 1. Making requests through the load balancer
# 2. Making one region unhealthy
# 3. Observing traffic shift to the healthy region
# 4. Restoring health and observing failback
#
# Usage:
#   ./03-test-failover.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
SERVICE="health-demo"
REGION_A="us-central1"
REGION_B="europe-west1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERT_FILE="$SCRIPT_DIR/selfsigned-cert.pem"

# Get URLs (use || true to prevent set -e from exiting on error)
LB_IP=$(gcloud compute addresses describe $SERVICE-ip --global --format='value(address)' 2>/dev/null || true)
URL_A=$(gcloud run services describe $SERVICE --region=$REGION_A --format='value(status.url)' 2>/dev/null || true)
URL_B=$(gcloud run services describe $SERVICE --region=$REGION_B --format='value(status.url)' 2>/dev/null || true)

if [ -z "$LB_IP" ]; then
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  Error: Load balancer not found${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  The demo infrastructure hasn't been deployed yet."
    echo ""
    echo -e "  Please run ${GREEN}./01-setup.sh${NC} first to deploy:"
    echo -e "    - Cloud Run services in $REGION_A and $REGION_B"
    echo -e "    - Global External Application Load Balancer"
    echo -e "    - Serverless NEGs and backend services"
    echo ""
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Cloud Run Service Health Demo - Failover Test${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Project:        ${GREEN}$PROJECT_ID${NC}"
echo -e "  Load Balancer:  ${GREEN}https://$LB_IP${NC}"
echo -e "  Region A URL:   ${GREEN}$URL_A${NC}"
echo -e "  Region B URL:   ${GREEN}$URL_B${NC}"
echo ""

# Get auth token for authenticated requests
AUTH_TOKEN=$(gcloud auth print-identity-token 2>/dev/null)
if [ -z "$AUTH_TOKEN" ]; then
    echo -e "${RED}Error: Could not get auth token. Run 'gcloud auth login' first.${NC}"
    exit 1
fi

# Determine curl SSL options based on whether we have a cert file
if [ -f "$CERT_FILE" ]; then
    CURL_SSL_OPTS="--cacert $CERT_FILE"
else
    CURL_SSL_OPTS="--insecure"
    echo -e "${YELLOW}Note: Using --insecure for HTTPS (no cert file found)${NC}"
    echo ""
fi

# Function to make a request and show the result
make_request() {
    local url=$1
    local label=$2
    
    echo -e "${CYAN}→ Request to $label${NC}"
    echo -e "  ${BLUE}$ curl -s $CURL_SSL_OPTS -H \"Authorization: Bearer \$TOKEN\" \"$url/status\"${NC}"
    response=$(curl -s $CURL_SSL_OPTS -H "Authorization: Bearer $AUTH_TOKEN" "$url/status" 2>/dev/null || echo '{"error": "request failed"}')
    
    region=$(echo "$response" | grep -o '"region":"[^"]*"' | cut -d'"' -f4)
    healthy=$(echo "$response" | grep -o '"healthy":[^,}]*' | cut -d':' -f2)
    
    if [ -n "$region" ]; then
        if [ "$healthy" = "true" ]; then
            echo -e "  Region: ${GREEN}$region${NC} | Health: ${GREEN}healthy${NC}"
        else
            echo -e "  Region: ${YELLOW}$region${NC} | Health: ${RED}unhealthy${NC}"
        fi
    else
        echo -e "  ${RED}Failed to get response${NC}"
    fi
    echo ""
}

# Function to set health on a region
set_health() {
    local url=$1
    local healthy=$2
    local region=$3
    
    if [ "$healthy" = "true" ]; then
        echo -e "${GREEN}Setting $region to HEALTHY${NC}"
    else
        echo -e "${RED}Setting $region to UNHEALTHY${NC}"
    fi
    
    echo -e "  ${BLUE}$ curl -s -X POST -H \"Authorization: Bearer \$TOKEN\" \"$url/set_health?healthy=$healthy\"${NC}"
    curl -s -X POST -H "Authorization: Bearer $AUTH_TOKEN" "$url/set_health?healthy=$healthy" > /dev/null
}

# Function to wait with countdown
wait_with_countdown() {
    local seconds=$1
    local message=$2
    
    echo -ne "${YELLOW}$message${NC}"
    for ((i=seconds; i>0; i--)); do
        echo -ne " $i"
        sleep 1
    done
    echo ""
}

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 1: Check Initial State${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "Checking health status of each region directly..."
echo ""
make_request "$URL_A" "$REGION_A (direct)"
make_request "$URL_B" "$REGION_B (direct)"

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 2: Test Load Balancer Routing${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "Making 5 requests through the load balancer..."
echo -e "(You should see responses from your nearest healthy region)"
echo ""

for i in {1..5}; do
    make_request "https://$LB_IP" "Load Balancer (#$i)"
    sleep 1
done

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 3: Trigger Failover (Make Region A Unhealthy)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

set_health "$URL_A" "false" "$REGION_A"
echo ""

echo -e "Verifying health status..."
make_request "$URL_A" "$REGION_A (direct)"
make_request "$URL_B" "$REGION_B (direct)"

echo -e "${YELLOW}Note: It may take 30-60 seconds for the load balancer to detect${NC}"
echo -e "${YELLOW}the unhealthy status and shift traffic.${NC}"
echo ""

wait_with_countdown 30 "Waiting for failover..."
echo ""

echo -e "Making 5 requests through the load balancer..."
echo -e "(You should now see responses from $REGION_B only)"
echo ""

for i in {1..5}; do
    make_request "https://$LB_IP" "Load Balancer (#$i)"
    sleep 1
done

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Step 4: Restore Health (Failback)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

set_health "$URL_A" "true" "$REGION_A"
echo ""

echo -e "Verifying health status..."
make_request "$URL_A" "$REGION_A (direct)"
make_request "$URL_B" "$REGION_B (direct)"

echo -e "${YELLOW}Note: Failback may take 30-60 seconds as the load balancer${NC}"
echo -e "${YELLOW}detects the healthy status.${NC}"
echo ""

wait_with_countdown 30 "Waiting for failback..."
echo ""

echo -e "Making 5 requests through the load balancer..."
echo -e "(Traffic should return to your nearest region)"
echo ""

for i in {1..5}; do
    make_request "https://$LB_IP" "Load Balancer (#$i)"
    sleep 1
done

echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Failover Test Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Summary:"
echo -e "    • Both regions are now healthy"
echo -e "    • Traffic is routed based on proximity"
echo -e "    • Failover/failback occurred automatically"
echo ""
echo -e "  Try these commands for manual testing:"
echo ""
echo -e "    ${CYAN}# Get auth token (required for authenticated services)${NC}"
echo -e "    export TOKEN=\$(gcloud auth print-identity-token)"
echo ""
echo -e "    ${CYAN}# Make Region A unhealthy${NC}"
echo -e "    curl -X POST -H \"Authorization: Bearer \$TOKEN\" '$URL_A/set_health?healthy=false'"
echo ""
echo -e "    ${CYAN}# Make Region A healthy again${NC}"
echo -e "    curl -X POST -H \"Authorization: Bearer \$TOKEN\" '$URL_A/set_health?healthy=true'"
echo ""
echo -e "    ${CYAN}# Set 50% readiness (random failures)${NC}"
echo -e "    curl -X POST -H \"Authorization: Bearer \$TOKEN\" '$URL_A/set_readiness?percent=50'"
echo ""
echo -e "    ${CYAN}# Test through load balancer${NC}"
if [ -f "$CERT_FILE" ]; then
    echo -e "    curl --cacert ./selfsigned-cert.pem -H \"Authorization: Bearer \$TOKEN\" https://$LB_IP/status | jq ."
else
    echo -e "    curl --insecure -H \"Authorization: Bearer \$TOKEN\" https://$LB_IP/status | jq ."
fi
echo ""
#!/bin/bash
#
# Cloud Run Service Health Demo - Cleanup Script
#
# This script removes all resources created by the demo:
# - Cloud Run services in both regions
# - Load balancer components (forwarding rules, proxies, URL maps)
# - SSL certificate
# - External IP address
# - Serverless NEGs
# - Backend service
# - Container images
#
# Usage:
#   ./99-cleanup.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
SERVICE="health-demo"
REGION_A="us-central1"
REGION_B="europe-west1"

if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: No project set. Run 'gcloud config set project YOUR_PROJECT_ID'${NC}"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Cloud Run Service Health Demo - Cleanup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Project:  ${GREEN}$PROJECT_ID${NC}"
echo -e "  Service:  ${GREEN}$SERVICE${NC}"
echo ""
echo -e "${YELLOW}This will delete all resources created by the demo.${NC}"
echo ""
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cleanup cancelled.${NC}"
    exit 0
fi

echo ""

# Helper function to run command silently but show what's being run
run_cmd() {
    echo -e "  ${GREEN}$1${NC}"
    eval "$1" >/dev/null 2>&1 || true
}

# Delete forwarding rules
echo -e "${YELLOW}[1/10] Deleting forwarding rules...${NC}"
run_cmd "gcloud compute forwarding-rules delete $SERVICE-https-fr --global --quiet"
run_cmd "gcloud compute forwarding-rules delete $SERVICE-http-fr --global --quiet"

# Delete target proxies
echo -e "${YELLOW}[2/10] Deleting target proxies...${NC}"
run_cmd "gcloud compute target-https-proxies delete $SERVICE-https-proxy --global --quiet"
run_cmd "gcloud compute target-http-proxies delete $SERVICE-http-proxy --global --quiet"

# Delete URL maps
echo -e "${YELLOW}[3/10] Deleting URL maps...${NC}"
run_cmd "gcloud compute url-maps delete $SERVICE-lb --global --quiet"
run_cmd "gcloud compute url-maps delete $SERVICE-http-redirect --global --quiet"

# Delete SSL certificate
echo -e "${YELLOW}[4/10] Deleting SSL certificate...${NC}"
run_cmd "gcloud compute ssl-certificates delete $SERVICE-cert --global --quiet"

# Delete external IP address
echo -e "${YELLOW}[5/10] Releasing external IP address...${NC}"
run_cmd "gcloud compute addresses delete $SERVICE-ip --global --quiet"

# Delete backend service
echo -e "${YELLOW}[6/10] Deleting backend service...${NC}"
run_cmd "gcloud compute backend-services delete $SERVICE-bs --global --quiet"

# Delete Serverless NEGs
echo -e "${YELLOW}[7/10] Deleting serverless NEGs...${NC}"
run_cmd "gcloud compute network-endpoint-groups delete $SERVICE-neg-$REGION_A --region=$REGION_A --quiet"
run_cmd "gcloud compute network-endpoint-groups delete $SERVICE-neg-$REGION_B --region=$REGION_B --quiet"

# Delete Cloud Run services
echo -e "${YELLOW}[8/10] Deleting Cloud Run services...${NC}"
run_cmd "gcloud run services delete $SERVICE --region=$REGION_A --quiet"
run_cmd "gcloud run services delete $SERVICE --region=$REGION_B --quiet"

# Delete container images
echo -e "${YELLOW}[9/10] Deleting container images...${NC}"
# List and delete all tags for the image
for digest in $(gcloud container images list-tags gcr.io/$PROJECT_ID/$SERVICE --format='get(digest)' 2>/dev/null); do
    run_cmd "gcloud container images delete gcr.io/$PROJECT_ID/$SERVICE@$digest --force-delete-tags --quiet"
done

# Clean up any leftover build artifacts and local files
echo -e "${YELLOW}[10/10] Cleaning up build artifacts and local files...${NC}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/selfsigned-cert.pem" ]; then
    run_cmd "rm -f $SCRIPT_DIR/selfsigned-cert.pem"
fi
echo -e "  ${GREEN}Build artifacts will be cleaned by retention policies${NC}"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Cleanup Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  All demo resources have been deleted."
echo ""
echo -e "  ${YELLOW}Note: Some resources may take a few minutes to fully delete.${NC}"
echo ""
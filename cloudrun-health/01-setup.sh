#!/bin/bash
#
# Cloud Run Service Health Demo - Setup Script
#
# This script deploys a multi-region Cloud Run service with:
# - Readiness probes for health monitoring
# - Global External Application Load Balancer
# - HTTPS with SSL certificate
# - Serverless NEGs for backend connectivity
#
# Usage:
#   ./01-setup.sh              # Uses self-signed cert for testing
#   ./01-setup.sh mydomain.com # Uses Google-managed cert for domain
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
DOMAIN="${1:-}"  # Optional domain for Google-managed cert

# Validate project
if [ -z "$PROJECT_ID" ]; then
    echo -e "${RED}Error: No project set. Run 'gcloud config set project YOUR_PROJECT_ID'${NC}"
    exit 1
fi

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Cloud Run Service Health Demo - Setup${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Project:     ${GREEN}$PROJECT_ID${NC}"
echo -e "  Service:     ${GREEN}$SERVICE${NC}"
echo -e "  Region A:    ${GREEN}$REGION_A${NC}"
echo -e "  Region B:    ${GREEN}$REGION_B${NC}"
if [ -n "$DOMAIN" ]; then
    echo -e "  Domain:      ${GREEN}$DOMAIN${NC} (Google-managed cert)"
else
    echo -e "  SSL:         ${YELLOW}Self-signed certificate (for testing)${NC}"
fi
echo ""

# Enable required APIs
echo -e "${YELLOW}[1/12] Enabling required APIs...${NC}"
echo -e "  ${GREEN}gcloud services enable run.googleapis.com compute.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com --quiet${NC}"
gcloud services enable \
    run.googleapis.com \
    compute.googleapis.com \
    cloudbuild.googleapis.com \
    artifactregistry.googleapis.com \
    --quiet

# Build container image
echo -e "${YELLOW}[2/12] Building container image...${NC}"
cd "$(dirname "$0")/app"
echo -e "  ${GREEN}gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE --quiet${NC}"
gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE --quiet
cd ..

# Create service YAML with readiness probe for Region A
echo -e "${YELLOW}[3/12] Creating service configuration with readiness probe...${NC}"
cat > /tmp/service-$REGION_A.yaml << EOF
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: $SERVICE
  labels:
    cloud.googleapis.com/location: $REGION_A
  annotations:
    run.googleapis.com/launch-stage: BETA
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"
        run.googleapis.com/startup-cpu-boost: "true"
        run.googleapis.com/launch-stage: BETA
    spec:
      containers:
        - image: gcr.io/$PROJECT_ID/$SERVICE
          ports:
            - containerPort: 8080
          env:
            - name: CLOUD_RUN_REGION
              value: "$REGION_A"
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            periodSeconds: 10
            failureThreshold: 3
            successThreshold: 1
            timeoutSeconds: 1
EOF

# Create service YAML for Region B
cat > /tmp/service-$REGION_B.yaml << EOF
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: $SERVICE
  labels:
    cloud.googleapis.com/location: $REGION_B
  annotations:
    run.googleapis.com/launch-stage: BETA
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"
        run.googleapis.com/startup-cpu-boost: "true"
        run.googleapis.com/launch-stage: BETA
    spec:
      containers:
        - image: gcr.io/$PROJECT_ID/$SERVICE
          ports:
            - containerPort: 8080
          env:
            - name: CLOUD_RUN_REGION
              value: "$REGION_B"
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            periodSeconds: 10
            failureThreshold: 3
            successThreshold: 1
            timeoutSeconds: 1
EOF

# Deploy to Region A
echo -e "${YELLOW}[4/12] Deploying to $REGION_A...${NC}"
# Delete existing service if it exists (to ensure clean state with BETA annotation)
echo -e "  ${GREEN}gcloud run services delete $SERVICE --region=$REGION_A --quiet${NC}"
gcloud run services delete $SERVICE --region=$REGION_A --quiet 2>/dev/null || true
echo -e "  ${GREEN}gcloud run services replace /tmp/service-$REGION_A.yaml --region=$REGION_A --quiet${NC}"
gcloud run services replace /tmp/service-$REGION_A.yaml --region=$REGION_A --quiet

# Allow unauthenticated access for Region A (may fail if org policy restricts this)
echo -e "  ${GREEN}gcloud run services add-iam-policy-binding $SERVICE --region=$REGION_A --member=allUsers --role=roles/run.invoker --quiet${NC}"
gcloud run services add-iam-policy-binding $SERVICE \
    --region=$REGION_A \
    --member="allUsers" \
    --role="roles/run.invoker" \
    --quiet 2>/dev/null || echo -e "  ${YELLOW}Note: Unauthenticated access not allowed by org policy. Service requires authentication.${NC}"

# Deploy to Region B
echo -e "${YELLOW}[5/12] Deploying to $REGION_B...${NC}"
# Delete existing service if it exists (to ensure clean state with BETA annotation)
echo -e "  ${GREEN}gcloud run services delete $SERVICE --region=$REGION_B --quiet${NC}"
gcloud run services delete $SERVICE --region=$REGION_B --quiet 2>/dev/null || true
echo -e "  ${GREEN}gcloud run services replace /tmp/service-$REGION_B.yaml --region=$REGION_B --quiet${NC}"
gcloud run services replace /tmp/service-$REGION_B.yaml --region=$REGION_B --quiet

# Allow unauthenticated access for Region B (may fail if org policy restricts this)
echo -e "  ${GREEN}gcloud run services add-iam-policy-binding $SERVICE --region=$REGION_B --member=allUsers --role=roles/run.invoker --quiet${NC}"
gcloud run services add-iam-policy-binding $SERVICE \
    --region=$REGION_B \
    --member="allUsers" \
    --role="roles/run.invoker" \
    --quiet 2>/dev/null || echo -e "  ${YELLOW}Note: Unauthenticated access not allowed by org policy. Service requires authentication.${NC}"

# Create Backend Service
echo -e "${YELLOW}[6/12] Creating backend service...${NC}"
echo -e "  ${GREEN}gcloud compute backend-services create $SERVICE-bs --load-balancing-scheme=EXTERNAL_MANAGED --global --quiet${NC}"
gcloud compute backend-services create $SERVICE-bs \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --global \
    --quiet 2>/dev/null || echo "  (Backend service already exists)"

# Create Serverless NEG for Region A
echo -e "${YELLOW}[7/12] Creating serverless NEG for $REGION_A...${NC}"
echo -e "  ${GREEN}gcloud compute network-endpoint-groups create $SERVICE-neg-$REGION_A --region=$REGION_A --network-endpoint-type=serverless --cloud-run-service=$SERVICE --quiet${NC}"
gcloud compute network-endpoint-groups create $SERVICE-neg-$REGION_A \
    --region=$REGION_A \
    --network-endpoint-type=serverless \
    --cloud-run-service=$SERVICE \
    --quiet 2>/dev/null || echo "  (NEG already exists)"

# Add backend for Region A
echo -e "  ${GREEN}gcloud compute backend-services add-backend $SERVICE-bs --global --network-endpoint-group=$SERVICE-neg-$REGION_A --network-endpoint-group-region=$REGION_A --quiet${NC}"
gcloud compute backend-services add-backend $SERVICE-bs \
    --global \
    --network-endpoint-group=$SERVICE-neg-$REGION_A \
    --network-endpoint-group-region=$REGION_A \
    --quiet 2>/dev/null || echo "  (Backend already exists)"

# Create Serverless NEG for Region B
echo -e "${YELLOW}[8/12] Creating serverless NEG for $REGION_B...${NC}"
echo -e "  ${GREEN}gcloud compute network-endpoint-groups create $SERVICE-neg-$REGION_B --region=$REGION_B --network-endpoint-type=serverless --cloud-run-service=$SERVICE --quiet${NC}"
gcloud compute network-endpoint-groups create $SERVICE-neg-$REGION_B \
    --region=$REGION_B \
    --network-endpoint-type=serverless \
    --cloud-run-service=$SERVICE \
    --quiet 2>/dev/null || echo "  (NEG already exists)"

# Add backend for Region B
echo -e "  ${GREEN}gcloud compute backend-services add-backend $SERVICE-bs --global --network-endpoint-group=$SERVICE-neg-$REGION_B --network-endpoint-group-region=$REGION_B --quiet${NC}"
gcloud compute backend-services add-backend $SERVICE-bs \
    --global \
    --network-endpoint-group=$SERVICE-neg-$REGION_B \
    --network-endpoint-group-region=$REGION_B \
    --quiet 2>/dev/null || echo "  (Backend already exists)"

# Reserve external IP address
echo -e "${YELLOW}[9/12] Reserving external IP address...${NC}"
echo -e "  ${GREEN}gcloud compute addresses create $SERVICE-ip --network-tier=PREMIUM --ip-version=IPV4 --global --quiet${NC}"
gcloud compute addresses create $SERVICE-ip \
    --network-tier=PREMIUM \
    --ip-version=IPV4 \
    --global \
    --quiet 2>/dev/null || echo "  (IP already reserved)"

LB_IP=$(gcloud compute addresses describe $SERVICE-ip --global --format='value(address)')
echo -e "  Load Balancer IP: ${GREEN}$LB_IP${NC}"

# Create SSL Certificate
echo -e "${YELLOW}[10/12] Creating SSL certificate...${NC}"
if [ -n "$DOMAIN" ]; then
    # Option 1: Google-managed certificate (requires domain)
    echo -e "  ${GREEN}gcloud compute ssl-certificates create $SERVICE-cert --domains=$DOMAIN --global --quiet${NC}"
    gcloud compute ssl-certificates create $SERVICE-cert \
        --domains=$DOMAIN \
        --global \
        --quiet 2>/dev/null || echo "  (Certificate already exists)"
    echo -e "  Using Google-managed certificate for ${GREEN}$DOMAIN${NC}"
    echo -e "  ${YELLOW}Note: Point your DNS A record to $LB_IP${NC}"
else
    # Option 2: Self-signed certificate (for testing)
    CERT_DIR="$(dirname "$0")"
    echo -e "  ${GREEN}openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/key.pem -out $CERT_DIR/selfsigned-cert.pem${NC}"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /tmp/key.pem \
        -out "$CERT_DIR/selfsigned-cert.pem" \
        -subj "/CN=$SERVICE.example.com/O=Demo" \
        2>/dev/null
    
    echo -e "  ${GREEN}gcloud compute ssl-certificates create $SERVICE-cert --certificate=$CERT_DIR/selfsigned-cert.pem --private-key=/tmp/key.pem --global --quiet${NC}"
    gcloud compute ssl-certificates create $SERVICE-cert \
        --certificate="$CERT_DIR/selfsigned-cert.pem" \
        --private-key=/tmp/key.pem \
        --global \
        --quiet 2>/dev/null || echo "  (Certificate already exists)"
    
    rm -f /tmp/key.pem
    echo -e "  Using self-signed certificate (browser will show warning)"
    echo -e "  Certificate saved to: ${GREEN}$CERT_DIR/selfsigned-cert.pem${NC}"
fi

# Create URL map
echo -e "${YELLOW}[11/12] Creating URL map and HTTPS proxy...${NC}"
echo -e "  ${GREEN}gcloud compute url-maps create $SERVICE-lb --default-service=$SERVICE-bs --global --quiet${NC}"
gcloud compute url-maps create $SERVICE-lb \
    --default-service=$SERVICE-bs \
    --global \
    --quiet 2>/dev/null || echo "  (URL map already exists)"

# Create HTTPS target proxy
echo -e "  ${GREEN}gcloud compute target-https-proxies create $SERVICE-https-proxy --url-map=$SERVICE-lb --ssl-certificates=$SERVICE-cert --global --quiet${NC}"
gcloud compute target-https-proxies create $SERVICE-https-proxy \
    --url-map=$SERVICE-lb \
    --ssl-certificates=$SERVICE-cert \
    --global \
    --quiet 2>/dev/null || echo "  (HTTPS proxy already exists)"

# Create HTTPS forwarding rule
echo -e "${YELLOW}[12/12] Creating forwarding rules...${NC}"
echo -e "  ${GREEN}gcloud compute forwarding-rules create $SERVICE-https-fr --load-balancing-scheme=EXTERNAL_MANAGED --network-tier=PREMIUM --address=$SERVICE-ip --target-https-proxy=$SERVICE-https-proxy --global --ports=443 --quiet${NC}"
gcloud compute forwarding-rules create $SERVICE-https-fr \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --network-tier=PREMIUM \
    --address=$SERVICE-ip \
    --target-https-proxy=$SERVICE-https-proxy \
    --global \
    --ports=443 \
    --quiet 2>/dev/null || echo "  (HTTPS forwarding rule already exists)"

# Create HTTP to HTTPS redirect
cat > /tmp/http-redirect.yaml << EOF
name: $SERVICE-http-redirect
defaultUrlRedirect:
  redirectResponseCode: MOVED_PERMANENTLY_DEFAULT
  httpsRedirect: true
EOF

echo -e "  ${GREEN}gcloud compute url-maps import $SERVICE-http-redirect --source=/tmp/http-redirect.yaml --global --quiet${NC}"
gcloud compute url-maps import $SERVICE-http-redirect \
    --source=/tmp/http-redirect.yaml \
    --global \
    --quiet 2>/dev/null || echo "  (HTTP redirect already exists)"

echo -e "  ${GREEN}gcloud compute target-http-proxies create $SERVICE-http-proxy --url-map=$SERVICE-http-redirect --global --quiet${NC}"
gcloud compute target-http-proxies create $SERVICE-http-proxy \
    --url-map=$SERVICE-http-redirect \
    --global \
    --quiet 2>/dev/null || echo "  (HTTP proxy already exists)"

echo -e "  ${GREEN}gcloud compute forwarding-rules create $SERVICE-http-fr --load-balancing-scheme=EXTERNAL_MANAGED --network-tier=PREMIUM --address=$SERVICE-ip --target-http-proxy=$SERVICE-http-proxy --global --ports=80 --quiet${NC}"
gcloud compute forwarding-rules create $SERVICE-http-fr \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --network-tier=PREMIUM \
    --address=$SERVICE-ip \
    --target-http-proxy=$SERVICE-http-proxy \
    --global \
    --ports=80 \
    --quiet 2>/dev/null || echo "  (HTTP forwarding rule already exists)"

# Clean up temp files
rm -f /tmp/service-$REGION_A.yaml /tmp/service-$REGION_B.yaml /tmp/http-redirect.yaml

# Get service URLs
URL_A=$(gcloud run services describe $SERVICE --region=$REGION_A --format='value(status.url)')
URL_B=$(gcloud run services describe $SERVICE --region=$REGION_B --format='value(status.url)')

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Deployment Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BLUE}Load Balancer:${NC}"
echo -e "    HTTPS:  ${GREEN}https://$LB_IP${NC}"
if [ -n "$DOMAIN" ]; then
    echo -e "    Domain: ${GREEN}https://$DOMAIN${NC} (after DNS propagation)"
fi
echo ""
echo -e "  ${BLUE}Direct Service URLs:${NC}"
echo -e "    $REGION_A: ${GREEN}$URL_A${NC}"
echo -e "    $REGION_B: ${GREEN}$URL_B${NC}"
echo ""
echo -e "  ${BLUE}Authentication:${NC}"
echo -e "    If your GCP project has Domain Restricted Sharing enabled,"
echo -e "    you'll need to use an identity token to access services:"
echo ""
echo -e "    ${GREEN}# Get identity token${NC}"
echo -e "    TOKEN=\$(gcloud auth print-identity-token)"
echo ""
echo -e "    ${GREEN}# Access services directly${NC}"
echo -e "    curl -H \"Authorization: Bearer \$TOKEN\" $URL_A/"
echo -e "    curl -H \"Authorization: Bearer \$TOKEN\" $URL_B/"
echo ""
if [ -n "$DOMAIN" ]; then
    echo -e "    ${GREEN}# Access via Load Balancer (after DNS propagation)${NC}"
    echo -e "    curl -H \"Authorization: Bearer \$TOKEN\" https://$DOMAIN/"
else
    echo -e "    ${GREEN}# Access via Load Balancer${NC}"
    echo -e "    ${YELLOW}# Note: Using --cacert to trust self-signed cert, or use a real domain${NC}"
    echo -e "    curl --cacert ./selfsigned-cert.pem -H \"Authorization: Bearer \$TOKEN\" https://$LB_IP/"
    echo -e "    ${YELLOW}# Or for quick testing (less secure):${NC}"
    echo -e "    curl --insecure -H \"Authorization: Bearer \$TOKEN\" https://$LB_IP/"
fi
echo ""
echo -e "  ${YELLOW}Note: Load balancer may take 5-10 minutes to become fully operational.${NC}"
echo ""
echo -e "  ${BLUE}Next steps:${NC}"
echo -e "    1. Run ${GREEN}./02-browser-test.sh${NC} to open the web UI in your browser"
echo -e "       (creates local proxies with automatic authentication)"
echo -e "    2. Use the web UI to toggle health status and observe behavior"
echo -e "    3. Run ${GREEN}./03-test-failover.sh${NC} to test load balancer failover (CLI)"
echo ""
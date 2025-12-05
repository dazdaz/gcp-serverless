#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
FWD_RULE=$(gcloud compute forwarding-rules describe demo2-https-rule --global --project="$PROJECT_ID" --format='value(selfLink)' 2>/dev/null)

cat > /tmp/lb-traffic-extension.yaml << EOF
name: smart-router-extension
loadBalancingScheme: EXTERNAL_MANAGED
forwardingRules:
  - ${FWD_RULE}
extensionChains:
  - name: router-chain
    matchCondition:
      celExpression: "true"
    extensions:
      - name: smart-router
        service: projects/${PROJECT_ID}/locations/global/wasmPlugins/smart-router
        failOpen: true
        supportedEvents:
          - REQUEST_HEADERS
          - RESPONSE_HEADERS
EOF

echo "=== Creating LB Traffic Extension ==="
gcloud service-extensions lb-traffic-extensions import smart-router-extension \
    --location=global \
    --project="$PROJECT_ID" \
    --source=/tmp/lb-traffic-extension.yaml

echo "=== Done ==="
rm -f /tmp/lb-traffic-extension.yaml
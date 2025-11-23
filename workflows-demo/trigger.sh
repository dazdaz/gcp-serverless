#!/bin/bash

# Workflows Demo - Trigger Script
# This script executes the workflow with sample order data

set -e

echo "=================================="
echo "Workflows Demo - Execute Workflow"
echo "=================================="
echo ""

# Load configuration
if [ -f config.env ]; then
  source config.env
else
  echo "Error: config.env not found. Please run ./setup.sh first"
  exit 1
fi

if [ -f api-endpoints.env ]; then
  source api-endpoints.env
else
  echo "Error: api-endpoints.env not found. Please run ./setup.sh first"
  exit 1
fi

echo "Workflow: $WORKFLOW_NAME"
echo ""

# Create sample order data
ORDER_DATA=$(cat <<EOF
{
  "order": {
    "order_id": "ORD-$(date +%s)",
    "customer_id": "CUST-12345",
    "items": [
      {
        "product_id": "PROD-001",
        "name": "Widget",
        "quantity": 2,
        "price": 29.99
      },
      {
        "product_id": "PROD-002",
        "name": "Gadget",
        "quantity": 1,
        "price": 49.99
      }
    ],
    "total": 109.97,
    "shipping_address": {
      "street": "123 Main St",
      "city": "San Francisco",
      "state": "CA",
      "zip": "94102"
    }
  },
  "validate_url": "${VALIDATE_URL}",
  "inventory_url": "${INVENTORY_URL}",
  "shipping_url": "${SHIPPING_URL}",
  "tax_url": "${TAX_URL}",
  "payment_url": "${PAYMENT_URL}",
  "notification_url": "${NOTIFICATION_URL}"
}
EOF
)

echo "Order Data:"
echo "$ORDER_DATA" | jq .
echo ""

# Execute the workflow
echo "Executing workflow..."
EXECUTION_ID=$(gcloud workflows run ${WORKFLOW_NAME} \
  --location=${REGION} \
  --data="${ORDER_DATA}" \
  --format='value(name)')

echo "✓ Workflow execution started"
echo ""
echo "Execution ID: $EXECUTION_ID"
echo ""

# Wait a moment for execution to start
sleep 2

# Check execution status
echo "Checking execution status..."
gcloud workflows executions describe ${EXECUTION_ID} \
  --workflow=${WORKFLOW_NAME} \
  --location=${REGION}

echo ""
echo "=================================="
echo "Workflow Execution Triggered"
echo "=================================="
echo ""
echo "Monitor execution:"
echo "1. Describe execution:"
echo "   gcloud workflows executions describe ${EXECUTION_ID} --workflow=${WORKFLOW_NAME} --location=${REGION}"
echo ""
echo "2. Wait for completion and view result:"
echo "   gcloud workflows executions wait ${EXECUTION_ID} --workflow=${WORKFLOW_NAME} --location=${REGION}"
echo ""
echo "3. View mock API logs:"
echo "   gcloud functions logs read ${FUNCTION_NAME} --region=${REGION} --limit=50"
echo ""
echo "4. View in Cloud Console:"
echo "   https://console.cloud.google.com/workflows/workflow/${REGION}/${WORKFLOW_NAME}/executions/${EXECUTION_ID}"
echo ""

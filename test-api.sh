#!/bin/bash

# API Testing Script
echo "=========================================="
echo "EDI Monitor API Testing"
echo "=========================================="

STACK_NAME="${STACK_NAME:-edi-monitor-stack}"
AWS_REGION="${AWS_REGION:-us-east-1}"

# Get API endpoint
API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query "Stacks[0].Outputs[?OutputKey=='APIEndpoint'].OutputValue" \
    --output text \
    --region "${AWS_REGION}" 2>/dev/null)

if [ -z "$API_ENDPOINT" ] || [ "$API_ENDPOINT" == "None" ]; then
    echo "Error: Could not retrieve API endpoint. Is the stack deployed?"
    exit 1
fi

echo "API Endpoint: $API_ENDPOINT"
echo ""

# Test health endpoint
echo "1. Testing /api/health endpoint..."
echo "-----------------------------------"
HEALTH_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" "${API_ENDPOINT}/api/health")
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
BODY=$(echo "$HEALTH_RESPONSE" | grep -v "HTTP_CODE")

echo "Response: $BODY"
echo "HTTP Code: $HTTP_CODE"

if [ "$HTTP_CODE" == "200" ]; then
    echo "✓ Health check passed"
else
    echo "✗ Health check failed"
fi
echo ""

# Test dashboard endpoint
echo "2. Testing /api/dashboard endpoint..."
echo "---------------------------------------"
DASHBOARD_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" "${API_ENDPOINT}/api/dashboard")
HTTP_CODE=$(echo "$DASHBOARD_RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
BODY=$(echo "$DASHBOARD_RESPONSE" | grep -v "HTTP_CODE")

echo "Response: $BODY" | head -c 500
echo "..."
echo "HTTP Code: $HTTP_CODE"

if [ "$HTTP_CODE" == "200" ]; then
    echo "✓ Dashboard endpoint working"
else
    echo "✗ Dashboard endpoint failed"
fi
echo ""

# Test EDI data endpoint
echo "3. Testing /api/edi-data endpoint..."
echo "--------------------------------------"
EDI_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" "${API_ENDPOINT}/api/edi-data")
HTTP_CODE=$(echo "$EDI_RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
BODY=$(echo "$EDI_RESPONSE" | grep -v "HTTP_CODE")

echo "Response: $BODY" | head -c 500
echo "..."
echo "HTTP Code: $HTTP_CODE"

if [ "$HTTP_CODE" == "200" ]; then
    echo "✓ EDI data endpoint working"
else
    echo "✗ EDI data endpoint failed"
fi
echo ""

# Test master data endpoint
echo "4. Testing /api/master-data endpoint..."
echo "-----------------------------------------"
MASTER_RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" "${API_ENDPOINT}/api/master-data")
HTTP_CODE=$(echo "$MASTER_RESPONSE" | grep "HTTP_CODE" | cut -d':' -f2)
BODY=$(echo "$MASTER_RESPONSE" | grep -v "HTTP_CODE")

echo "Response: $BODY" | head -c 500
echo "..."
echo "HTTP Code: $HTTP_CODE"

if [ "$HTTP_CODE" == "200" ]; then
    echo "✓ Master data endpoint working"
else
    echo "✗ Master data endpoint failed"
fi
echo ""

echo "=========================================="
echo "API Testing Complete!"
echo "=========================================="

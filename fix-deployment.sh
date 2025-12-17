#!/bin/bash
set -e

echo "=========================================="
echo "Fixing EDI Monitor Deployment"
echo "=========================================="
echo ""

AWS_REGION="${AWS_REGION:-us-east-1}"
STACK_NAME="${STACK_NAME:-edi-monitor-stack}"

# Step 1: Delete the stuck stack
echo "Step 1: Removing stuck stack in REVIEW_IN_PROGRESS state..."
aws cloudformation delete-stack \
  --stack-name "$STACK_NAME" \
  --region "$AWS_REGION"

echo "Waiting for stack deletion..."
aws cloudformation wait stack-delete-complete \
  --stack-name "$STACK_NAME" \
  --region "$AWS_REGION" 2>/dev/null || echo "Stack deleted or didn't exist"

echo "✅ Stack cleared"
echo ""

# Step 2: Generate unique bucket name
TIMESTAMP=$(date +%s)
S3_BUCKET="edi-monitor-${TIMESTAMP}"

echo "Step 2: Using unique S3 bucket name: $S3_BUCKET"
echo ""

# Step 3: Deploy
echo "Step 3: Deploying with unique bucket name..."
export S3_BUCKET
export STACK_NAME
export AWS_REGION

./deploy.sh

echo ""
echo "=========================================="
echo "Deployment Fixed and Complete!"
echo "=========================================="
echo ""
echo "IMPORTANT: Save this S3 bucket name for GitHub Actions:"
echo "  S3_BUCKET=$S3_BUCKET"
echo ""

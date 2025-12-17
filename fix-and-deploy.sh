#!/bin/bash
set -e

echo "=========================================="
echo "EDI Monitor - Fix and Deploy"
echo "=========================================="
echo ""

AWS_REGION="${AWS_REGION:-us-east-1}"
STACK_NAME="${STACK_NAME:-edi-monitor-stack}"
S3_BUCKET="${S3_BUCKET:-edi-monitor}"

# Check if stack exists and is in failed state
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$AWS_REGION" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || echo "DOES_NOT_EXIST")

if [ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ] || [ "$STACK_STATUS" == "CREATE_FAILED" ]; then
  echo "Stack is in failed state: $STACK_STATUS"
  echo "Deleting the stack..."

  aws cloudformation delete-stack \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION"

  echo "Waiting for stack deletion to complete..."
  aws cloudformation wait stack-delete-complete \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" || true

  echo "✅ Stack deleted successfully"
  echo ""
fi

# Check if S3 bucket name is available
echo "Checking S3 bucket availability..."
if aws s3 ls "s3://$S3_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
  # Bucket exists - check if we own it
  BUCKET_REGION=$(aws s3api get-bucket-location --bucket "$S3_BUCKET" --output text 2>/dev/null || echo "")

  if [ -z "$BUCKET_REGION" ] || [ "$BUCKET_REGION" == "None" ]; then
    BUCKET_REGION="us-east-1"
  fi

  echo "⚠️  Bucket s3://$S3_BUCKET already exists in region: $BUCKET_REGION"
  echo ""
  echo "Options:"
  echo "1. Use a different bucket name (recommended)"
  echo "2. Continue if you own this bucket"
  echo ""
  read -p "Enter 1 to use a unique name, or 2 to continue: " choice

  if [ "$choice" == "1" ]; then
    # Generate unique bucket name
    TIMESTAMP=$(date +%s)
    S3_BUCKET="edi-monitor-${TIMESTAMP}"
    echo "Using unique bucket name: $S3_BUCKET"
    export S3_BUCKET
  fi
fi

echo ""
echo "Deploying with configuration:"
echo "  Stack Name: $STACK_NAME"
echo "  S3 Bucket: $S3_BUCKET"
echo "  AWS Region: $AWS_REGION"
echo ""

# Run deployment
./deploy.sh

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="

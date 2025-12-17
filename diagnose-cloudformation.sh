#!/bin/bash
set -e

echo "=========================================="
echo "CloudFormation Diagnosis Script"
echo "=========================================="
echo ""

AWS_REGION="${AWS_REGION:-us-east-1}"
STACK_NAME="${STACK_NAME:-edi-monitor-stack}"
S3_BUCKET="${S3_BUCKET:-edi-monitor}"

echo "Configuration:"
echo "  AWS Region: $AWS_REGION"
echo "  Stack Name: $STACK_NAME"
echo "  S3 Bucket: $S3_BUCKET"
echo ""

# Check if stack exists
echo "1. Checking if CloudFormation stack exists..."
STACK_STATUS=$(aws cloudformation describe-stacks \
  --stack-name "$STACK_NAME" \
  --region "$AWS_REGION" \
  --query 'Stacks[0].StackStatus' \
  --output text 2>/dev/null || echo "DOES_NOT_EXIST")

if [ "$STACK_STATUS" != "DOES_NOT_EXIST" ]; then
  echo "   ⚠️  Stack exists with status: $STACK_STATUS"
  if [ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ] || [ "$STACK_STATUS" == "CREATE_FAILED" ]; then
    echo "   ❌ Stack is in failed state. Must delete before recreating."
    echo ""
    echo "   To delete the stack, run:"
    echo "   aws cloudformation delete-stack --stack-name $STACK_NAME --region $AWS_REGION"
  fi
else
  echo "   ✅ Stack does not exist"
fi
echo ""

# Check if S3 buckets exist
echo "2. Checking S3 bucket availability..."

# Check main bucket
echo "   Checking: s3://$S3_BUCKET"
if aws s3 ls "s3://$S3_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
  BUCKET_OWNER=$(aws s3api get-bucket-acl --bucket "$S3_BUCKET" --query 'Owner.DisplayName' --output text 2>/dev/null || echo "unknown")
  echo "   ⚠️  Bucket exists (Owner: $BUCKET_OWNER)"
  echo "   If you own this bucket, you can reuse it."
  echo "   If not, choose a different bucket name."
else
  echo "   ✅ Bucket available"
fi
echo ""

# Check frontend bucket
FRONTEND_BUCKET="${S3_BUCKET}-frontend"
echo "   Checking: s3://$FRONTEND_BUCKET"
if aws s3 ls "s3://$FRONTEND_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
  BUCKET_OWNER=$(aws s3api get-bucket-acl --bucket "$FRONTEND_BUCKET" --query 'Owner.DisplayName' --output text 2>/dev/null || echo "unknown")
  echo "   ⚠️  Bucket exists (Owner: $BUCKET_OWNER)"
else
  echo "   ✅ Bucket available"
fi
echo ""

# Check Lambda bucket
LAMBDA_BUCKET="${STACK_NAME}-lambda-${AWS_REGION}"
echo "   Checking: s3://$LAMBDA_BUCKET"
if aws s3 ls "s3://$LAMBDA_BUCKET" --region "$AWS_REGION" 2>/dev/null; then
  echo "   ℹ️  Bucket exists (this is OK, used for Lambda deployment)"
else
  echo "   ✅ Bucket does not exist (will be created)"
fi
echo ""

# Validate CloudFormation template
echo "3. Validating CloudFormation template..."
VALIDATION=$(aws cloudformation validate-template \
  --template-body file://cloudformation.yaml \
  --region "$AWS_REGION" 2>&1)

if [ $? -eq 0 ]; then
  echo "   ✅ Template is valid"
else
  echo "   ❌ Template validation failed:"
  echo "$VALIDATION"
fi
echo ""

# Check AWS credentials
echo "4. Checking AWS credentials and permissions..."
CALLER_IDENTITY=$(aws sts get-caller-identity --output json 2>/dev/null || echo "{}")
if [ "$CALLER_IDENTITY" != "{}" ]; then
  echo "   ✅ AWS credentials configured"
  echo "   Account: $(echo $CALLER_IDENTITY | jq -r .Account)"
  echo "   User/Role: $(echo $CALLER_IDENTITY | jq -r .Arn)"
else
  echo "   ❌ AWS credentials not configured"
fi
echo ""

echo "=========================================="
echo "Recommendations:"
echo "=========================================="
echo ""

if [ "$STACK_STATUS" == "ROLLBACK_COMPLETE" ] || [ "$STACK_STATUS" == "CREATE_FAILED" ]; then
  echo "1. Delete the failed stack:"
  echo "   aws cloudformation delete-stack --stack-name $STACK_NAME --region $AWS_REGION"
  echo ""
  echo "2. Wait for deletion to complete:"
  echo "   aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME --region $AWS_REGION"
  echo ""
  echo "3. Then retry deployment"
  echo ""
elif aws s3 ls "s3://$S3_BUCKET" --region "$AWS_REGION" 2>/dev/null && [ "$STACK_STATUS" == "DOES_NOT_EXIST" ]; then
  echo "1. S3 bucket already exists. Choose one of these options:"
  echo ""
  echo "   Option A: Use a unique bucket name"
  echo "   export S3_BUCKET=\"edi-monitor-$(date +%s)\""
  echo "   # Or use your company name:"
  echo "   export S3_BUCKET=\"yourcompany-edi-monitor\""
  echo ""
  echo "   Option B: If you own the bucket, verify and proceed"
  echo "   aws s3api get-bucket-location --bucket $S3_BUCKET"
  echo ""
else
  echo "✅ Ready to deploy! Run:"
  echo "   ./deploy.sh"
  echo ""
  echo "Or deploy with a unique bucket name:"
  echo "   S3_BUCKET=\"edi-monitor-$(date +%s)\" ./deploy.sh"
fi
echo ""

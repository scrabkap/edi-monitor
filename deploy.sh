#!/bin/bash
set -e

# EDI Monitor Deployment Script
echo "=========================================="
echo "EDI Monitor Deployment Script"
echo "=========================================="

# Configuration
STACK_NAME="${STACK_NAME:-edi-monitor-stack}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
S3_BUCKET="${S3_BUCKET:-edi-monitor}"

echo "Stack Name: $STACK_NAME"
echo "Environment: $ENVIRONMENT"
echo "AWS Region: $AWS_REGION"
echo "S3 Bucket: $S3_BUCKET"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check AWS credentials
echo "Checking AWS credentials..."
aws sts get-caller-identity > /dev/null 2>&1 || {
    echo "Error: AWS credentials not configured. Please run 'aws configure'."
    exit 1
}
echo "✓ AWS credentials configured"
echo ""

# Step 1: Package Lambda function
echo "Step 1: Packaging Lambda function..."
cd backend
pip install -r requirements.txt -t . --upgrade 2>/dev/null || true
zip -r ../lambda-function.zip . -x "*.pyc" -x "__pycache__/*" > /dev/null
cd ..
echo "✓ Lambda function packaged"
echo ""

# Step 2: Create S3 bucket for Lambda deployment if it doesn't exist
LAMBDA_BUCKET="${STACK_NAME}-lambda-${AWS_REGION}"
echo "Step 2: Creating S3 bucket for Lambda deployment..."
if aws s3 ls "s3://${LAMBDA_BUCKET}" 2>&1 | grep -q 'NoSuchBucket'; then
    aws s3 mb "s3://${LAMBDA_BUCKET}" --region "${AWS_REGION}" || {
        echo "Warning: Could not create Lambda bucket. It may already exist."
    }
    echo "✓ S3 bucket created: ${LAMBDA_BUCKET}"
else
    echo "✓ S3 bucket already exists: ${LAMBDA_BUCKET}"
fi
echo ""

# Step 3: Upload Lambda function to S3
echo "Step 3: Uploading Lambda function to S3..."
aws s3 cp lambda-function.zip "s3://${LAMBDA_BUCKET}/lambda-function.zip"
echo "✓ Lambda function uploaded"
echo ""

# Step 4: Deploy CloudFormation stack
echo "Step 4: Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file cloudformation.yaml \
    --stack-name "${STACK_NAME}" \
    --parameter-overrides \
        EnvironmentName="${ENVIRONMENT}" \
        S3BucketName="${S3_BUCKET}" \
    --capabilities CAPABILITY_IAM \
    --region "${AWS_REGION}" \
    --no-fail-on-empty-changeset

if [ $? -eq 0 ]; then
    echo "✓ CloudFormation stack deployed successfully"
else
    echo "✗ CloudFormation stack deployment failed"
    exit 1
fi
echo ""

# Step 5: Get stack outputs
echo "Step 5: Retrieving stack outputs..."
API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query "Stacks[0].Outputs[?OutputKey=='APIEndpoint'].OutputValue" \
    --output text \
    --region "${AWS_REGION}")

FRONTEND_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query "Stacks[0].Outputs[?OutputKey=='FrontendBucketName'].OutputValue" \
    --output text \
    --region "${AWS_REGION}")

FRONTEND_URL=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query "Stacks[0].Outputs[?OutputKey=='FrontendURL'].OutputValue" \
    --output text \
    --region "${AWS_REGION}")

echo "API Endpoint: $API_ENDPOINT"
echo "Frontend Bucket: $FRONTEND_BUCKET"
echo "Frontend URL: https://$FRONTEND_URL"
echo ""

# Step 6: Update Component.js with API endpoint
echo "Step 6: Updating frontend configuration..."
sed -i.bak "s|https://your-api-id.execute-api.region.amazonaws.com/dev|${API_ENDPOINT}|g" webapp/Component.js
rm -f webapp/Component.js.bak
echo "✓ Frontend configuration updated"
echo ""

# Step 7: Build frontend
echo "Step 7: Building frontend..."
if command -v npm &> /dev/null; then
    npm install > /dev/null 2>&1 || echo "Warning: npm install had issues"
    npm run build > /dev/null 2>&1 || echo "Warning: Could not build with UI5 CLI, deploying source"
    if [ -d "dist" ]; then
        DEPLOY_DIR="dist"
    else
        DEPLOY_DIR="webapp"
    fi
else
    echo "Warning: npm not found, deploying source files"
    DEPLOY_DIR="webapp"
fi
echo "✓ Frontend build completed (deploying from: $DEPLOY_DIR)"
echo ""

# Step 8: Deploy frontend to S3
echo "Step 8: Deploying frontend to S3..."
aws s3 sync "${DEPLOY_DIR}" "s3://${FRONTEND_BUCKET}" \
    --delete \
    --region "${AWS_REGION}" \
    --cache-control "max-age=3600"

if [ $? -eq 0 ]; then
    echo "✓ Frontend deployed successfully"
else
    echo "✗ Frontend deployment failed"
    exit 1
fi
echo ""

# Step 9: Invalidate CloudFront cache (if needed)
echo "Step 9: CloudFront cache invalidation..."
DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
    --stack-name "${STACK_NAME}" \
    --query "Stacks[0].Outputs[?OutputKey=='FrontendDistributionId'].OutputValue" \
    --output text \
    --region "${AWS_REGION}" 2>/dev/null || echo "")

if [ -n "$DISTRIBUTION_ID" ] && [ "$DISTRIBUTION_ID" != "None" ]; then
    aws cloudfront create-invalidation \
        --distribution-id "$DISTRIBUTION_ID" \
        --paths "/*" > /dev/null 2>&1 || echo "Warning: Could not invalidate CloudFront cache"
    echo "✓ CloudFront cache invalidated"
else
    echo "⚠ No CloudFront distribution found, skipping cache invalidation"
fi
echo ""

# Cleanup
rm -f lambda-function.zip

echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Access your application at:"
echo "Frontend: https://$FRONTEND_URL"
echo "API: $API_ENDPOINT"
echo ""
echo "Next steps:"
echo "1. Upload your master data files to: s3://${S3_BUCKET}/master-data/"
echo "2. Upload your EDI mock data to: s3://${S3_BUCKET}/edi-mockdata/"
echo "3. Test the API endpoint: ${API_ENDPOINT}/api/health"
echo ""

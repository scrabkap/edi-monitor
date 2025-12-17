#!/bin/bash
set -e

echo "Simple Frontend Deployment to CloudFront"
echo "=========================================="

REGION="eu-west-1"
TIMESTAMP=$(date +%s)
BUCKET_NAME="edi-monitor-frontend-${TIMESTAMP}"

echo "Creating S3 bucket: $BUCKET_NAME"
aws s3 mb "s3://${BUCKET_NAME}" --region $REGION

echo "Configuring bucket for website hosting"
aws s3 website "s3://${BUCKET_NAME}" \
  --index-document index.html \
  --error-document index.html

echo "Setting bucket policy for public access"
aws s3api put-bucket-policy --bucket "${BUCKET_NAME}" --policy "{
  \"Version\": \"2012-10-17\",
  \"Statement\": [{
    \"Sid\": \"PublicReadGetObject\",
    \"Effect\": \"Allow\",
    \"Principal\": \"*\",
    \"Action\": \"s3:GetObject\",
    \"Resource\": \"arn:aws:s3:::${BUCKET_NAME}/*\"
  }]
}"

echo "Uploading frontend files"
aws s3 sync webapp/ "s3://${BUCKET_NAME}/" --region $REGION

WEBSITE_URL="${BUCKET_NAME}.s3-website-${REGION}.amazonaws.com"

echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "S3 Website URL: http://${WEBSITE_URL}"
echo "Bucket: ${BUCKET_NAME}"
echo ""
echo "Test it now: http://${WEBSITE_URL}"
echo ""
echo "Optional: Create CloudFront distribution manually in AWS Console"
echo "Origin: ${WEBSITE_URL}"
echo ""

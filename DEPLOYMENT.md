# EDI Monitor Deployment Guide

This guide provides step-by-step instructions for deploying the EDI Monitor application to AWS.

## Prerequisites

Before deploying, ensure you have:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```
3. **Node.js** (v18.x or later) - for building the frontend
4. **Python 3.11** - for Lambda functions
5. **Git** - for version control

## Quick Start Deployment

### 1. Clone and Setup

```bash
git clone <repository-url>
cd edi-monitor
```

### 2. Configure Environment

Set your AWS region and bucket name (optional):

```bash
export AWS_REGION=us-east-1
export S3_BUCKET=edi-monitor
export STACK_NAME=edi-monitor-stack
export ENVIRONMENT=dev
```

### 3. Deploy Infrastructure and Application

Run the deployment script:

```bash
./deploy.sh
```

This script will:
- Package the Lambda function
- Create necessary S3 buckets
- Deploy the CloudFormation stack
- Build and deploy the frontend
- Configure the application

### 4. Upload Sample Data

Upload the sample data files to S3:

```bash
./setup-sample-data.sh
```

Or manually upload your data:

```bash
# Upload master data
aws s3 cp your-data/KNA1.csv s3://edi-monitor/master-data/KNA1.csv
aws s3 cp your-data/LFA1.csv s3://edi-monitor/master-data/LFA1.csv
aws s3 cp your-data/MAKT.csv s3://edi-monitor/master-data/MAKT.csv

# Upload EDI mock data
aws s3 cp your-data/YLO_SNXT_EDI_H.csv s3://edi-monitor/edi-mockdata/YLO_SNXT_EDI_H.csv
aws s3 cp your-data/YLO_SNXT_EDI_I.csv s3://edi-monitor/edi-mockdata/YLO_SNXT_EDI_I.csv
```

### 5. Access the Application

After deployment completes, you'll see the URLs:

```
Frontend: https://xxxxx.cloudfront.net
API: https://xxxxx.execute-api.us-east-1.amazonaws.com/dev
```

Open the Frontend URL in your browser to access the EDI Monitor.

## Manual Deployment Steps

If you prefer to deploy manually:

### Step 1: Create S3 Buckets

```bash
aws s3 mb s3://edi-monitor
aws s3 mb s3://edi-monitor-frontend
```

### Step 2: Package Lambda Function

```bash
cd backend
pip install -r requirements.txt -t .
zip -r ../lambda-function.zip .
cd ..
```

### Step 3: Deploy CloudFormation Stack

```bash
aws cloudformation create-stack \
  --stack-name edi-monitor-stack \
  --template-body file://cloudformation.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=dev \
               ParameterKey=S3BucketName,ParameterValue=edi-monitor \
  --capabilities CAPABILITY_IAM
```

Wait for stack creation:

```bash
aws cloudformation wait stack-create-complete \
  --stack-name edi-monitor-stack
```

### Step 4: Update Lambda Function Code

```bash
FUNCTION_NAME=$(aws cloudformation describe-stacks \
  --stack-name edi-monitor-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionName`].OutputValue' \
  --output text)

aws lambda update-function-code \
  --function-name $FUNCTION_NAME \
  --zip-file fileb://lambda-function.zip
```

### Step 5: Build and Deploy Frontend

```bash
npm install
npm run build

BUCKET=$(aws cloudformation describe-stacks \
  --stack-name edi-monitor-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text)

aws s3 sync dist/ s3://$BUCKET/
```

## Testing the Deployment

### 1. Test API Health

```bash
API_URL=$(aws cloudformation describe-stacks \
  --stack-name edi-monitor-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`APIEndpoint`].OutputValue' \
  --output text)

curl $API_URL/api/health
```

Expected response:
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00"
}
```

### 2. Test EDI Data Endpoint

```bash
curl $API_URL/api/edi-data
```

### 3. Test Dashboard Endpoint

```bash
curl $API_URL/api/dashboard
```

### 4. Access Frontend

Open the CloudFront URL in your browser and verify:
- Dashboard loads with statistics
- EDI documents list shows data
- Detail view displays document information
- Hebrew text displays correctly

## Data Format Requirements

### Master Data Files

**KNA1.csv** (Store Master Data):
```csv
GP,Name,City,Region
1001,Store Name,City,Region
```

- Column GP: EDI Store Number (joins with YLO_SNXT_EDI_H column D)

**LFA1.csv** (Vendor Master Data):
```csv
EN,Name,City,Type
V001,Vendor Name,City,Type
```

- Column EN: EDI Delivery (joins with YLO_SNXT_EDI_H column B)

**MAKT.csv** (Material Description):
```csv
Material,Description
7290000001234,Product Description in Hebrew
```

- Column Material: Barcode (joins with YLO_SNXT_EDI_I column B)

### EDI Data Files

**YLO_SNXT_EDI_H.csv** (Header):
```csv
A,B,C,D,E,F,G,H,Timestamp
DOC001,V001,2024-01-15,1001,INV,123,1500.00,104,2024-01-15T08:30:00
```

- Column A: Document Number
- Column B: EDI Delivery (joins with LFA1.EN)
- Column D: EDI Store Number (joins with KNA1.GP)
- Column H: Error Code (104 = Critical, 114 = Warning)

**YLO_SNXT_EDI_I.csv** (Items):
```csv
A,B,C,D,E,F,G,H
DOC001,7290000001234,50,125.00,EA,1,,104
```

- Column A: Document Number (links to header)
- Column B: Barcode (joins with MAKT.Material)
- Column C: Quantity
- Column H: Error Code

## Updating the Application

### Update Lambda Function

```bash
cd backend
# Make your changes
zip -r ../lambda-function.zip .
cd ..

aws lambda update-function-code \
  --function-name $(aws cloudformation describe-stacks \
    --stack-name edi-monitor-stack \
    --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionName`].OutputValue' \
    --output text) \
  --zip-file fileb://lambda-function.zip
```

### Update Frontend

```bash
npm run build

aws s3 sync dist/ s3://$(aws cloudformation describe-stacks \
  --stack-name edi-monitor-stack \
  --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
  --output text)/

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
  --distribution-id $(aws cloudformation describe-stacks \
    --stack-name edi-monitor-stack \
    --query 'Stacks[0].Outputs[?OutputKey==`FrontendDistributionId`].OutputValue' \
    --output text) \
  --paths "/*"
```

### Update Infrastructure

```bash
aws cloudformation update-stack \
  --stack-name edi-monitor-stack \
  --template-body file://cloudformation.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=dev \
               ParameterKey=S3BucketName,ParameterValue=edi-monitor \
  --capabilities CAPABILITY_IAM
```

## Monitoring and Troubleshooting

### View Lambda Logs

```bash
aws logs tail /aws/lambda/dev-edi-processor --follow
```

### View CloudFormation Events

```bash
aws cloudformation describe-stack-events \
  --stack-name edi-monitor-stack \
  --max-items 10
```

### Check API Gateway Logs

Enable CloudWatch Logs in API Gateway settings, then:

```bash
aws logs tail /aws/apigateway/edi-monitor-api --follow
```

### Common Issues

1. **Lambda timeout**: Increase timeout in cloudformation.yaml (currently 60s)
2. **CORS errors**: Check API Gateway CORS configuration
3. **S3 access denied**: Verify Lambda IAM role has S3 read permissions
4. **Frontend not loading**: Check CloudFront distribution and S3 bucket policy

## Cleanup

To remove all resources:

```bash
# Empty S3 buckets first
aws s3 rm s3://edi-monitor --recursive
aws s3 rm s3://edi-monitor-frontend --recursive

# Delete CloudFormation stack
aws cloudformation delete-stack --stack-name edi-monitor-stack

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name edi-monitor-stack
```

## Security Considerations

1. **API Authentication**: Consider adding API Gateway authorization
2. **S3 Bucket Policies**: Review and restrict as needed
3. **Lambda Environment Variables**: Use AWS Secrets Manager for sensitive data
4. **CloudFront**: Configure custom SSL certificate for production
5. **IAM Roles**: Follow principle of least privilege

## Performance Optimization

1. **Lambda**: Adjust memory allocation based on data size
2. **CloudFront**: Configure caching policies
3. **S3**: Use lifecycle policies for old data
4. **API Gateway**: Enable caching if needed

## Support

For issues or questions, please refer to:
- AWS Documentation
- OpenUI5 Documentation
- Project README

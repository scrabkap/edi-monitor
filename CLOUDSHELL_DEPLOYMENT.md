# AWS CloudShell Deployment Guide

Deploy EDI Monitor manually using AWS CloudShell, then use GitHub Actions for updates.

## Step 1: Open AWS CloudShell

1. Log in to AWS Console
2. Click the CloudShell icon (>_) in the top navigation bar
3. Wait for CloudShell to initialize

## Step 2: Clone Repository

```bash
# Clone your repository
git clone https://github.com/scrabkap/edi-monitor.git
cd edi-monitor
```

## Step 3: Set Configuration Variables

```bash
# IMPORTANT: Choose a globally unique bucket name
# Option 1: Use timestamp
export S3_BUCKET="edi-monitor-$(date +%s)"

# Option 2: Use your company/username
export S3_BUCKET="yourcompany-edi-monitor"

# Other settings
export STACK_NAME="edi-monitor-stack"
export AWS_REGION="us-east-1"  # Change if needed
export ENVIRONMENT="dev"

echo "Configuration:"
echo "  S3_BUCKET: $S3_BUCKET"
echo "  STACK_NAME: $STACK_NAME"
echo "  AWS_REGION: $AWS_REGION"
```

## Step 4: Package Lambda Function

```bash
cd backend
pip install -r requirements.txt -t . --upgrade
zip -r ../lambda-function.zip . -x "*.pyc" -x "__pycache__/*"
cd ..
```

## Step 5: Create Lambda Deployment Bucket

```bash
LAMBDA_BUCKET="${STACK_NAME}-lambda-${AWS_REGION}"
aws s3 mb "s3://${LAMBDA_BUCKET}" --region "${AWS_REGION}" 2>/dev/null || \
  echo "Bucket already exists, continuing..."

aws s3 cp lambda-function.zip "s3://${LAMBDA_BUCKET}/"
```

## Step 6: Deploy CloudFormation Stack

```bash
aws cloudformation deploy \
  --template-file cloudformation.yaml \
  --stack-name "${STACK_NAME}" \
  --parameter-overrides \
    EnvironmentName="${ENVIRONMENT}" \
    S3BucketName="${S3_BUCKET}" \
  --capabilities CAPABILITY_IAM \
  --region "${AWS_REGION}" \
  --no-fail-on-empty-changeset
```

**This will take 5-10 minutes.** You'll see progress updates.

## Step 7: Get Stack Outputs

```bash
# Get all outputs
aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --query 'Stacks[0].Outputs' \
  --region "${AWS_REGION}" \
  --output table

# Save to variables
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
```

## Step 8: Install Node.js (if needed)

```bash
# Check if Node.js is available
node --version || {
  echo "Installing Node.js..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  nvm install 18
}
```

## Step 9: Build and Deploy Frontend

```bash
# Install dependencies
npm install

# Update API endpoint in frontend
sed -i "s|https://your-api-id.execute-api.region.amazonaws.com/dev|${API_ENDPOINT}|g" webapp/Component.js

# Try to build (optional - source files work too)
npm run build 2>/dev/null && DEPLOY_DIR="dist" || DEPLOY_DIR="webapp"

# Deploy to S3
aws s3 sync "${DEPLOY_DIR}" "s3://${FRONTEND_BUCKET}" \
  --delete \
  --region "${AWS_REGION}" \
  --cache-control "max-age=3600"

echo "✅ Frontend deployed!"
```

## Step 10: Upload Sample Data

```bash
# Create sample data directory
mkdir -p sample-data/master-data
mkdir -p sample-data/edi-mockdata

# Create KNA1 - Store master data
cat > sample-data/master-data/KNA1.csv << 'EOF'
GP,Name,City,Region
1001,Store Tel Aviv Central,Tel Aviv,Central
1002,Store Jerusalem West,Jerusalem,Jerusalem
1003,Store Haifa North,Haifa,North
1004,Store Beer Sheva South,Beer Sheva,South
1005,Store Netanya Coast,Netanya,Central
EOF

# Create LFA1 - Vendor master data
cat > sample-data/master-data/LFA1.csv << 'EOF'
EN,Name,City,Type
V001,Supplier Alpha Ltd,Tel Aviv,Food
V002,Supplier Beta Industries,Haifa,Electronics
V003,Supplier Gamma Corp,Jerusalem,Textiles
V004,Supplier Delta Trading,Ashdod,General
V005,Supplier Epsilon Dist,Rishon,Food
EOF

# Create MAKT - Material descriptions
cat > sample-data/master-data/MAKT.csv << 'EOF'
Material,Description
7290000001234,חלב 3% 1 ליטר
7290000001241,לחם פרוס שחור
7290000001258,גבינה צהובה פרוסה
7290000001265,יוגורט תותים 150 גרם
7290000001272,ביצים גודל L 12 יחידות
7290000001289,עגבניות שרי 250 גרם
7290000001296,מלפפון חמוץ צנצנת
7290000001302,שמן זית 500 מ"ל
7290000001319,סוכר לבן 1 ק"ג
7290000001326,קמח לבן 1 ק"ג
EOF

# Create YLO_SNXT_EDI_H - Header
cat > sample-data/edi-mockdata/YLO_SNXT_EDI_H.csv << 'EOF'
A,B,C,D,E,F,G,H,Timestamp
DOC001,V001,2024-01-15,1001,INV,123,1500.00,104,2024-01-15T08:30:00
DOC002,V002,2024-01-15,1002,INV,124,2300.50,,2024-01-15T09:15:00
DOC003,V003,2024-01-15,1003,INV,125,1800.00,114,2024-01-15T10:00:00
DOC004,V004,2024-01-15,1004,INV,126,3200.00,,2024-01-15T10:45:00
DOC005,V005,2024-01-15,1005,INV,127,2100.00,104,2024-01-15T11:30:00
DOC006,V001,2024-01-15,1001,INV,128,1750.00,114,2024-01-15T12:15:00
DOC007,V002,2024-01-15,1002,INV,129,2900.00,,2024-01-15T13:00:00
DOC008,V003,2024-01-15,1003,INV,130,1950.00,104,2024-01-15T13:45:00
DOC009,V004,2024-01-15,1004,INV,131,2650.00,,2024-01-15T14:30:00
DOC010,V005,2024-01-15,1005,INV,132,3100.00,114,2024-01-15T15:15:00
EOF

# Create YLO_SNXT_EDI_I - Items
cat > sample-data/edi-mockdata/YLO_SNXT_EDI_I.csv << 'EOF'
A,B,C,D,E,F,G,H
DOC001,7290000001234,50,125.00,EA,1,,104
DOC001,7290000001241,30,90.00,EA,2,,
DOC001,7290000001258,25,150.00,EA,3,,
DOC002,7290000001265,100,200.00,EA,1,,
DOC002,7290000001272,40,180.00,EA,2,,
DOC003,7290000001289,60,120.00,EA,1,,114
DOC003,7290000001296,35,140.00,EA,2,,
DOC004,7290000001302,45,225.00,EA,1,,
DOC004,7290000001319,80,160.00,EA,2,,
DOC005,7290000001326,55,220.00,EA,1,,104
DOC005,7290000001234,40,100.00,EA,2,,104
DOC006,7290000001241,70,210.00,EA,1,,114
DOC006,7290000001258,30,180.00,EA,2,,
DOC007,7290000001265,90,270.00,EA,1,,
DOC007,7290000001272,50,225.00,EA,2,,
DOC008,7290000001289,65,195.00,EA,1,,104
DOC008,7290000001296,45,180.00,EA,2,,
DOC009,7290000001302,75,300.00,EA,1,,
DOC009,7290000001319,100,200.00,EA,2,,
DOC010,7290000001326,85,340.00,EA,1,,114
DOC010,7290000001234,60,150.00,EA,2,,
EOF

# Upload to S3
aws s3 cp sample-data/master-data/ "s3://${S3_BUCKET}/master-data/" --recursive
aws s3 cp sample-data/edi-mockdata/ "s3://${S3_BUCKET}/edi-mockdata/" --recursive

echo "✅ Sample data uploaded!"
```

## Step 11: Test Deployment

```bash
# Test API health
curl "${API_ENDPOINT}/api/health"

# Should return: {"status": "healthy", ...}

# Test dashboard
curl "${API_ENDPOINT}/api/dashboard"

# View frontend URL
echo ""
echo "=========================================="
echo "Deployment Complete!"
echo "=========================================="
echo ""
echo "Frontend URL: https://${FRONTEND_URL}"
echo "API Endpoint: ${API_ENDPOINT}"
echo ""
echo "Open the Frontend URL in your browser!"
```

## Step 12: Save Configuration for GitHub Actions

**Important:** Save these values to update GitHub Secrets:

```bash
# Display values to save
echo ""
echo "=========================================="
echo "GitHub Actions Configuration"
echo "=========================================="
echo ""
echo "Update these GitHub Secrets:"
echo "  AWS_REGION=$AWS_REGION"
echo "  S3_BUCKET=$S3_BUCKET"
echo "  STACK_NAME=$STACK_NAME"
echo ""
echo "Already configured (don't change):"
echo "  AWS_ACCESS_KEY_ID"
echo "  AWS_SECRET_ACCESS_KEY"
echo ""
```

Go to GitHub → Settings → Secrets → Actions and update:
- `S3_BUCKET` with your actual bucket name
- `STACK_NAME` with your stack name (usually keep default)
- `AWS_REGION` with your region (usually keep default)

## Troubleshooting

### If deployment fails:

**Check for existing failed stack:**
```bash
aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}"
```

**Delete failed stack:**
```bash
aws cloudformation delete-stack \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}"

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}"
```

**Then retry from Step 6.**

### If bucket name is taken:

```bash
# Generate new unique name
export S3_BUCKET="edi-monitor-$(date +%s)"
echo "New bucket name: $S3_BUCKET"

# Retry from Step 6
```

### View detailed errors:

```bash
aws cloudformation describe-stack-events \
  --stack-name "${STACK_NAME}" \
  --region "${AWS_REGION}" \
  --max-items 20
```

## After Manual Deployment

Once deployed manually, GitHub Actions will work for updates:

**What GitHub Actions will do:**
- ✅ Update Lambda function code
- ✅ Update frontend files
- ✅ Invalidate CloudFront cache
- ❌ Won't recreate the stack (already exists)

**Future deployments:**
```bash
# Just push to trigger deployment
git push origin main
```

## One-Line Quick Deploy

Copy everything and paste into CloudShell:

```bash
export S3_BUCKET="edi-monitor-$(date +%s)" && \
export STACK_NAME="edi-monitor-stack" && \
export AWS_REGION="us-east-1" && \
export ENVIRONMENT="dev" && \
git clone https://github.com/scrabkap/edi-monitor.git && \
cd edi-monitor && \
cd backend && pip install -r requirements.txt -t . --upgrade && zip -r ../lambda-function.zip . && cd .. && \
aws s3 mb "s3://${STACK_NAME}-lambda-${AWS_REGION}" 2>/dev/null || true && \
aws s3 cp lambda-function.zip "s3://${STACK_NAME}-lambda-${AWS_REGION}/" && \
aws cloudformation deploy --template-file cloudformation.yaml --stack-name "${STACK_NAME}" --parameter-overrides EnvironmentName="${ENVIRONMENT}" S3BucketName="${S3_BUCKET}" --capabilities CAPABILITY_IAM --region "${AWS_REGION}" --no-fail-on-empty-changeset && \
echo "Deployment complete! Getting outputs..." && \
aws cloudformation describe-stacks --stack-name "${STACK_NAME}" --query 'Stacks[0].Outputs' --region "${AWS_REGION}" --output table
```

## Summary

1. ✅ CloudShell deployment bypasses GitHub Actions issues
2. ✅ You control bucket names (avoid conflicts)
3. ✅ Once deployed, GitHub Actions works for updates
4. ✅ Full control over AWS resources

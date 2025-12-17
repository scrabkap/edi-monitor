# GitHub Actions Setup Guide

This guide explains how to set up and use GitHub Actions for automated deployment of the EDI Monitor application to AWS.

## Overview

Three GitHub Actions workflows are configured:

1. **Deploy to AWS** (`deploy.yml`) - Automated deployment on push to main or manual trigger
2. **Validate PR** (`validate-pr.yml`) - Validation checks for pull requests
3. **Upload Sample Data** (`upload-sample-data.yml`) - Manual workflow to upload sample data

## Prerequisites

### 1. AWS Account Setup

You need an AWS account with appropriate permissions to create:
- CloudFormation stacks
- Lambda functions
- S3 buckets
- API Gateway
- CloudFront distributions
- IAM roles

### 2. AWS IAM User for GitHub Actions

Create an IAM user with programmatic access and attach the following policies:

**Minimum Required Permissions:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudformation:*",
        "lambda:*",
        "apigateway:*",
        "s3:*",
        "cloudfront:*",
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:PassRole",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "logs:*"
      ],
      "Resource": "*"
    }
  ]
}
```

**Note:** For production, you should restrict these permissions to specific resources.

### 3. Configure GitHub Secrets

In your GitHub repository, go to **Settings → Secrets and variables → Actions** and add the following secrets:

#### Required Secrets

| Secret Name | Description | Example Value |
|------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | AWS access key ID | `AKIAIOSFODNN7EXAMPLE` |
| `AWS_SECRET_ACCESS_KEY` | AWS secret access key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` |

#### Optional Secrets (with defaults)

| Secret Name | Description | Default Value |
|------------|-------------|---------------|
| `AWS_REGION` | AWS region to deploy to | `us-east-1` |
| `STACK_NAME` | CloudFormation stack name | `edi-monitor-stack` |
| `S3_BUCKET` | S3 bucket name for EDI data | `edi-monitor` |

### 4. Configure GitHub Environments (Optional)

For better control, you can create environments (dev, staging, prod):

1. Go to **Settings → Environments**
2. Create environments: `dev`, `staging`, `prod`
3. Add environment-specific secrets if needed
4. Configure protection rules (e.g., require approval for prod)

## Workflows

### 1. Deploy to AWS

**File:** `.github/workflows/deploy.yml`

**Triggers:**
- Push to `main` branch
- Push to any `claude/**` branch
- Manual workflow dispatch

**What it does:**
1. Checks out the code
2. Configures AWS credentials
3. Sets up Python and Node.js
4. Installs dependencies
5. Builds the frontend
6. Packages the Lambda function
7. Deploys CloudFormation stack
8. Uploads frontend to S3
9. Invalidates CloudFront cache
10. Provides deployment summary

**Usage:**

**Automatic Deployment:**
```bash
git push origin main
# or
git push origin claude/your-branch-name
```

**Manual Deployment:**
1. Go to **Actions** tab in GitHub
2. Select **Deploy EDI Monitor to AWS**
3. Click **Run workflow**
4. Select environment (dev/staging/prod)
5. Click **Run workflow**

### 2. Validate PR

**File:** `.github/workflows/validate-pr.yml`

**Triggers:**
- Pull request to `main` branch
- Only when relevant files change

**What it does:**
1. Installs frontend dependencies
2. Lints frontend code (if configured)
3. Builds frontend
4. Validates Python syntax
5. Installs backend dependencies
6. Validates CloudFormation template

**Usage:**
Automatically runs when you create a pull request.

### 3. Upload Sample Data

**File:** `.github/workflows/upload-sample-data.yml`

**Triggers:**
- Manual workflow dispatch only

**What it does:**
1. Creates sample CSV files
2. Uploads master data to S3
3. Uploads EDI mock data to S3

**Usage:**
1. Go to **Actions** tab in GitHub
2. Select **Upload Sample Data**
3. Click **Run workflow**
4. Enter S3 bucket name (default: `edi-monitor`)
5. Click **Run workflow**

## Step-by-Step Setup

### Step 1: Configure AWS Credentials

1. Create IAM user in AWS Console
2. Attach necessary policies
3. Generate access keys
4. Add to GitHub Secrets

```bash
# Test AWS credentials locally first
aws sts get-caller-identity
```

### Step 2: Push Code to GitHub

```bash
git add .
git commit -m "Add GitHub Actions workflows"
git push origin main
```

### Step 3: Monitor Deployment

1. Go to **Actions** tab in GitHub
2. Watch the workflow execution
3. Check for any errors
4. Review the deployment summary

### Step 4: Upload Sample Data

1. Run the "Upload Sample Data" workflow
2. Or use the AWS CLI:
   ```bash
   ./setup-sample-data.sh
   ```

### Step 5: Verify Deployment

1. Check the workflow summary for URLs
2. Open the CloudFront URL in your browser
3. Test the API endpoints
4. Verify data displays correctly

## Workflow Configuration

### Environment Variables

You can customize the deployment by setting environment variables in the workflow file:

```yaml
env:
  AWS_REGION: 'us-east-1'          # AWS region
  STACK_NAME: 'edi-monitor-stack'   # CloudFormation stack name
  S3_BUCKET: 'edi-monitor'          # S3 bucket for data
```

### Customizing Triggers

**Deploy on specific branches:**
```yaml
on:
  push:
    branches:
      - main
      - develop
      - 'release/**'
```

**Deploy on tags:**
```yaml
on:
  push:
    tags:
      - 'v*.*.*'
```

**Schedule deployments:**
```yaml
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC
```

## Troubleshooting

### Common Issues

#### 1. AWS Credentials Error

**Error:** `Unable to locate credentials`

**Solution:**
- Verify `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` are set in GitHub Secrets
- Check the IAM user has programmatic access enabled
- Ensure the secrets are accessible to the workflow

#### 2. CloudFormation Stack Already Exists

**Error:** `Stack already exists`

**Solution:**
- The workflow uses `cloudformation deploy` which updates existing stacks
- If you need to recreate, delete the stack first:
  ```bash
  aws cloudformation delete-stack --stack-name edi-monitor-stack
  ```

#### 3. S3 Bucket Name Conflict

**Error:** `BucketAlreadyExists`

**Solution:**
- S3 bucket names are globally unique
- Change the `S3_BUCKET` secret to a unique name
- Update the workflow environment variables

#### 4. Lambda Deployment Package Too Large

**Error:** `Unzipped size must be smaller than...`

**Solution:**
- The workflow automatically packages Lambda efficiently
- If issues persist, reduce dependencies in `backend/requirements.txt`

#### 5. Frontend Build Fails

**Error:** `npm run build failed`

**Solution:**
- Check `package.json` has the correct build script
- The workflow falls back to deploying source files if build fails
- Review build logs in the Actions tab

### Debug Mode

Enable debug logging in GitHub Actions:

1. Go to **Settings → Secrets and variables → Actions**
2. Add a secret: `ACTIONS_STEP_DEBUG` = `true`
3. Re-run the workflow

### Viewing Logs

1. Go to **Actions** tab
2. Click on the workflow run
3. Click on the job name
4. Expand individual steps to see logs

## Security Best Practices

### 1. Restrict AWS Permissions

Create a dedicated IAM user with minimum required permissions:

```bash
# Example: Create a deployment-specific policy
aws iam create-policy \
  --policy-name EDIMonitorDeployment \
  --policy-document file://deployment-policy.json
```

### 2. Use GitHub Environments

Configure environment protection rules:
- Require reviewers for production
- Set branch restrictions
- Add wait timer

### 3. Rotate AWS Credentials

Regularly rotate your AWS access keys:
1. Create new keys in AWS Console
2. Update GitHub Secrets
3. Delete old keys

### 4. Monitor CloudTrail

Enable AWS CloudTrail to audit all API calls:
```bash
aws cloudtrail create-trail \
  --name edi-monitor-trail \
  --s3-bucket-name my-cloudtrail-bucket
```

### 5. Use OIDC (Recommended)

Instead of long-lived credentials, use GitHub's OIDC provider:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
    aws-region: us-east-1
```

[Setup guide for OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

## Advanced Configuration

### Multi-Environment Deployment

Create separate workflows for each environment:

**.github/workflows/deploy-dev.yml:**
```yaml
name: Deploy to Development
on:
  push:
    branches: [develop]
env:
  STACK_NAME: edi-monitor-dev
  S3_BUCKET: edi-monitor-dev
```

**.github/workflows/deploy-prod.yml:**
```yaml
name: Deploy to Production
on:
  push:
    tags: ['v*']
env:
  STACK_NAME: edi-monitor-prod
  S3_BUCKET: edi-monitor-prod
```

### Deployment Notifications

Add Slack notifications:

```yaml
- name: Notify Slack
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: 'EDI Monitor deployment completed!'
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
  if: always()
```

### Rollback Strategy

Create a rollback workflow:

**.github/workflows/rollback.yml:**
```yaml
name: Rollback Deployment
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to rollback to'
        required: true
jobs:
  rollback:
    runs-on: ubuntu-latest
    steps:
      - name: Rollback Lambda
        run: |
          aws lambda update-function-code \
            --function-name edi-processor \
            --s3-bucket lambda-versions \
            --s3-key "lambda-${{ github.event.inputs.version }}.zip"
```

## Cost Optimization

### 1. Clean Up Old Deployments

Create a cleanup workflow:

```yaml
name: Cleanup Old Resources
on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - name: Delete old Lambda versions
        run: |
          aws lambda list-versions-by-function \
            --function-name edi-processor \
            --query 'Versions[?Version!=`$LATEST`].[Version]' \
            --output text | \
          while read version; do
            aws lambda delete-function --function-name edi-processor:$version
          done
```

### 2. Monitor Costs

Set up AWS Budget alerts:

```bash
aws budgets create-budget \
  --account-id 123456789012 \
  --budget file://budget.json
```

## Monitoring and Alerts

### CloudWatch Integration

The workflows create CloudWatch log groups automatically. View logs:

```bash
aws logs tail /aws/lambda/dev-edi-processor --follow
```

### GitHub Actions Status Badge

Add to your README.md:

```markdown
[![Deploy Status](https://github.com/your-username/edi-monitor/workflows/Deploy%20EDI%20Monitor%20to%20AWS/badge.svg)](https://github.com/your-username/edi-monitor/actions)
```

## Support

For issues with:
- GitHub Actions setup: Check this guide
- AWS deployment: See DEPLOYMENT.md
- Application code: See README.md and PROJECT_OVERVIEW.md

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [Configure AWS Credentials Action](https://github.com/aws-actions/configure-aws-credentials)

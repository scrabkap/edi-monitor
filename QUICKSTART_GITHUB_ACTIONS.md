# Quick Start: Deploy with GitHub Actions

Get your EDI Monitor running on AWS in 5 minutes using GitHub Actions!

## Step 1: Configure GitHub Secrets (2 minutes)

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** and add these two secrets:

| Name | Value | Where to find |
|------|-------|---------------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key | AWS Console → IAM → Users → Security credentials |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key | AWS Console → IAM → Users → Security credentials |

**Optional secrets** (will use defaults if not set):
- `AWS_REGION` → Default: `us-east-1`
- `STACK_NAME` → Default: `edi-monitor-stack`
- `S3_BUCKET` → Default: `edi-monitor`

## Step 2: Push to GitHub (30 seconds)

```bash
# If you haven't already pushed the code
git add .
git commit -m "Add EDI Monitor with GitHub Actions"
git push origin main
```

The deployment will start automatically! 🚀

## Step 3: Monitor Deployment (2 minutes)

1. Go to **Actions** tab in GitHub
2. Watch "Deploy EDI Monitor to AWS" workflow
3. Wait for green checkmark ✓

## Step 4: Get Your URLs

When deployment completes:

1. Click on the completed workflow run
2. Scroll to the bottom to see **Deployment summary**
3. You'll see:
   - **Frontend URL**: Your CloudFront URL (open in browser)
   - **API URL**: Your API Gateway endpoint

## Step 5: Upload Sample Data (1 minute)

1. Go to **Actions** tab
2. Click **Upload Sample Data** workflow
3. Click **Run workflow**
4. Enter your S3 bucket name (or use default: `edi-monitor`)
5. Click **Run workflow**

Wait ~30 seconds for completion ✓

## Step 6: Test Your Application (30 seconds)

Open the Frontend URL from Step 4 in your browser.

You should see:
- Dashboard with statistics
- Sample EDI documents
- Error indicators (red/yellow/green)
- Hebrew text for materials

## That's It! 🎉

Your EDI Monitor is now running on AWS!

## What Just Happened?

The GitHub Actions workflow:
1. ✅ Built your frontend (OpenUI5)
2. ✅ Packaged your backend (Python Lambda)
3. ✅ Created AWS infrastructure (CloudFormation)
4. ✅ Deployed to S3 and CloudFront
5. ✅ Set up API Gateway

## Next Steps

### Automatic Deployments

Every time you push to `main`, the app redeploys automatically:

```bash
# Make changes to your code
git add .
git commit -m "Update dashboard styling"
git push origin main
# Deployment starts automatically!
```

### Manual Deployment

Want to deploy without pushing?

1. Go to **Actions** tab
2. Click **Deploy EDI Monitor to AWS**
3. Click **Run workflow**
4. Select environment (dev/staging/prod)
5. Click **Run workflow**

### Upload Your Real Data

Replace sample data with your actual CSV files:

**Option 1: Use AWS CLI**
```bash
# Upload master data
aws s3 cp your-data/KNA1.csv s3://edi-monitor/master-data/KNA1.csv
aws s3 cp your-data/LFA1.csv s3://edi-monitor/master-data/LFA1.csv
aws s3 cp your-data/MAKT.csv s3://edi-monitor/master-data/MAKT.csv

# Upload EDI data
aws s3 cp your-data/YLO_SNXT_EDI_H.csv s3://edi-monitor/edi-mockdata/YLO_SNXT_EDI_H.csv
aws s3 cp your-data/YLO_SNXT_EDI_I.csv s3://edi-monitor/edi-mockdata/YLO_SNXT_EDI_I.csv
```

**Option 2: Use AWS Console**
1. Go to S3 in AWS Console
2. Open `edi-monitor` bucket
3. Upload files to `master-data/` and `edi-mockdata/` folders

### Customize the Application

Edit the files and push:

```bash
# Change dashboard colors
vim webapp/css/style.css

# Update error messages
vim webapp/i18n/i18n.properties

# Modify backend logic
vim backend/index.py

# Commit and push
git add .
git commit -m "Customize application"
git push origin main
```

## Troubleshooting

### Deployment Failed?

**Check AWS Credentials:**
- Verify secrets are set correctly in GitHub
- Ensure IAM user has required permissions

**View Logs:**
1. Go to Actions tab
2. Click on failed workflow
3. Expand steps to see error messages

### Application Not Working?

**Check API:**
```bash
curl https://your-api-endpoint/api/health
```

Should return: `{"status": "healthy", ...}`

**Check Data:**
```bash
aws s3 ls s3://edi-monitor/master-data/
aws s3 ls s3://edi-monitor/edi-mockdata/
```

Should see your CSV files.

### Need Help?

- **GitHub Actions Issues**: See [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)
- **AWS Deployment Issues**: See [DEPLOYMENT.md](DEPLOYMENT.md)
- **Application Issues**: See [README.md](README.md)

## Architecture Overview

```
GitHub Push
    ↓
GitHub Actions
    ↓
    ├─→ Build Frontend (OpenUI5)
    ├─→ Package Lambda (Python)
    ├─→ Deploy CloudFormation
    ├─→ Upload to S3
    └─→ Configure CloudFront
         ↓
    AWS Cloud
    ├─→ CloudFront (CDN)
    ├─→ S3 (Frontend + Data)
    ├─→ API Gateway
    └─→ Lambda (Backend)
```

## Cost Estimate

With sample data and light usage:
- **Lambda**: ~$0.20/month (free tier)
- **API Gateway**: ~$1/month (free tier)
- **S3**: ~$0.50/month
- **CloudFront**: ~$1/month (free tier)

**Total**: ~$2-3/month (mostly free tier)

## Security Checklist

- ✅ AWS credentials in GitHub Secrets (encrypted)
- ✅ IAM user with minimum permissions
- ✅ HTTPS enabled via CloudFront
- ✅ S3 bucket access controlled
- ⚠️ Consider adding API authentication for production

## What's Next?

1. **Add Authentication**: Implement AWS Cognito
2. **Set Up Monitoring**: CloudWatch dashboards
3. **Add Notifications**: Email/Slack alerts for errors
4. **Multiple Environments**: Separate dev/staging/prod
5. **Custom Domain**: Use Route53 for custom domain

Enjoy your EDI Monitor! 🎊

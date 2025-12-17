# EDI Monitor Application

An OpenUI5-based EDI monitoring application that highlights IDOC errors for non-technical users.

## Features

- Real-time EDI error monitoring
- Material description display in Hebrew
- Store and vendor master data integration
- Error categorization (Critical/Warning)
- User-friendly interface following SAP Fiori guidelines

## Architecture

- **Frontend**: OpenUI5 (v1.108.0)
- **Backend**: AWS Lambda + API Gateway
- **Data Storage**: AWS S3
- **Infrastructure**: AWS CloudFormation

## Data Structure

### Master Data (s3://edi-monitor/master-data/)
- `KNA1` - Store master data (receiver)
- `LFA1` - Vendor master data (sender)
- `MAKT` - Material description in Hebrew

### EDI Data (s3://edi-monitor/edi-mockdata/)
- `YLO_SNXT_EDI_H` - Header EDI data
- `YLO_SNXT_EDI_I` - Item EDI data

## Error Codes
- **104** (Critical): Item is not listed in store assortment
- **114** (Warning): Item wasn't ordered

## Deployment

### Option 1: GitHub Actions (Recommended)

Automated deployment using GitHub Actions workflows.

**Setup:**
1. Configure GitHub Secrets (see [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md)):
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION` (optional, defaults to us-east-1)

2. Deploy automatically:
   ```bash
   git push origin main
   ```
   Or manually trigger from GitHub Actions tab

3. Upload sample data:
   - Go to Actions → Upload Sample Data → Run workflow

**Workflows Available:**
- **Deploy to AWS** - Automatic deployment on push to main
- **Validate PR** - Validation for pull requests
- **Upload Sample Data** - Manual data upload

See [GITHUB_ACTIONS_SETUP.md](GITHUB_ACTIONS_SETUP.md) for complete setup guide.

### Option 2: Manual Deployment

Local deployment using shell scripts.

**Prerequisites:**
- AWS CLI configured
- Node.js 18.x or later
- Python 3.11
- AWS Account with appropriate permissions

**Deploy:**
```bash
# Deploy CloudFormation stack and application
./deploy.sh

# Upload sample data
./setup-sample-data.sh

# Test API endpoints
./test-api.sh
```

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed manual deployment guide.

### Local Development

```bash
# Install dependencies
npm install

# Run locally
npm start
```

## Configuration

AWS credentials should be configured in GitHub Secrets (for CI/CD) or locally:
- AWS Access Key ID and Secret Access Key
- S3 bucket access
- API Gateway configuration

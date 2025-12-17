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

### Prerequisites
- AWS CLI configured
- Node.js 18.x or later
- AWS Account with appropriate permissions

### Deploy Infrastructure

```bash
# Deploy CloudFormation stack
./deploy.sh
```

### Local Development

```bash
# Install dependencies
npm install

# Run locally
npm start
```

## Configuration

AWS credentials should be configured in AWS Secrets Manager or environment variables:
- S3 bucket access
- API Gateway configuration

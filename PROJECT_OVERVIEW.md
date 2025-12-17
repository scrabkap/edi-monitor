# EDI Monitor - Project Overview

## Project Structure

```
edi-monitor/
├── backend/                      # Backend Lambda functions
│   ├── index.py                 # Main Lambda handler with EDI processing logic
│   └── requirements.txt         # Python dependencies
├── webapp/                       # OpenUI5 Frontend application
│   ├── controller/              # Controllers for each view
│   │   ├── App.controller.js
│   │   ├── Dashboard.controller.js
│   │   ├── EDIDetail.controller.js
│   │   └── EDIList.controller.js
│   ├── view/                    # XML views following SAP Fiori guidelines
│   │   ├── App.view.xml
│   │   ├── Dashboard.view.xml
│   │   ├── EDIDetail.view.xml
│   │   └── EDIList.view.xml
│   ├── model/                   # Data models
│   │   └── models.js
│   ├── i18n/                    # Internationalization
│   │   └── i18n.properties
│   ├── css/                     # Custom styles
│   │   └── style.css
│   ├── Component.js             # Main application component
│   ├── index.html               # Entry point
│   └── manifest.json            # App descriptor
├── cloudformation.yaml          # AWS infrastructure as code
├── deploy.sh                    # Main deployment script
├── setup-sample-data.sh         # Sample data setup script
├── test-api.sh                  # API testing script
├── ui5.yaml                     # UI5 tooling configuration
├── package.json                 # Node.js dependencies
├── DEPLOYMENT.md                # Comprehensive deployment guide
├── README.md                    # Project documentation
└── .gitignore                   # Git ignore rules
```

## Architecture

### Frontend (OpenUI5)
- **Framework**: OpenUI5 v1.108.0
- **Design**: SAP Fiori/Horizon theme
- **Routing**: Client-side routing with three main views:
  - **Dashboard**: Overview with KPIs and recent errors
  - **EDI List**: Searchable/filterable list of all EDI documents
  - **EDI Detail**: Detailed view of a single document with items

### Backend (AWS Lambda)
- **Runtime**: Python 3.11
- **API Endpoints**:
  - `/api/health` - Health check
  - `/api/dashboard` - Aggregated statistics
  - `/api/edi-data` - EDI documents with enriched data
  - `/api/master-data` - Master data (KNA1, LFA1, MAKT)

### Infrastructure (AWS)
- **API Gateway**: HTTP API for backend
- **Lambda**: Serverless compute
- **S3**: Data storage and static hosting
- **CloudFront**: CDN for frontend distribution

## Data Flow

1. **Master Data Files** (S3):
   - KNA1: Store information (GP = EDI Store Number)
   - LFA1: Vendor information (EN = EDI Delivery)
   - MAKT: Material descriptions (Material = Barcode)

2. **EDI Data Files** (S3):
   - YLO_SNXT_EDI_H: Header records
     - Column A: Document Number
     - Column B: EDI Delivery → joins LFA1.EN
     - Column D: EDI Store Number → joins KNA1.GP
     - Column H: Error Code (104, 114)
   - YLO_SNXT_EDI_I: Item records
     - Column A: Document Number (links to header)
     - Column B: Barcode → joins MAKT.Material
     - Column C: Quantity
     - Column H: Error Code

3. **Processing**:
   - Lambda reads CSV files from S3
   - Performs joins to enrich data
   - Categorizes errors by severity
   - Returns JSON to frontend

4. **Display**:
   - Frontend fetches data via API
   - Displays with color coding (Error/Warning/Success)
   - Supports Hebrew text for material descriptions

## Error Codes

| Code | Severity | Description |
|------|----------|-------------|
| 104  | Error    | Item is not listed in store assortment |
| 114  | Warning  | Item wasn't ordered |

## Key Features

### Dashboard
- Total documents count
- Error/Warning/Success breakdown
- Error rate calculation
- Recent errors list
- One-click navigation to filtered views

### EDI List
- Full document list with search
- Filter by severity (All/Error/Warning/Success)
- Sortable columns
- Responsive table with pagination
- Display store name, vendor name, error info

### EDI Detail
- Complete document information
- Header-level error display
- Item-level details with material descriptions
- Hebrew text support for product names
- Status indicators for each item

## Development Guidelines

### Frontend (OpenUI5)
- Follow SAP Fiori design guidelines
- Use semantic colors (Error, Warning, Success)
- Implement responsive design
- Support Hebrew RTL text
- Use ObjectStatus for severity display
- Implement proper routing

### Backend (Python)
- Use boto3 for S3 access
- Handle CSV with UTF-8 BOM support
- Return proper CORS headers
- Implement error handling
- Log for debugging

### Infrastructure
- Use CloudFormation for IaC
- Follow AWS best practices
- Implement least privilege IAM
- Enable CORS properly
- Use CloudFront for caching

## Deployment Process

1. **Package Lambda**: Zip Python code with dependencies
2. **Deploy CloudFormation**: Create AWS resources
3. **Update Configuration**: Set API endpoint in frontend
4. **Build Frontend**: Compile UI5 application
5. **Upload to S3**: Deploy frontend files
6. **Upload Data**: Load master and EDI data

## Testing

### API Testing
```bash
./test-api.sh
```

### Manual Testing
1. Check health endpoint
2. Verify dashboard data
3. Test EDI list with filters
4. Navigate to detail views
5. Verify Hebrew text display

## Monitoring

- CloudWatch Logs for Lambda
- API Gateway metrics
- CloudFront access logs
- S3 access logs

## Security

- S3 buckets with appropriate policies
- Lambda with minimum required permissions
- API Gateway with CORS
- CloudFront with HTTPS
- No hardcoded credentials

## Performance

- Lambda: 512MB memory, 60s timeout
- CloudFront caching enabled
- S3 optimized for reads
- Lazy loading in UI5 tables
- Pagination for large datasets

## Scalability

- Serverless architecture auto-scales
- S3 handles any data volume
- CloudFront global distribution
- API Gateway rate limiting available

## Future Enhancements

1. **Authentication**: Add Cognito or IAM auth
2. **Real-time Updates**: WebSocket for live monitoring
3. **Notifications**: SNS/SES for error alerts
4. **Export**: CSV/Excel export functionality
5. **Advanced Filtering**: More filter options
6. **Analytics**: Historical trend analysis
7. **Multi-language**: Full i18n support
8. **Dark Mode**: UI theme switching

## Support

For deployment issues, see DEPLOYMENT.md
For API documentation, see backend/index.py
For UI customization, see webapp/ directory

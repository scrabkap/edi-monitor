import json
import boto3
import os
import csv
from io import StringIO
from datetime import datetime
from typing import Dict, List, Optional

s3_client = boto3.client('s3')
BUCKET = os.environ.get('S3_BUCKET', 'edi-monitor')

# Error code definitions
ERROR_CODES = {
    '104': {'severity': 'Error', 'description': 'Item is not listed in store assortment'},
    '114': {'severity': 'Warning', 'description': 'Item wasn\'t ordered'}
}

def lambda_handler(event, context):
    """Main Lambda handler"""
    try:
        # Parse request - support both API Gateway V1 and V2 formats
        # V2 (HTTP API) format
        if 'requestContext' in event and 'http' in event['requestContext']:
            http_method = event['requestContext']['http']['method']
            path = event['rawPath']
        # V1 (REST API) format
        else:
            http_method = event.get('httpMethod', 'GET')
            path = event.get('path', '')

        query_params = event.get('queryStringParameters') or {}

        # Strip stage name from path (e.g., /dev/api/dashboard -> /api/dashboard)
        if path.startswith('/dev/'):
            path = path[4:]
        elif path.startswith('/prod/'):
            path = path[5:]

        print(f"Processing request: {http_method} {path}")
        print(f"Event: {json.dumps(event)}")  # Debug logging

        # Route requests
        if path.startswith('/api/edi-data'):
            return get_edi_data(query_params)
        elif path.startswith('/api/master-data'):
            return get_master_data()
        elif path.startswith('/api/dashboard'):
            return get_dashboard_data()
        elif path.startswith('/api/health'):
            return {
                'statusCode': 200,
                'headers': get_cors_headers(),
                'body': json.dumps({'status': 'healthy', 'timestamp': datetime.now().isoformat()})
            }
        else:
            return {
                'statusCode': 404,
                'headers': get_cors_headers(),
                'body': json.dumps({
                    'error': 'Not found',
                    'path': path,
                    'method': http_method,
                    'available_routes': ['/api/health', '/api/dashboard', '/api/edi-data', '/api/master-data']
                })
            }
    except Exception as e:
        print(f"Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': str(e)})
        }

def get_cors_headers():
    """Return CORS headers for responses"""
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
        'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
    }

def read_csv_from_s3(key: str) -> List[Dict]:
    """Read CSV file from S3 and return as list of dictionaries"""
    try:
        print(f"Reading file from S3: {BUCKET}/{key}")
        response = s3_client.get_object(Bucket=BUCKET, Key=key)
        content = response['Body'].read().decode('utf-8-sig')  # Handle BOM

        csv_reader = csv.DictReader(StringIO(content))
        data = list(csv_reader)
        print(f"Successfully read {len(data)} rows from {key}")
        return data
    except Exception as e:
        print(f"Error reading {key}: {str(e)}")
        return []

def get_master_data():
    """Load and return all master data"""
    try:
        # Load master data files
        kna1_data = read_csv_from_s3('master-data/KNA1.csv')
        lfa1_data = read_csv_from_s3('master-data/LFA1.csv')
        makt_data = read_csv_from_s3('master-data/MAKT.csv')

        result = {
            'kna1': kna1_data,
            'lfa1': lfa1_data,
            'makt': makt_data,
            'timestamp': datetime.now().isoformat()
        }

        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(result, ensure_ascii=False)
        }
    except Exception as e:
        print(f"Error in get_master_data: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': str(e)})
        }

def get_edi_data(query_params: Dict):
    """Process and return EDI data with enriched information"""
    try:
        # Load EDI data
        edi_header = read_csv_from_s3('edi-mockdata/YLO_SNXT_EDI_H.csv')
        edi_items = read_csv_from_s3('edi-mockdata/YLO_SNXT_EDI_I.csv')

        # Load master data for joins
        kna1_data = read_csv_from_s3('master-data/KNA1.csv')
        lfa1_data = read_csv_from_s3('master-data/LFA1.csv')
        makt_data = read_csv_from_s3('master-data/MAKT.csv')

        # Create lookup dictionaries using correct column names
        kna1_lookup = {row.get('EDI Store number', '').strip(): row for row in kna1_data if row.get('EDI Store number', '').strip()}
        lfa1_lookup = {row.get('EDI Delivery', '').strip(): row for row in lfa1_data if row.get('EDI Delivery', '').strip()}
        makt_lookup = {row.get('Material', '').strip(): row for row in makt_data if row.get('Material', '').strip()}

        # Process EDI data
        enriched_data = process_edi_documents(edi_header, edi_items, kna1_lookup, lfa1_lookup, makt_lookup)

        # Apply filters
        severity_filter = query_params.get('severity')
        if severity_filter:
            enriched_data = [doc for doc in enriched_data if doc.get('severity') == severity_filter]

        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps({
                'data': enriched_data,
                'timestamp': datetime.now().isoformat(),
                'count': len(enriched_data)
            }, ensure_ascii=False)
        }
    except Exception as e:
        print(f"Error in get_edi_data: {str(e)}")
        import traceback
        traceback.print_exc()
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': str(e)})
        }

def process_edi_documents(headers: List[Dict], items: List[Dict],
                         kna1_lookup: Dict, lfa1_lookup: Dict, makt_lookup: Dict) -> List[Dict]:
    """Process EDI documents and enrich with master data"""
    result = []

    # Group items by EDI Delivery number
    items_by_delivery = {}
    for item in items:
        edi_delivery = item.get('EDI Delivery', '').strip()
        if edi_delivery:
            if edi_delivery not in items_by_delivery:
                items_by_delivery[edi_delivery] = []
            items_by_delivery[edi_delivery].append(item)

    for header in headers:
        # Get header fields using correct column names
        edi_delivery = header.get('EDI Delivery', '').strip()
        edi_store_number = header.get('EDI Store number', '').strip()
        error_code = header.get('Error Code', '').strip()
        doc_number = header.get('Vendor\'s Delivery Number', '').strip()

        # Skip headers that have no items
        if edi_delivery not in items_by_delivery:
            continue

        # Join with master data
        store_data = kna1_lookup.get(edi_store_number, {})
        vendor_data = lfa1_lookup.get(edi_delivery, {})

        # Get store and vendor names
        store_name = store_data.get('Name 1', 'Unknown Store').strip()
        vendor_name = vendor_data.get('Name 1', 'Unknown Vendor').strip()

        # Get items for this delivery
        doc_items = items_by_delivery.get(edi_delivery, [])

        # Enrich items with material descriptions
        enriched_items = []
        for item in doc_items:
            barcode = item.get('Barcode', '').strip()
            material_data = makt_lookup.get(barcode, {})
            material_desc = material_data.get('Material Description',
                                            material_data.get('Material description', 'Unknown Material')).strip()

            item_error_code = item.get('Error Code', '').strip()

            enriched_item = {
                'barcode': barcode,
                'material_description': material_desc,
                'quantity': item.get('PC Quantity', '').strip(),
                'error_code': item_error_code,
                'error_info': get_error_info(item_error_code)
            }
            enriched_items.append(enriched_item)

        # Determine overall severity
        severity = get_severity(error_code, enriched_items)

        doc_data = {
            'document_number': doc_number,
            'edi_delivery': edi_delivery,
            'edi_store_number': edi_store_number,
            'store_name': store_name,
            'vendor_name': vendor_name,
            'error_code': error_code,
            'error_info': get_error_info(error_code),
            'severity': severity,
            'items': enriched_items,
            'item_count': len(enriched_items),
            'error_count': sum(1 for item in enriched_items if item['error_code']),
            'timestamp': datetime.now().isoformat()
        }

        result.append(doc_data)

    return result

def get_error_info(error_code: str) -> Optional[Dict]:
    """Get error information for a given error code"""
    if error_code and error_code in ERROR_CODES:
        return ERROR_CODES[error_code]
    return None

def get_severity(header_error: str, items: List[Dict]) -> str:
    """Determine overall severity based on header and items"""
    # Check header error
    if header_error == '104':
        return 'Error'

    # Check items for any critical errors
    for item in items:
        if item.get('error_code') == '104':
            return 'Error'

    # Check for warnings
    if header_error == '114':
        return 'Warning'

    for item in items:
        if item.get('error_code') == '114':
            return 'Warning'

    return 'Success'

def get_dashboard_data():
    """Get aggregated dashboard data"""
    try:
        # Load EDI data
        edi_header = read_csv_from_s3('edi-mockdata/YLO_SNXT_EDI_H.csv')
        edi_items = read_csv_from_s3('edi-mockdata/YLO_SNXT_EDI_I.csv')

        # Load master data
        kna1_data = read_csv_from_s3('master-data/KNA1.csv')
        lfa1_data = read_csv_from_s3('master-data/LFA1.csv')
        makt_data = read_csv_from_s3('master-data/MAKT.csv')

        # Create lookups
        kna1_lookup = {row.get('GP', ''): row for row in kna1_data if row.get('GP')}
        lfa1_lookup = {row.get('EN', ''): row for row in lfa1_data if row.get('EN')}
        makt_lookup = {row.get('Material', ''): row for row in makt_data if row.get('Material')}

        # Process data
        enriched_data = process_edi_documents(edi_header, edi_items, kna1_lookup, lfa1_lookup, makt_lookup)

        # Calculate statistics
        total_documents = len(enriched_data)
        error_documents = sum(1 for doc in enriched_data if doc['severity'] == 'Error')
        warning_documents = sum(1 for doc in enriched_data if doc['severity'] == 'Warning')
        success_documents = sum(1 for doc in enriched_data if doc['severity'] == 'Success')

        dashboard = {
            'total_documents': total_documents,
            'error_documents': error_documents,
            'warning_documents': warning_documents,
            'success_documents': success_documents,
            'error_rate': round(error_documents / total_documents * 100, 2) if total_documents > 0 else 0,
            'timestamp': datetime.now().isoformat(),
            'recent_errors': [doc for doc in enriched_data if doc['severity'] == 'Error'][:10]
        }

        return {
            'statusCode': 200,
            'headers': get_cors_headers(),
            'body': json.dumps(dashboard, ensure_ascii=False)
        }
    except Exception as e:
        print(f"Error in get_dashboard_data: {str(e)}")
        return {
            'statusCode': 500,
            'headers': get_cors_headers(),
            'body': json.dumps({'error': str(e)})
        }

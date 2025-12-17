# SAP EDI Monitor - Implementation Guide

## Overview

This guide explains how to implement the EDI Monitor application in SAP ECC using OData services. The current mock implementation (AWS Lambda + S3 CSV files) will be replaced with a real SAP Gateway OData service that reads directly from SAP tables.

---

## Architecture Comparison

### Current Mock Architecture (POC)
```
OpenUI5 Frontend
    ↓ HTTP GET
AWS API Gateway
    ↓ Invoke
AWS Lambda (Python)
    ↓ Read CSV
S3 Bucket
    - YLO_SNXT_EDI_H.csv
    - YLO_SNXT_EDI_I.csv
    - KNA1.csv (Customer Master)
    - LFA1.csv (Vendor Master)
    - MAKT.csv (Material Descriptions)
```

### SAP Production Architecture
```
OpenUI5 Frontend
    ↓ HTTP GET (OData)
SAP Gateway (ICM)
    ↓ Route
OData Service (ZEDI_MONITOR_SRV)
    ↓ DPC Class Methods
Backend ABAP
    ↓ SELECT
SAP Database Tables
    - YLO_SNXT_EDI_H (EDI Header)
    - YLO_SNXT_EDI_I (EDI Items)
    - KNA1 (Customer Master)
    - LFA1 (Vendor Master)
    - MAKT (Material Descriptions)
```

---

## Files Provided

1. **ZEDI_MONITOR_SRV_metadata.xml**
   - Simplified OData metadata definition
   - Only includes fields needed for the UI
   - Removed 100+ irrelevant fields from LFA1, KNA1

2. **ZCL_EDI_MONITOR_DPC_EXT.abap**
   - Data Provider Class (DPC) implementation
   - Contains all business logic methods
   - Handles data retrieval and enrichment

3. **IMPLEMENTATION_GUIDE.md** (this file)
   - Step-by-step implementation instructions
   - API mapping between mock and SAP
   - Testing procedures

---

## Implementation Steps

### Step 1: Create Custom Tables (if not already exist)

The EDI tables should already exist in your SAP system. Verify with **SE11**:

```abap
* YLO_SNXT_EDI_H - EDI Header Table
* Key Fields: MANDT, SENDR, V_EDI

* YLO_SNXT_EDI_I - EDI Item Table
* Key Fields: MANDT, SENDR, V_EDI, REFLN
```

### Step 2: Create OData Service in SEGW

1. **Open Transaction SEGW** (Gateway Service Builder)

2. **Create New Project:**
   - Project Name: `ZEDI_MONITOR`
   - Description: `EDI Monitor OData Service`
   - Package: `ZEDI` (or your custom package)

3. **Import EDMX:**
   - Right-click on Data Model → Import → EDMX
   - Select file: `ZEDI_MONITOR_SRV_metadata.xml`
   - This will create all entity types and associations

4. **Generate Runtime Objects:**
   - Click "Generate Runtime Objects" button
   - This creates:
     - **MPC** (Model Provider Class): `ZCL_EDI_MONITOR_MPC`
     - **DPC** (Data Provider Class): `ZCL_EDI_MONITOR_DPC`
     - **DPC_EXT** (Extension class): `ZCL_EDI_MONITOR_DPC_EXT`

### Step 3: Implement Business Logic

1. **Open SE24** and edit class `ZCL_EDI_MONITOR_DPC_EXT`

2. **Copy the provided ABAP code** from `ZCL_EDI_MONITOR_DPC_EXT.abap`

3. **Adjust table/field names** if your custom tables have different names

4. **Activate the class** (Ctrl+F3)

### Step 4: Register and Activate Service

1. **Back in SEGW**, click "Register Service" button
   - System Alias: `LOCAL` (for development)
   - Package Assignment: `$TMP` or your package

2. **Activate Service** in transaction `/IWFND/MAINT_SERVICE`:
   - Add Service → `ZEDI_MONITOR_SRV`
   - System Alias: `LOCAL`

### Step 5: Test OData Service

1. **Open Gateway Client** (`/IWFND/GW_CLIENT`)

2. **Test Endpoints:**

   ```
   GET /sap/opu/odata/sap/ZEDI_MONITOR_SRV/EDIDocuments
   GET /sap/opu/odata/sap/ZEDI_MONITOR_SRV/EDIDocuments('43681')
   GET /sap/opu/odata/sap/ZEDI_MONITOR_SRV/EDIDocuments?$filter=Severity eq 'Error'
   GET /sap/opu/odata/sap/ZEDI_MONITOR_SRV/DashboardKPI('MAIN')
   ```

3. **Verify Response Format** matches expected structure

### Step 6: Update Frontend Configuration

1. **Edit `webapp/Component.js`** in your OpenUI5 app

2. **Update API endpoint** from AWS to SAP:

   ```javascript
   // OLD (Mock):
   const API_BASE_URL = "https://abc123.execute-api.us-east-1.amazonaws.com/prod";

   // NEW (SAP):
   const API_BASE_URL = "/sap/opu/odata/sap/ZEDI_MONITOR_SRV";
   ```

3. **Change from REST to OData model:**

   ```javascript
   // OLD (Mock - JSON Model):
   const oModel = new JSONModel();
   this.setModel(oModel, "edi");

   // NEW (SAP - OData V4 Model):
   const oModel = new sap.ui.model.odata.v4.ODataModel({
       serviceUrl: "/sap/opu/odata/sap/ZEDI_MONITOR_SRV/",
       synchronizationMode: "None",
       operationMode: "Server"
   });
   this.setModel(oModel);
   ```

---

## API Mapping: Mock → SAP OData

### Current Mock API Endpoints

| Mock Endpoint | Method | Description |
|--------------|--------|-------------|
| `/edi-data` | GET | Get list of EDI documents |
| `/edi-data/{id}` | GET | Get single document |
| `/dashboard` | GET | Get KPI metrics |
| `/master-data` | GET | Get all master data |

### SAP OData Service Endpoints

| OData Endpoint | Method | Mock Equivalent |
|---------------|--------|-----------------|
| `/EDIDocuments` | GET | `/edi-data` |
| `/EDIDocuments('{id}')` | GET | `/edi-data/{id}` |
| `/EDIDocuments('{id}')?$expand=Items` | GET | `/edi-data/{id}` (with items) |
| `/DashboardKPI('MAIN')` | GET | `/dashboard` |
| `/EDIDocuments?$filter=Severity eq 'Error'` | GET | `/edi-data?severity=Error` |
| `/EDIDocuments?$top=100&$skip=20` | GET | `/edi-data?limit=100&offset=20` |

### Query Parameter Mapping

| Mock Parameter | OData Equivalent | Example |
|---------------|------------------|---------|
| `?severity=Error` | `?$filter=Severity eq 'Error'` | Filter by severity |
| `?limit=100&offset=20` | `?$top=100&$skip=20` | Pagination |
| `?days=7` | Custom filter logic | Date range filter |
| `?store=123` | `?$filter=EdiStoreNumber eq '123'` | Store filter |
| `?vendor=456` | `?$filter=EdiDelivery eq '456'` | Vendor filter |

---

## Class Structure

### Main OData Service Class: `ZCL_EDI_MONITOR_DPC_EXT`

```abap
CLASS zcl_edi_monitor_dpc_ext DEFINITION
  PUBLIC
  INHERITING FROM zcl_edi_monitor_dpc
  CREATE PUBLIC.

  PUBLIC SECTION.

    " OData CRUD Methods (auto-generated signatures)
    METHODS edidocuments_get_entityset REDEFINITION.
    METHODS edidocuments_get_entity REDEFINITION.
    METHODS ediitems_get_entityset REDEFINITION.
    METHODS dashboardkpi_get_entity REDEFINITION.

  PRIVATE SECTION.

    " Helper Methods
    METHODS get_error_info.
    METHODS get_document_severity.
    METHODS calculate_error_count.
    METHODS read_vendor_master.
    METHODS read_customer_master.
    METHODS read_material_description.
    METHODS normalize_numeric.

ENDCLASS.
```

### Method Responsibilities

#### 1. `EDIDOCUMENTS_GET_ENTITYSET`
**Purpose:** Get list of EDI documents

**What it does:**
1. Reads query parameters (`$filter`, `$top`, `$skip`)
2. Selects from `YLO_SNXT_EDI_H` table
3. Selects from `YLO_SNXT_EDI_I` table
4. Joins with master data (KNA1, LFA1)
5. Calculates severity and error count for each document
6. Applies filters and pagination
7. Returns enriched document list

**Mock Equivalent:** `GET /edi-data`

#### 2. `EDIDOCUMENTS_GET_ENTITY`
**Purpose:** Get single EDI document by key

**What it does:**
1. Reads key from URL (e.g., `EDIDocuments('43681')`)
2. Selects single header from `YLO_SNXT_EDI_H`
3. Enriches with master data
4. Returns single document

**Mock Equivalent:** `GET /edi-data/{id}`

#### 3. `EDIITEMS_GET_ENTITYSET`
**Purpose:** Get EDI items (usually via navigation)

**What it does:**
1. Checks for filter (usually `DocumentNumber`)
2. Selects from `YLO_SNXT_EDI_I` table
3. Joins with MAKT for material descriptions
4. Determines item severity (Error/Warning/Success)
5. Returns enriched item list

**Mock Equivalent:** Items array in document response

#### 4. `DASHBOARDKPI_GET_ENTITY`
**Purpose:** Calculate and return dashboard KPIs

**What it does:**
1. Selects all headers and items
2. Calculates:
   - Total documents
   - Error documents (severity = Error)
   - Warning documents (severity = Warning)
   - Success documents (severity = Success)
   - Total items
   - Error items (only error code 104)
3. Returns KPI structure

**Mock Equivalent:** `GET /dashboard`

---

## Business Logic - Error Count Calculation

### Rules (CRITICAL - Must match mock behavior)

```abap
" Rule 1: Header Error Code 28 (General Document Error)
" → Count ALL items as errors (entire document failed)

IF header_error_code = '28'.
  error_count = lines( items ).  " All items affected
ENDIF.

" Rule 2: Item Error Codes
" → Count ONLY items with error code 104 (critical error)
" → Do NOT count warning code 114

error_count = REDUCE i( INIT cnt = 0
                        FOR item IN items
                        WHERE ( error_code = '104' )
                        NEXT cnt = cnt + 1 ).
```

### Severity Calculation

```abap
" Priority: Error > Warning > Success

" 1. Check header for error code 28
IF header_error_code = '28'.
  severity = 'Error'.
  RETURN.
ENDIF.

" 2. Check items for error code 104
IF ANY item IN items SATISFIES ( error_code = '104' ).
  severity = 'Error'.
  RETURN.
ENDIF.

" 3. Check items for warning code 114
IF ANY item IN items SATISFIES ( error_code = '114' ).
  severity = 'Warning'.
  RETURN.
ENDIF.

" 4. No errors or warnings
severity = 'Success'.
```

---

## Testing Checklist

### Backend Testing (Gateway Client)

- [ ] Service activated in `/IWFND/MAINT_SERVICE`
- [ ] Metadata loads: `/sap/opu/odata/sap/ZEDI_MONITOR_SRV/$metadata`
- [ ] Get all documents: `/EDIDocuments`
- [ ] Get single document: `/EDIDocuments('43681')`
- [ ] Get with items: `/EDIDocuments('43681')?$expand=Items`
- [ ] Filter by severity: `/EDIDocuments?$filter=Severity eq 'Error'`
- [ ] Pagination works: `/EDIDocuments?$top=10&$skip=0`
- [ ] Dashboard KPIs: `/DashboardKPI('MAIN')`

### Frontend Testing (OpenUI5 App)

- [ ] Dashboard loads with correct KPI counts
- [ ] Document list shows all 13 documents
- [ ] Error count shows 0 for documents with only warnings (code 114)
- [ ] Error count shows correct count for documents with error code 104
- [ ] Document with error code 28 shows error_count = item_count
- [ ] Barcode displays correctly (no scientific notation)
- [ ] Material descriptions appear
- [ ] Store names appear (from KNA1)
- [ ] Vendor names appear (from LFA1)
- [ ] Item status filter works (All/Error/Warning/Success)
- [ ] Advanced filters work (Store, Vendor, Document, Date Range)

### Data Validation

- [ ] Compare mock response with OData response for document 43681
- [ ] Verify error counts match between mock and SAP
- [ ] Verify severity calculations match
- [ ] Check timestamp format (ISO 8601)

---

## Performance Considerations

### Indexing Recommendations

```sql
-- YLO_SNXT_EDI_H table
CREATE INDEX YLO_SNXT_EDI_H~001 ON YLO_SNXT_EDI_H (DNDAT, DNTIM);

-- YLO_SNXT_EDI_I table
CREATE INDEX YLO_SNXT_EDI_I~001 ON YLO_SNXT_EDI_I (V_EDI);
```

### Query Optimization

1. **Use `UP TO n ROWS`** for large result sets
2. **Add buffering** for master data tables (KNA1, LFA1, MAKT)
3. **Implement caching** for dashboard KPIs (refresh every 5 minutes)
4. **Use parallel cursor** for large item reads

```abap
" Buffer master data lookups
DATA: gt_vendor_cache TYPE HASHED TABLE OF lfa1 WITH UNIQUE KEY lifnr,
      gt_customer_cache TYPE HASHED TABLE OF kna1 WITH UNIQUE KEY kunnr,
      gt_material_cache TYPE HASHED TABLE OF makt WITH UNIQUE KEY matnr.
```

---

## Security and Authorization

### Authorization Objects

Create custom authorization object: `ZEDI_MONITOR`

Fields:
- `ACTVT` - Activity (01=Display, 02=Change, etc.)
- `WERKS` - Plant (if store-specific access needed)

### Role Configuration

```abap
" Check authorization in each method
AUTHORITY-CHECK OBJECT 'ZEDI_MONITOR'
  ID 'ACTVT' FIELD '03'.  " 03 = Display

IF sy-subrc <> 0.
  " User not authorized
  RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
    EXPORTING
      textid = /iwbep/cx_mgw_busi_exception=>not_authorized.
ENDIF.
```

---

## Deployment Steps

### Development → Quality → Production

1. **Development System (DEV):**
   - Create and test OData service
   - Unit test all methods
   - Verify data quality

2. **Transport to Quality (QAS):**
   - Transport Request: `DEVK9xxxxx`
   - Objects to transport:
     - Tables: `YLO_SNXT_EDI_H`, `YLO_SNXT_EDI_I`
     - Service: `ZEDI_MONITOR_SRV`
     - Classes: `ZCL_EDI_MONITOR_*`
     - Authorization: `ZEDI_MONITOR`
   - Integration testing
   - User acceptance testing (UAT)

3. **Transport to Production (PRD):**
   - Final transport
   - Activate service in `/IWFND/MAINT_SERVICE`
   - Configure ICM (Internet Communication Manager)
   - Set up SSL certificates
   - Enable CORS if needed

### Frontend Deployment

```bash
# Build OpenUI5 app
npm run build

# Deploy to SAP Gateway
# Option 1: Deploy to BSP (Business Server Pages)
# - Transaction: SE80
# - Create BSP application: ZEDI_MONITOR_UI
# - Upload dist/ folder

# Option 2: Deploy to Fiori Launchpad
# - Use Fiori Tools
# - Deploy via abap deploy task
```

---

## Differences from Mock Implementation

### What Stays the Same

✅ UI/UX (OpenUI5 views and controllers)
✅ Business logic (error count calculation, severity rules)
✅ Data structure (document, items, error codes)
✅ Error code definitions (28, 104, 114)

### What Changes

❌ **Data Source:** S3 CSV files → SAP database tables
❌ **API Protocol:** REST JSON → OData
❌ **Backend Language:** Python → ABAP
❌ **Infrastructure:** AWS Lambda → SAP Gateway
❌ **Authentication:** API Key → SAP SSO/SAML

### Frontend Code Changes Required

**Minimal changes needed!** Just update the model:

```javascript
// OLD: JSON Model with REST calls
const oModel = new JSONModel();
$.ajax({
    url: API_BASE_URL + "/edi-data",
    success: (data) => oModel.setData(data)
});

// NEW: OData V4 Model (automatic)
const oModel = new sap.ui.model.odata.v4.ODataModel({
    serviceUrl: "/sap/opu/odata/sap/ZEDI_MONITOR_SRV/"
});
// OData binding handles all CRUD operations automatically!
```

---

## Troubleshooting

### Common Issues

**1. Service not found (404)**
- Check service is activated in `/IWFND/MAINT_SERVICE`
- Verify URL path is correct
- Check ICM is running: `SMICM`

**2. No data returned**
- Check table `YLO_SNXT_EDI_H` has data: `SE16`
- Verify SELECT statements in debug mode
- Check authorization: `SU53`

**3. Performance issues**
- Add indexes (see Performance Considerations)
- Reduce result set with `$top`
- Enable caching for master data

**4. CORS errors (frontend)**
- Configure ICM CORS settings: `SICF`
- Enable trusted origins in Gateway

---

## Contact and Support

For questions about this implementation:

**SAP Basis Team:** Activate service, transport, ICM config
**ABAP Development Team:** Custom tables, OData service logic
**Frontend Team:** OpenUI5 app changes, model binding

---

## Appendix: Error Code Reference

| Code | Severity | Description | Count Logic |
|------|----------|-------------|-------------|
| 28 | Error | General error - entire document failed | Count all items |
| 104 | Error | Item is not listed in store assortment | Count only items with code 104 |
| 114 | Warning | Item wasn't ordered | Do NOT count in error_count |

---

**Last Updated:** 2025-12-17
**Version:** 1.0
**Author:** EDI Monitor Development Team

*&---------------------------------------------------------------------*
*& Class: ZCL_EDI_MONITOR_DPC_EXT (CDS Version)
*& Description: OData Service Implementation using CDS Views
*& Service: ZEDI_MONITOR_SRV
*&---------------------------------------------------------------------*
*& This version uses CDS views instead of direct table reads
*& CDS views handle joins, calculations, and data enrichment
*& Result: Cleaner, faster, more maintainable code
*&---------------------------------------------------------------------*

CLASS zcl_edi_monitor_dpc_ext DEFINITION
  PUBLIC
  INHERITING FROM zcl_edi_monitor_dpc
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS:
      "! Override GET_ENTITYSET for EDIDocuments
      edidocuments_get_entityset REDEFINITION,

      "! Override GET_ENTITY for EDIDocuments
      edidocuments_get_entity REDEFINITION,

      "! Override GET_ENTITYSET for EDIItems
      ediitems_get_entityset REDEFINITION,

      "! Override GET_ENTITY for DashboardKPI
      dashboardkpi_get_entity REDEFINITION.

  PRIVATE SECTION.

    METHODS:
      "! Apply filters from OData query to CDS view
      apply_filters
        IMPORTING
          io_filter        TYPE REF TO /iwbep/if_mgw_req_filter
        CHANGING
          ct_filter_select TYPE /iwbep/t_mgw_select_option.

ENDCLASS.


CLASS zcl_edi_monitor_dpc_ext IMPLEMENTATION.

*&---------------------------------------------------------------------*
*& Method: EDIDOCUMENTS_GET_ENTITYSET
*& Description: Get list of EDI documents using CDS view
*& CDS View: ZEDI_C_DOCUMENT (handles all joins and calculations)
*&---------------------------------------------------------------------*
  METHOD edidocuments_get_entityset.

    DATA:
      lt_documents   TYPE STANDARD TABLE OF zedi_c_document,
      ls_document    TYPE zedi_c_document,
      ls_entity      TYPE zcl_edi_monitor_mpc=>ts_edidocument,
      lt_filter      TYPE /iwbep/t_mgw_select_option,
      lv_top         TYPE i,
      lv_skip        TYPE i,
      lv_orderby     TYPE string.

    "---------------------------------------------------------------------
    " 1. Read Pagination Parameters
    "---------------------------------------------------------------------
    lv_top = io_tech_request_context->get_top( ).
    lv_skip = io_tech_request_context->get_skip( ).

    IF lv_top IS INITIAL OR lv_top > 100.
      lv_top = 100. " Default/max page size
    ENDIF.

    "---------------------------------------------------------------------
    " 2. Read Filters from URL
    "---------------------------------------------------------------------
    io_tech_request_context->get_filter( )->get_filter_select_options(
      IMPORTING
        et_select_options = lt_filter ).

    "---------------------------------------------------------------------
    " 3. Select from CDS View (all joins/calculations handled in CDS!)
    "---------------------------------------------------------------------
    TRY.
        SELECT *
          FROM zedi_c_document
          INTO TABLE @lt_documents
          UP TO @lv_top ROWS
          ORDER BY processing_date DESCENDING,
                   processing_time DESCENDING.

      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        " Handle database errors
        RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
          EXPORTING
            textid           = /iwbep/cx_mgw_busi_exception=>business_error
            message          = lx_sql->get_text( )
            http_status_code = /iwbep/cx_mgw_busi_exception=>gcs_http_status_codes-internal_server_error.
    ENDTRY.

    "---------------------------------------------------------------------
    " 4. Apply Filters (if needed - can also use WHERE clause in SELECT)
    "---------------------------------------------------------------------
    " Filters like ?$filter=Severity eq 'Error'
    " Can be handled by adding WHERE conditions to SELECT above

    "---------------------------------------------------------------------
    " 5. Apply Pagination ($skip)
    "---------------------------------------------------------------------
    IF lv_skip > 0 AND lv_skip < lines( lt_documents ).
      DELETE lt_documents TO lv_skip.
    ENDIF.

    "---------------------------------------------------------------------
    " 6. Map CDS View to OData Entity Structure
    "---------------------------------------------------------------------
    LOOP AT lt_documents INTO ls_document.

      CLEAR ls_entity.

      " Direct mapping (CDS view already has correct field names)
      ls_entity-document_number     = ls_document-documentnumber.
      ls_entity-edi_delivery        = ls_document-edidelivery.
      ls_entity-edi_store_number    = ls_document-edistorenumber.
      ls_entity-vendor_name         = ls_document-vendorname.
      ls_entity-store_name          = ls_document-storename.
      ls_entity-processing_date     = ls_document-processingdate.
      ls_entity-processing_time     = ls_document-processingtime.
      ls_entity-timestamp           = ls_document-timestamp.
      ls_entity-error_code          = ls_document-errorcode.
      ls_entity-error_description   = ls_document-errordescription.
      ls_entity-severity            = ls_document-severity.
      ls_entity-item_count          = ls_document-itemcount.
      ls_entity-error_count         = ls_document-errorcount.
      ls_entity-vbeln               = ls_document-salesdocument.
      ls_entity-mblnr               = ls_document-materialdocument.
      ls_entity-mjahr               = ls_document-materialdocumentyear.

      APPEND ls_entity TO et_entityset.

    ENDLOOP.

    "---------------------------------------------------------------------
    " 7. Set Inline Count (total records for paging)
    "---------------------------------------------------------------------
    " If client requests $inlinecount=allpages
    IF io_tech_request_context->has_inlinecount( ).
      SELECT COUNT(*)
        FROM zedi_c_document
        INTO @DATA(lv_count).
      es_response_context-count = lv_count.
    ENDIF.

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& Method: EDIDOCUMENTS_GET_ENTITY
*& Description: Get single EDI document by key using CDS view
*&---------------------------------------------------------------------*
  METHOD edidocuments_get_entity.

    DATA:
      ls_document TYPE zedi_c_document,
      lv_doc_id   TYPE string.

    "---------------------------------------------------------------------
    " 1. Read Key from URL
    "---------------------------------------------------------------------
    io_tech_request_context->get_converted_keys(
      IMPORTING
        es_key_values = DATA(ls_key) ).

    lv_doc_id = ls_key-document_number.

    "---------------------------------------------------------------------
    " 2. Read from CDS View (single record)
    "---------------------------------------------------------------------
    SELECT SINGLE *
      FROM zedi_c_document
      INTO @ls_document
      WHERE documentnumber = @lv_doc_id.

    IF sy-subrc NE 0.
      " Document not found
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          textid            = /iwbep/cx_mgw_busi_exception=>resource_not_found
          message           = |Document { lv_doc_id } not found|
          http_status_code  = /iwbep/cx_mgw_busi_exception=>gcs_http_status_codes-not_found.
    ENDIF.

    "---------------------------------------------------------------------
    " 3. Map to Entity Structure
    "---------------------------------------------------------------------
    er_entity-document_number     = ls_document-documentnumber.
    er_entity-edi_delivery        = ls_document-edidelivery.
    er_entity-edi_store_number    = ls_document-edistorenumber.
    er_entity-vendor_name         = ls_document-vendorname.
    er_entity-store_name          = ls_document-storename.
    er_entity-processing_date     = ls_document-processingdate.
    er_entity-processing_time     = ls_document-processingtime.
    er_entity-timestamp           = ls_document-timestamp.
    er_entity-error_code          = ls_document-errorcode.
    er_entity-error_description   = ls_document-errordescription.
    er_entity-severity            = ls_document-severity.
    er_entity-item_count          = ls_document-itemcount.
    er_entity-error_count         = ls_document-errorcount.
    er_entity-vbeln               = ls_document-salesdocument.
    er_entity-mblnr               = ls_document-materialdocument.
    er_entity-mjahr               = ls_document-materialdocumentyear.

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& Method: EDIITEMS_GET_ENTITYSET
*& Description: Get EDI items using CDS view
*&---------------------------------------------------------------------*
  METHOD ediitems_get_entityset.

    DATA:
      lt_items       TYPE STANDARD TABLE OF zedi_c_item,
      ls_item        TYPE zedi_c_item,
      ls_entity      TYPE zcl_edi_monitor_mpc=>ts_ediitem,
      lt_filter      TYPE /iwbep/t_mgw_select_option,
      lv_doc_number  TYPE string.

    "---------------------------------------------------------------------
    " 1. Check if filtered by DocumentNumber (from navigation)
    "---------------------------------------------------------------------
    io_tech_request_context->get_filter( )->get_filter_select_options(
      IMPORTING
        et_select_options = lt_filter ).

    READ TABLE lt_filter WITH KEY property = 'DOCUMENTNUMBER' INTO DATA(ls_filter).
    IF sy-subrc = 0.
      READ TABLE ls_filter-select_options INDEX 1 INTO DATA(ls_option).
      lv_doc_number = ls_option-low.
    ENDIF.

    "---------------------------------------------------------------------
    " 2. Select from CDS View
    "---------------------------------------------------------------------
    IF lv_doc_number IS NOT INITIAL.
      " Filtered by document number (typical case)
      SELECT *
        FROM zedi_c_item
        INTO TABLE @lt_items
        WHERE documentnumber = @lv_doc_number.
    ELSE.
      " All items (use with caution - limit to 1000)
      SELECT *
        FROM zedi_c_item
        INTO TABLE @lt_items
        UP TO 1000 ROWS.
    ENDIF.

    "---------------------------------------------------------------------
    " 3. Map to Entity Structure
    "---------------------------------------------------------------------
    LOOP AT lt_items INTO ls_item.

      CLEAR ls_entity.

      ls_entity-document_number       = ls_item-documentnumber.
      ls_entity-item_number           = ls_item-itemnumber.
      ls_entity-barcode               = ls_item-barcode.
      ls_entity-material_description  = ls_item-materialdescription.
      ls_entity-quantity              = ls_item-quantity.
      ls_entity-weight                = ls_item-weight.
      ls_entity-error_code            = ls_item-errorcode.
      ls_entity-error_description     = ls_item-errordescription.
      ls_entity-severity              = ls_item-severity.
      ls_entity-expiration_date       = ls_item-expirationdate.
      ls_entity-purchase_order        = ls_item-purchaseorder.
      ls_entity-po_item               = ls_item-poitem.

      APPEND ls_entity TO et_entityset.

    ENDLOOP.

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& Method: DASHBOARDKPI_GET_ENTITY
*& Description: Get dashboard KPIs using CDS aggregate view
*&---------------------------------------------------------------------*
  METHOD dashboardkpi_get_entity.

    DATA: ls_kpi TYPE zedi_c_dashboard.

    "---------------------------------------------------------------------
    " Read from CDS Dashboard View (aggregation handled in CDS!)
    "---------------------------------------------------------------------
    SELECT SINGLE *
      FROM zedi_c_dashboard
      INTO @ls_kpi
      WHERE id = 'MAIN'.

    IF sy-subrc = 0.
      " Map to entity structure
      er_entity-id                  = ls_kpi-id.
      er_entity-total_documents     = ls_kpi-totaldocuments.
      er_entity-error_documents     = ls_kpi-errordocuments.
      er_entity-warning_documents   = ls_kpi-warningdocuments.
      er_entity-success_documents   = ls_kpi-successdocuments.
      er_entity-total_items         = ls_kpi-totalitems.
      er_entity-error_items         = ls_kpi-erroritems.
      er_entity-last_update         = ls_kpi-lastupdate.
    ELSE.
      " Return empty KPIs if no data
      er_entity-id = 'MAIN'.
      er_entity-total_documents     = 0.
      er_entity-error_documents     = 0.
      er_entity-warning_documents   = 0.
      er_entity-success_documents   = 0.
      er_entity-total_items         = 0.
      er_entity-error_items         = 0.
      er_entity-last_update         = cl_abap_tstmp=>utclong_current( ).
    ENDIF.

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& Helper Methods
*&---------------------------------------------------------------------*

  METHOD apply_filters.
    " Apply OData filters to SELECT statement
    " Can be extended to support complex $filter expressions
  ENDMETHOD.

ENDCLASS.

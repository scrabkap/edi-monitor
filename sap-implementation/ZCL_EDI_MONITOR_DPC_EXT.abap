*&---------------------------------------------------------------------*
*& Class: ZCL_EDI_MONITOR_DPC_EXT
*& Description: OData Service Implementation for EDI Monitor
*& Service: ZEDI_MONITOR_SRV
*&---------------------------------------------------------------------*
*& This class extends the generated Data Provider Class (DPC)
*& Created in SEGW (Gateway Service Builder) transaction
*&---------------------------------------------------------------------*

CLASS zcl_edi_monitor_dpc_ext DEFINITION
  PUBLIC
  INHERITING FROM zcl_edi_monitor_dpc
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! Error code constants
    CONSTANTS:
      gc_error_general    TYPE char3 VALUE '28',  " General document error
      gc_error_critical   TYPE char3 VALUE '104', " Item not in assortment
      gc_warning_not_ord  TYPE char3 VALUE '114'. " Item wasn't ordered

    METHODS:
      "! Override GET_ENTITYSET for EDIDocuments
      edidocuments_get_entityset REDEFINITION,

      "! Override GET_ENTITY for EDIDocuments
      edidocuments_get_entity REDEFINITION,

      "! Override GET_ENTITYSET for EDIItems
      ediitems_get_entityset REDEFINITION,

      "! Override GET_ENTITY for DashboardKPI
      dashboardkpi_get_entity REDEFINITION.

  PROTECTED SECTION.

  PRIVATE SECTION.

    TYPES:
      "! Structure for error code mapping
      BEGIN OF ty_error_info,
        error_code  TYPE char3,
        severity    TYPE string,
        description TYPE string,
      END OF ty_error_info,

      "! Internal table for error codes
      ty_t_error_info TYPE STANDARD TABLE OF ty_error_info WITH KEY error_code.

    METHODS:
      "! Get error information for a given error code
      get_error_info
        IMPORTING
          iv_error_code        TYPE char3
        RETURNING
          VALUE(rs_error_info) TYPE ty_error_info,

      "! Calculate document severity based on header and items
      get_document_severity
        IMPORTING
          iv_header_error   TYPE char3
          it_items          TYPE ANY TABLE
        RETURNING
          VALUE(rv_severity) TYPE string,

      "! Calculate error count for document
      calculate_error_count
        IMPORTING
          iv_header_error    TYPE char3
          it_items           TYPE ANY TABLE
        RETURNING
          VALUE(rv_count)    TYPE i,

      "! Read vendor master data
      read_vendor_master
        IMPORTING
          iv_lifnr         TYPE lifnr
        RETURNING
          VALUE(rv_name1)  TYPE name1,

      "! Read customer master data
      read_customer_master
        IMPORTING
          iv_kunnr         TYPE kunnr
        RETURNING
          VALUE(rv_name1)  TYPE name1,

      "! Read material description
      read_material_description
        IMPORTING
          iv_matnr         TYPE matnr
        RETURNING
          VALUE(rv_maktx)  TYPE maktx,

      "! Normalize numeric fields (remove .0 suffix, handle leading zeros)
      normalize_numeric
        IMPORTING
          iv_value          TYPE any
        RETURNING
          VALUE(rv_normalized) TYPE string.

ENDCLASS.


CLASS zcl_edi_monitor_dpc_ext IMPLEMENTATION.

*&---------------------------------------------------------------------*
*& Method: EDIDOCUMENTS_GET_ENTITYSET
*& Description: Get list of EDI documents with filtering and pagination
*&---------------------------------------------------------------------*
  METHOD edidocuments_get_entityset.

    DATA:
      lt_edi_header  TYPE STANDARD TABLE OF ylo_snxt_edi_h,
      lt_edi_item    TYPE STANDARD TABLE OF ylo_snxt_edi_i,
      ls_edi_header  TYPE ylo_snxt_edi_h,
      ls_entity      TYPE zcl_edi_monitor_mpc=>ts_edidocument,
      lv_filter      TYPE /iwbep/t_mgw_name_value_pair,
      lv_top         TYPE i,
      lv_skip        TYPE i,
      lv_severity    TYPE string,
      lv_days        TYPE i,
      lv_date_from   TYPE datum.

    "---------------------------------------------------------------------
    " 1. Read Filter Parameters from URL
    "---------------------------------------------------------------------
    " Get $filter parameters (severity, days, store, vendor, etc.)
    io_tech_request_context->get_filter( )->get_filter_select_options(
      IMPORTING
        et_select_options = DATA(lt_filter_select) ).

    " Get pagination parameters ($top, $skip)
    lv_top = io_tech_request_context->get_top( ).
    lv_skip = io_tech_request_context->get_skip( ).

    IF lv_top IS INITIAL.
      lv_top = 100. " Default page size
    ENDIF.

    "---------------------------------------------------------------------
    " 2. Read EDI Header and Item Data
    "---------------------------------------------------------------------
    " Read from custom tables YLO_SNXT_EDI_H and YLO_SNXT_EDI_I
    SELECT * FROM ylo_snxt_edi_h
      INTO TABLE @lt_edi_header
      ORDER BY dndat DESCENDING, dntim DESCENDING.

    IF sy-subrc NE 0.
      " No data found - return empty set
      RETURN.
    ENDIF.

    SELECT * FROM ylo_snxt_edi_i
      INTO TABLE @lt_edi_item.

    "---------------------------------------------------------------------
    " 3. Process Each Header and Enrich with Master Data
    "---------------------------------------------------------------------
    LOOP AT lt_edi_header INTO ls_edi_header.

      CLEAR ls_entity.

      " Map header fields
      ls_entity-document_number = me->normalize_numeric( ls_edi_header-v_edi ).
      ls_entity-edi_delivery = me->normalize_numeric( ls_edi_header-w_edi ).
      ls_entity-edi_store_number = me->normalize_numeric( ls_edi_header-sendr ).
      ls_entity-error_code = me->normalize_numeric( ls_edi_header-errcd ).
      ls_entity-processing_date = ls_edi_header-dndat.
      ls_entity-processing_time = ls_edi_header-dntim.
      ls_entity-vbeln = ls_edi_header-vbeln.
      ls_entity-mblnr = ls_edi_header-mblnr.
      ls_entity-mjahr = ls_edi_header-mjahr.

      " Build ISO timestamp from date and time
      ls_entity-timestamp = |{ ls_edi_header-dndat+0(4) }-| &&
                           |{ ls_edi_header-dndat+4(2) }-| &&
                           |{ ls_edi_header-dndat+6(2) }T| &&
                           |{ ls_edi_header-dntim+0(2) }:| &&
                           |{ ls_edi_header-dntim+2(2) }:| &&
                           |{ ls_edi_header-dntim+4(2) }Z|.

      " Join with master data
      ls_entity-vendor_name = me->read_vendor_master( ls_entity-edi_delivery ).
      ls_entity-store_name = me->read_customer_master( ls_entity-edi_store_number ).

      " Get items for this document
      DATA(lt_doc_items) = VALUE ty_t_edi_item(
        FOR item IN lt_edi_item
        WHERE ( v_edi = ls_edi_header-v_edi )
        ( item ) ).

      ls_entity-item_count = lines( lt_doc_items ).

      " Calculate severity and error count
      ls_entity-severity = me->get_document_severity(
        iv_header_error = ls_entity-error_code
        it_items        = lt_doc_items ).

      ls_entity-error_count = me->calculate_error_count(
        iv_header_error = ls_entity-error_code
        it_items        = lt_doc_items ).

      " Get error description
      DATA(ls_error_info) = me->get_error_info( ls_entity-error_code ).
      ls_entity-error_description = ls_error_info-description.

      " Apply filters (if specified in URL)
      " Filter by severity
      IF lv_severity IS NOT INITIAL AND ls_entity-severity NE lv_severity.
        CONTINUE.
      ENDIF.

      " Add to result set
      APPEND ls_entity TO et_entityset.

    ENDLOOP.

    "---------------------------------------------------------------------
    " 4. Apply Pagination
    "---------------------------------------------------------------------
    IF lv_skip > 0.
      DELETE et_entityset TO lv_skip.
    ENDIF.

    IF lv_top > 0 AND lines( et_entityset ) > lv_top.
      DELETE et_entityset FROM ( lv_top + 1 ).
    ENDIF.

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& Method: EDIDOCUMENTS_GET_ENTITY
*& Description: Get single EDI document by key with items
*&---------------------------------------------------------------------*
  METHOD edidocuments_get_entity.

    DATA:
      ls_edi_header TYPE ylo_snxt_edi_h,
      lt_edi_item   TYPE STANDARD TABLE OF ylo_snxt_edi_i,
      ls_edi_item   TYPE ylo_snxt_edi_i,
      ls_item       TYPE zcl_edi_monitor_mpc=>ts_ediitem,
      lv_doc_number TYPE string.

    "---------------------------------------------------------------------
    " 1. Read Key from URL (/EDIDocuments('43681'))
    "---------------------------------------------------------------------
    io_tech_request_context->get_converted_keys(
      IMPORTING
        es_key_values = DATA(ls_key) ).

    lv_doc_number = ls_key-document_number.

    "---------------------------------------------------------------------
    " 2. Read Header
    "---------------------------------------------------------------------
    SELECT SINGLE * FROM ylo_snxt_edi_h
      INTO @ls_edi_header
      WHERE v_edi = @lv_doc_number.

    IF sy-subrc NE 0.
      " Document not found - raise exception
      RAISE EXCEPTION TYPE /iwbep/cx_mgw_busi_exception
        EXPORTING
          textid            = /iwbep/cx_mgw_busi_exception=>resource_not_found
          message           = 'Document not found'
          http_status_code  = /iwbep/cx_mgw_busi_exception=>gcs_http_status_codes-not_found.
    ENDIF.

    "---------------------------------------------------------------------
    " 3. Map Header Fields (same as GET_ENTITYSET)
    "---------------------------------------------------------------------
    er_entity-document_number = me->normalize_numeric( ls_edi_header-v_edi ).
    er_entity-edi_delivery = me->normalize_numeric( ls_edi_header-w_edi ).
    er_entity-edi_store_number = me->normalize_numeric( ls_edi_header-sendr ).
    er_entity-error_code = me->normalize_numeric( ls_edi_header-errcd ).
    er_entity-vendor_name = me->read_vendor_master( er_entity-edi_delivery ).
    er_entity-store_name = me->read_customer_master( er_entity-edi_store_number ).

    " ... (rest of mapping similar to GET_ENTITYSET)

    "---------------------------------------------------------------------
    " 4. Read Items via Navigation (expand=Items)
    "---------------------------------------------------------------------
    " This will trigger EDIITEMS_GET_ENTITYSET with filter on DocumentNumber

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& Method: EDIITEMS_GET_ENTITYSET
*& Description: Get EDI items (usually filtered by document number)
*&---------------------------------------------------------------------*
  METHOD ediitems_get_entityset.

    DATA:
      lt_edi_item    TYPE STANDARD TABLE OF ylo_snxt_edi_i,
      ls_edi_item    TYPE ylo_snxt_edi_i,
      ls_entity      TYPE zcl_edi_monitor_mpc=>ts_ediitem,
      lv_doc_number  TYPE string.

    "---------------------------------------------------------------------
    " 1. Check if filtered by DocumentNumber (from navigation)
    "---------------------------------------------------------------------
    io_tech_request_context->get_filter( )->get_filter_select_options(
      IMPORTING
        et_select_options = DATA(lt_filter) ).

    READ TABLE lt_filter WITH KEY property = 'DOCUMENTNUMBER' INTO DATA(ls_filter).
    IF sy-subrc = 0.
      READ TABLE ls_filter-select_options INDEX 1 INTO DATA(ls_option).
      lv_doc_number = ls_option-low.
    ENDIF.

    "---------------------------------------------------------------------
    " 2. Read Items from Table
    "---------------------------------------------------------------------
    IF lv_doc_number IS NOT INITIAL.
      " Filtered by document number
      SELECT * FROM ylo_snxt_edi_i
        INTO TABLE @lt_edi_item
        WHERE v_edi = @lv_doc_number.
    ELSE.
      " All items (not recommended - use with caution)
      SELECT * FROM ylo_snxt_edi_i
        INTO TABLE @lt_edi_item
        UP TO 1000 ROWS.
    ENDIF.

    "---------------------------------------------------------------------
    " 3. Map and Enrich Each Item
    "---------------------------------------------------------------------
    LOOP AT lt_edi_item INTO ls_edi_item.

      CLEAR ls_entity.

      ls_entity-document_number = me->normalize_numeric( ls_edi_item-v_edi ).
      ls_entity-item_number = ls_edi_item-refln.
      ls_entity-barcode = me->normalize_numeric( ls_edi_item-barcd ).
      ls_entity-quantity = ls_edi_item-pcqty.
      ls_entity-weight = ls_edi_item-wight.
      ls_entity-error_code = me->normalize_numeric( ls_edi_item-errcd ).
      ls_entity-expiration_date = ls_edi_item-expdt.
      ls_entity-purchase_order = ls_edi_item-ebeln.
      ls_entity-po_item = ls_edi_item-ebelp.

      " Join with material description
      ls_entity-material_description = me->read_material_description( ls_entity-barcode ).

      " Determine severity
      CASE ls_entity-error_code.
        WHEN gc_error_critical.
          ls_entity-severity = 'Error'.
        WHEN gc_warning_not_ord.
          ls_entity-severity = 'Warning'.
        WHEN OTHERS.
          ls_entity-severity = 'Success'.
      ENDCASE.

      " Get error description
      DATA(ls_error_info) = me->get_error_info( ls_entity-error_code ).
      ls_entity-error_description = ls_error_info-description.

      APPEND ls_entity TO et_entityset.

    ENDLOOP.

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& Method: DASHBOARDKPI_GET_ENTITY
*& Description: Get dashboard KPI metrics
*&---------------------------------------------------------------------*
  METHOD dashboardkpi_get_entity.

    DATA:
      lt_edi_header TYPE STANDARD TABLE OF ylo_snxt_edi_h,
      lt_edi_item   TYPE STANDARD TABLE OF ylo_snxt_edi_i,
      lv_severity   TYPE string.

    "---------------------------------------------------------------------
    " Read all headers and items
    "---------------------------------------------------------------------
    SELECT * FROM ylo_snxt_edi_h INTO TABLE @lt_edi_header.
    SELECT * FROM ylo_snxt_edi_i INTO TABLE @lt_edi_item.

    "---------------------------------------------------------------------
    " Calculate KPIs
    "---------------------------------------------------------------------
    er_entity-id = 'MAIN'.
    er_entity-total_documents = lines( lt_edi_header ).

    LOOP AT lt_edi_header INTO DATA(ls_header).

      " Get items for this document
      DATA(lt_doc_items) = VALUE ty_t_edi_item(
        FOR item IN lt_edi_item
        WHERE ( v_edi = ls_header-v_edi )
        ( item ) ).

      " Calculate severity for each document
      lv_severity = me->get_document_severity(
        iv_header_error = ls_header-errcd
        it_items        = lt_doc_items ).

      " Count by severity
      CASE lv_severity.
        WHEN 'Error'.
          er_entity-error_documents = er_entity-error_documents + 1.
        WHEN 'Warning'.
          er_entity-warning_documents = er_entity-warning_documents + 1.
        WHEN 'Success'.
          er_entity-success_documents = er_entity-success_documents + 1.
      ENDCASE.

      " Count total items
      er_entity-total_items = er_entity-total_items + lines( lt_doc_items ).

      " Count error items (only error code 104)
      er_entity-error_items = er_entity-error_items +
        REDUCE i( INIT cnt = 0
                  FOR item IN lt_doc_items
                  WHERE ( errcd = gc_error_critical )
                  NEXT cnt = cnt + 1 ).

    ENDLOOP.

    er_entity-last_update = cl_abap_tstmp=>utclong_current( ).

  ENDMETHOD.


*&---------------------------------------------------------------------*
*& Helper Methods
*&---------------------------------------------------------------------*

  METHOD get_error_info.
    " Map error codes to descriptions
    CASE iv_error_code.
      WHEN gc_error_general.
        rs_error_info = VALUE #(
          error_code  = gc_error_general
          severity    = 'Error'
          description = 'General error - entire document failed' ).
      WHEN gc_error_critical.
        rs_error_info = VALUE #(
          error_code  = gc_error_critical
          severity    = 'Error'
          description = 'Item is not listed in store assortment' ).
      WHEN gc_warning_not_ord.
        rs_error_info = VALUE #(
          error_code  = gc_warning_not_ord
          severity    = 'Warning'
          description = 'Item wasn''t ordered' ).
    ENDCASE.
  ENDMETHOD.

  METHOD get_document_severity.
    " Determine overall document severity
    " Error > Warning > Success

    IF iv_header_error = gc_error_general.
      rv_severity = 'Error'.
      RETURN.
    ENDIF.

    " Check items for errors
    DATA(lv_has_error) = abap_false.
    DATA(lv_has_warning) = abap_false.

    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<item>).
      ASSIGN COMPONENT 'ERRCD' OF STRUCTURE <item> TO FIELD-SYMBOL(<error_code>).
      IF sy-subrc = 0.
        IF <error_code> = gc_error_critical.
          lv_has_error = abap_true.
        ELSEIF <error_code> = gc_warning_not_ord.
          lv_has_warning = abap_true.
        ENDIF.
      ENDIF.
    ENDLOOP.

    IF lv_has_error = abap_true.
      rv_severity = 'Error'.
    ELSEIF lv_has_warning = abap_true.
      rv_severity = 'Warning'.
    ELSE.
      rv_severity = 'Success'.
    ENDIF.

  ENDMETHOD.

  METHOD calculate_error_count.
    " Calculate error count based on rules:
    " - Header error 28: count all items
    " - Otherwise: count only items with error code 104

    IF iv_header_error = gc_error_general.
      rv_count = lines( it_items ).
    ELSE.
      rv_count = REDUCE i( INIT cnt = 0
                           FOR item IN it_items
                           WHERE ( errcd = gc_error_critical )
                           NEXT cnt = cnt + 1 ).
    ENDIF.

  ENDMETHOD.

  METHOD read_vendor_master.
    SELECT SINGLE name1 FROM lfa1
      INTO @rv_name1
      WHERE lifnr = @iv_lifnr.

    IF sy-subrc NE 0.
      rv_name1 = 'Unknown Vendor'.
    ENDIF.
  ENDMETHOD.

  METHOD read_customer_master.
    SELECT SINGLE name1 FROM kna1
      INTO @rv_name1
      WHERE kunnr = @iv_kunnr.

    IF sy-subrc NE 0.
      rv_name1 = 'Unknown Store'.
    ENDIF.
  ENDMETHOD.

  METHOD read_material_description.
    SELECT SINGLE maktx FROM makt
      INTO @rv_maktx
      WHERE matnr = @iv_matnr
        AND spras = @sy-langu.

    IF sy-subrc NE 0.
      rv_maktx = 'Unknown Material'.
    ENDIF.
  ENDMETHOD.

  METHOD normalize_numeric.
    " Remove leading zeros and .0 suffix from numeric strings
    DATA(lv_string) = CONV string( iv_value ).

    " Remove leading zeros
    lv_string = |{ CONV numc18( lv_string ) ALPHA = OUT }|.

    " Remove .0 suffix
    IF lv_string CS '.0'.
      REPLACE '.0' IN lv_string WITH ''.
    ENDIF.

    rv_normalized = lv_string.
  ENDMETHOD.

ENDCLASS.

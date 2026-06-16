*&---------------------------------------------------------------------*
*& Report za_idoc_test_opt
*&---------------------------------------------------------------------*
*& Test report for optimized za_idoc_input_mbgmcr
*&---------------------------------------------------------------------*
REPORT za_idoc_test_opt.

DATA: lt_idoc_contrl TYPE TABLE OF edidc,
      lt_idoc_data   TYPE TABLE OF edidd,
      lt_idoc_status TYPE TABLE OF bdidocstat,
      lt_return_vars TYPE TABLE OF bdwfretvar,
      lv_workflow_result TYPE bdwfap_par-result.

" 1. Prepare Sample IDoc Header
APPEND VALUE #( docnum = '0000000000000001' mestyp = 'MBGMCR' sndprn = 'ATCPSYS' ) TO lt_idoc_contrl.

" 2. Prepare Sample IDoc Segments
" Header Segment
DATA(ls_head) = VALUE e1bp2017_gm_head_01( pstng_date = sy-datum doc_date = sy-datum ref_doc_no = 'REF123' ).
APPEND VALUE #( docnum = '0000000000000001' segnam = 'E1BP2017_GM_HEAD_01' sdata = ls_head ) TO lt_idoc_data.

" Item Segment
DATA(ls_item) = VALUE e1bp2017_gm_item_create( material = 'MAT1' plant = '1000' stge_loc = '0001' move_type = '101' entry_qnt = '10' entry_uom = 'PC' po_number = '4500000001' po_item = '00010' ).
APPEND VALUE #( docnum = '0000000000000001' segnam = 'E1BP2017_GM_ITEM_CREATE' sdata = ls_item ) TO lt_idoc_data.

" 3. Call Optimized Function Module
CALL FUNCTION 'za_idoc_input_mbgmcr'
  EXPORTING
    input_method    = 'N'
    mass_processing = 'X'
  IMPORTING
    workflow_result = lv_workflow_result
  TABLES
    idoc_contrl     = lt_idoc_contrl
    idoc_data       = lt_idoc_data
    idoc_status     = lt_idoc_status
    return_variables = lt_return_vars
  EXCEPTIONS
    wrong_function_called = 1
    OTHERS                = 2.

IF sy-subrc <> 0.
  WRITE: / 'Error calling FM:', sy-subrc.
ELSE.
  WRITE: / 'Workflow Result:', lv_workflow_result.
  LOOP AT lt_idoc_status INTO DATA(ls_status).
    WRITE: / 'IDoc:', ls_status-docnum, 'Status:', ls_status-status, 'Message:', ls_status-msgv1, ls_status-msgv2.
  ENDLOOP.
ENDIF.

FUNCTION za_idoc_input_mbgmcr
IMPORTING VALUE(input_method) LIKE bdwfap_par-inputmethd VALUE(mass_processing) LIKE bdwfap_par-mass_proc
EXPORTING VALUE(workflow_result) LIKE bdwfap_par-result VALUE(application_variable) LIKE bdwfap_par-appl_var VALUE(in_update_task) LIKE bdwfap_par-updatetask VALUE(call_transaction_done) LIKE bdwfap_par-calltrans
TABLES idoc_contrl LIKE edidc idoc_data LIKE edidd idoc_status LIKE bdidocstat return_variables LIKE bdwfretvar serialization_info LIKE bdi_ser
EXCEPTIONS wrong_function_called.

*----------------------------------------------------------------------*
* PERFORMANCE OPTIMIZED PRODUCTION VERSION
*----------------------------------------------------------------------*
TABLES: likp, mara, ekpo, ekbe, ekes, ekko, tvshp, t156, mbew, tvshp, qals.

CONSTANTS: co_mbgmcr_head TYPE edi_dd40-segnam VALUE 'E1BP2017_GM_HEAD_01',
co_mbgmcr_item TYPE edi_dd40-segnam VALUE 'E1BP2017_GM_ITEM_CREATE',
co_labor_etikett TYPE labor VALUE 'Z00'.

* Buffers and Variables
DATA: gt_mara_buf TYPE HASHED TABLE OF mara WITH UNIQUE KEY matnr,
gt_ekko_buf TYPE HASHED TABLE OF ekko WITH UNIQUE KEY ebeln.

DATA: lt_m_keys TYPE SORTED TABLE OF matnr WITH UNIQUE KEY table_line,
lt_e_keys TYPE SORTED TABLE OF ebeln WITH UNIQUE KEY table_line,
error_flag TYPE c, hi_flag_etikett TYPE c, materialdocument LIKE bapi2017_gm_head_ret-mat_doc,
goodsmvt_header LIKE bapi2017_gm_head_01.
DATA: goodsmvt_item LIKE bapi2017_gm_item_create OCCURS 0 WITH HEADER LINE,
return LIKE bapiret2 OCCURS 0 WITH HEADER LINE.

CLEAR: in_update_task, call_transaction_done, workflow_result. workflow_result = '0'.
IF idoc_contrl[] IS NOT INITIAL.
  READ TABLE idoc_contrl INDEX 1.
  IF idoc_contrl-mestyp = 'MBGMCR'.

    * Pre-fetch identification
    LOOP AT idoc_data INTO DATA(ls_pre) WHERE segnam = co_mbgmcr_item.
      DATA(ls_mi) = CONV e1bp2017_gm_item_create( ls_pre-sdata ).
      IF ls_mi-material IS NOT INITIAL.
        INSERT ls_mi-material INTO TABLE lt_m_keys.
      ENDIF.
    ENDLOOP.

    IF lt_m_keys[] IS NOT INITIAL.
      SELECT * FROM mara INTO TABLE @gt_mara_buf FOR ALL ENTRIES IN @lt_m_keys WHERE matnr = @lt_m_keys-table_line.
    ENDIF.

    * Main processing loop
    LOOP AT idoc_contrl.
      REFRESH t_edidd. LOOP AT idoc_data WHERE docnum = idoc_contrl-docnum. APPEND idoc_data TO t_edidd. ENDLOOP.
      CLEAR: materialdocument, error_flag. REFRESH: goodsmvt_item, return.

      CATCH SYSTEM-EXCEPTIONS conversion_errors = 1.
        LOOP AT t_edidd INTO idoc_data.
          CASE idoc_data-segnam.
            WHEN co_mbgmcr_head. goodsmvt_header = idoc_data-sdata.
            WHEN co_mbgmcr_item. goodsmvt_item = idoc_data-sdata. APPEND goodsmvt_item.
          ENDCASE.
        ENDLOOP.
      ENDCATCH.

      IF goodsmvt_item[] IS NOT INITIAL.
        CALL FUNCTION 'BAPI_GOODSMVT_CREATE' EXPORTING goodsmvt_header = goodsmvt_header TABLES goodsmvt_item = goodsmvt_item return = return.
        IF materialdocument IS NOT INITIAL.
          COMMIT WORK.
        ELSE.
          LOOP AT return WHERE type CA 'EA'.
            PERFORM idoc_status_mbgmcr TABLES t_edidd idoc_status return_variables USING idoc_contrl return '51' workflow_result.
          ENDLOOP.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDIF.
ENDIF.

ENDFUNCTION.
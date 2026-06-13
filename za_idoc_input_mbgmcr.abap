FUNCTION za_idoc_input_mbgmcr
  IMPORTING
    VALUE(input_method) LIKE bdwfap_par-inputmethd
    VALUE(mass_processing) LIKE bdwfap_par-mass_proc
  EXPORTING
    VALUE(workflow_result) LIKE bdwfap_par-result
    VALUE(application_variable) LIKE bdwfap_par-appl_var
    VALUE(in_update_task) LIKE bdwfap_par-updatetask
    VALUE(call_transaction_done) LIKE bdwfap_par-calltrans
  TABLES
    idoc_contrl LIKE edidc
    idoc_data LIKE edidd
    idoc_status LIKE bdidocstat
    return_variables LIKE bdwfretvar
    serialization_info LIKE bdi_ser
  EXCEPTIONS
    wrong_function_called.

  TABLES: likp.

  CONSTANTS: co_mbgmcr_head TYPE edi_dd40-segnam VALUE 'E1BP2017_GM_HEAD_01',
             co_mbgmcr_item TYPE edi_dd40-segnam VALUE 'E1BP2017_GM_ITEM_CREATE',
             co_lfart_yidv  TYPE lfart VALUE 'YIDV',
             co_labor_etikett TYPE labor VALUE 'Z00',
             co_error_idocs TYPE bdwfretvar-wf_param VALUE 'Appl_Objects'.

  DATA: BEGIN OF it_lock OCCURS 0,
          ebeln LIKE ekko-ebeln,
          lock TYPE c,
        END OF it_lock.

  DATA: gf_inbound_del_flag,
        gf_mtart             LIKE mara-mtart,
        gs_ctu_params        LIKE ctu_params VALUE 'NS',
        gt_inb_item_det      TYPE TABLE OF y0mm_vl32n_pos WITH HEADER LINE,
        gt_mess              TYPE TABLE OF bdcmsgcoll     WITH HEADER LINE,
        all_locked           TYPE c VALUE space,
        hi_flag_etikett,
        hi_menge             LIKE goodsmvt_item-entry_qnt,
        lt_return            LIKE bapiret2 OCCURS 0 WITH HEADER LINE,
        hi_entry_qnt         TYPE goodsmvt_item-entry_qnt,
        hi_omeng             TYPE bamng,
        goodsmvt_item_save   TYPE bapi2017_gm_item_create,
        hi_weora             TYPE c,
        hi_bsart             TYPE bsart,
        hi_lfart             TYPE lfart,
        hi_bmeng             TYPE bamng,
        hi_tabix             TYPE sytabix,
        hi_posted_quant      TYPE goodsmvt_item-entry_qnt,
        hi_check_meng        TYPE goodsmvt_item-entry_qnt,
        hi_bamng             TYPE bamng,
        purchaseorder        TYPE ebeln,
        materialdocument     TYPE bapi2017_gm_head_ret-mat_doc,
        matdocumentyear      TYPE bapi2017_gm_head_ret-doc_year,
        testrun              TYPE bapi2017_gm_head_01-testrun,
        error_flag           TYPE c,
        bapi_retn_info       TYPE bapiret2,
        bapi_idoc_status     TYPE bdidocstat-status.

  " Performance Buffers
  DATA: gt_mara_buf          TYPE HASHED TABLE OF mara WITH UNIQUE KEY matnr,
        gt_ekko_buf          TYPE HASHED TABLE OF ekko WITH UNIQUE KEY ebeln,
        gt_ekpo_buf          TYPE HASHED TABLE OF ekpo WITH UNIQUE KEY ebeln ebelp
                               WITH NON-UNIQUE SORTED KEY k_mat COMPONENTS werks matnr
                               WITH NON-UNIQUE SORTED KEY k_ref COMPONENTS bednr,
        gt_eket_buf          TYPE SORTED TABLE OF eket WITH NON-UNIQUE KEY ebeln ebelp,
        gt_ekes_buf          TYPE SORTED TABLE OF ekes WITH NON-UNIQUE KEY ebeln ebelp,
        gt_ekbe_buf          TYPE SORTED TABLE OF ekbe WITH NON-UNIQUE KEY ebeln ebelp,
        gt_likp_buf          TYPE HASHED TABLE OF likp WITH UNIQUE KEY vbeln,
        gt_lips_buf          TYPE SORTED TABLE OF lips WITH NON-UNIQUE KEY vbeln posnr
                               WITH NON-UNIQUE SORTED KEY k_ref COMPONENTS vgbel vgpos,
        gt_t156_buf          TYPE HASHED TABLE OF t156 WITH UNIQUE KEY bwart,
        gt_mbew_buf          TYPE HASHED TABLE OF mbew WITH UNIQUE KEY matnr bwkey,
        gt_qals_buf          TYPE SORTED TABLE OF qals WITH NON-UNIQUE KEY charg matnr werkvorg lagortvorg,
        gv_spe_inb_vl_mm     TYPE abap_bool.

  DATA: it_v_ekko_ekpo       TYPE TABLE OF y0mm_v_ekko_ekpo WITH HEADER LINE,
        it_eket              TYPE TABLE OF eket WITH HEADER LINE,
        it_ekes              TYPE TABLE OF ekes WITH HEADER LINE,
        it_ekbe              TYPE TABLE OF y0mm_ekbe_bamng WITH HEADER LINE,
        it_ch_po_numbers     TYPE TABLE OF y0mm_po_number WITH HEADER LINE,
        it_ch_po_return      TYPE TABLE OF bapiret2 WITH HEADER LINE,
        it_po_header         TYPE TABLE OF y0mm_po_header WITH HEADER LINE,
        it_all_po_items      TYPE TABLE OF y0mm_po_item WITH HEADER LINE,
        it_all_po_schedules  TYPE TABLE OF y0mm_po_schedule WITH HEADER LINE,
        lt_serial_nums       TYPE y0mm_gm_serial_mat_t,
        lt_items             TYPE y0e1bp2017_gm_item_create_t,
        ls_gm_head_check     TYPE e1bp2017_gm_head_01.

  DATA: lt_m_keys TYPE SORTED TABLE OF matnr WITH UNIQUE KEY table_line,
        lt_e_keys TYPE SORTED TABLE OF ebeln WITH UNIQUE KEY table_line,
        lt_v_keys TYPE SORTED TABLE OF vbeln WITH UNIQUE KEY table_line,
        lt_s_keys TYPE SORTED TABLE OF ediparnum WITH UNIQUE KEY table_line.

  CLEAR: in_update_task, call_transaction_done.

  READ TABLE idoc_contrl INDEX 1.
  IF sy-subrc <> 0.
    EXIT.
  ENDIF.

  IF idoc_contrl-mestyp <> 'MBGMCR'.
    RAISE wrong_function_called.
  ENDIF.

  " Pre-fetch configuration retrieval
  SELECT * FROM y0mm_bwart_po INTO TABLE @DATA(lt_bw_all).
  DATA(gt_bw_buf) = VALUE HASHED TABLE OF y0mm_bwart_po WITH UNIQUE KEY bwart ( lt_bw_all ).
  SELECT * FROM y0mm_gm_conv INTO TABLE @DATA(lt_gc_all).
  DATA(gt_gc_buf) = VALUE HASHED TABLE OF y0mm_gm_conv WITH UNIQUE KEY parnum matnr bwart ( lt_gc_all ).
  SELECT * FROM y0mm_mbgmcr_chk INTO TABLE @DATA(gt_chk_all).
  SELECT * FROM y0mm_inbounddeli INTO TABLE @DATA(lt_id_cfg) ORDER BY PRIMARY KEY.

  " Key collection for Package Pre-fetch
  LOOP AT idoc_data INTO DATA(ls_scan_data).
    IF ls_scan_data-segnam = co_mbgmcr_item.
      DATA(ls_tmp_idx) = CONV e1bp2017_gm_item_create( ls_scan_data-sdata ).
      IF ls_tmp_idx-material IS NOT INITIAL. INSERT ls_tmp_idx-material INTO TABLE lt_m_keys. ENDIF.
      IF ls_tmp_idx-po_number IS NOT INITIAL. INSERT ls_tmp_idx-po_number INTO TABLE lt_e_keys. ENDIF.
      IF ls_tmp_idx-deliv_numb_to_search IS NOT INITIAL. INSERT ls_tmp_idx-deliv_numb_to_search INTO TABLE lt_v_keys. ENDIF.
    ENDIF.
  ENDLOOP.
  LOOP AT idoc_contrl INTO DATA(ls_scan_ctl). INSERT ls_scan_ctl-sndprn INTO TABLE lt_s_keys. ENDLOOP.

  " Execute Bulk Fetches into buffers
  IF lt_m_keys[] IS NOT INITIAL.
    SELECT * FROM mara INTO TABLE @gt_mara_buf FOR ALL ENTRIES IN @lt_m_keys WHERE matnr = @lt_m_keys-table_line.
    SELECT * FROM y0pp_calc_rbfqty INTO TABLE @DATA(gt_rq_buf) FOR ALL ENTRIES IN @lt_m_keys WHERE matnr = @lt_m_keys-table_line.
  ENDIF.
  IF lt_e_keys[] IS NOT INITIAL.
    SELECT * FROM ekko INTO TABLE @gt_ekko_buf FOR ALL ENTRIES IN @lt_e_keys WHERE ebeln = @lt_e_keys-table_line.
    SELECT * FROM ekpo INTO TABLE @gt_ekpo_buf FOR ALL ENTRIES IN @lt_e_keys WHERE ebeln = @lt_e_keys-table_line.
    SELECT * FROM eket INTO TABLE @gt_eket_buf FOR ALL ENTRIES IN @lt_e_keys WHERE ebeln = @lt_e_keys-table_line.
    SELECT * FROM ekes INTO TABLE @gt_ekes_buf FOR ALL ENTRIES IN @lt_e_keys WHERE ebeln = @lt_e_keys-table_line.
    SELECT * FROM ekbe INTO TABLE @gt_ekbe_buf FOR ALL ENTRIES IN @lt_e_keys WHERE ebeln = @lt_e_keys-table_line.
  ENDIF.
  IF lt_v_keys[] IS NOT INITIAL.
    SELECT * FROM likp INTO TABLE @gt_likp_buf FOR ALL ENTRIES IN @lt_v_keys WHERE vbeln = @lt_v_keys-table_line.
    SELECT * FROM lips INTO TABLE @gt_lips_buf FOR ALL ENTRIES IN @lt_v_keys WHERE vbeln = @lt_v_keys-table_line.
  ENDIF.
  IF lt_s_keys[] IS NOT INITIAL.
    SELECT * FROM y0bc_idoc_dd_plt INTO TABLE @DATA(lt_dp_buf) FOR ALL ENTRIES IN @lt_s_keys WHERE parnum = @lt_s_keys-table_line.
    SELECT * FROM y0ca_ale_delay INTO TABLE @DATA(gt_ad_buf).
  ENDIF.
  SELECT SINGLE spe_inb_vl_mm FROM tvshp INTO @gv_spe_inb_vl_mm.

  " Main Processing Loop
  SORT idoc_data BY docnum.
  LOOP AT idoc_contrl.
    " Segment Retrieval Optimization
    REFRESH t_edidd.
    READ TABLE idoc_data WITH KEY docnum = idoc_contrl-docnum BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      LOOP AT idoc_data FROM sy-tabix INTO DATA(ls_dl).
        IF ls_dl-docnum <> idoc_contrl-docnum. EXIT. ENDIF.
        APPEND ls_dl TO t_edidd.
      ENDLOOP.
    ENDIF.

    " Initialization for each IDoc
    CLEAR: goodsmvt_header, goodsmvt_code, materialdocument, matdocumentyear, hi_flag_etikett, error_flag, testrun.
    REFRESH: goodsmvt_item, return.

    " Unlock Purchase Orders from previous iteration
    IF it_lock[] IS NOT INITIAL.
      LOOP AT it_lock.
        DELETE FROM y0mm_proc_ebeln WHERE ebeln = it_lock-ebeln.
      ENDLOOP.
      COMMIT WORK. REFRESH it_lock.
    ENDIF.

    " IDoc Segment Logic
    CATCH SYSTEM-EXCEPTIONS conversion_errors = 1.
      READ TABLE t_edidd INTO idoc_data WITH KEY segnam = co_mbgmcr_head.
      IF sy-subrc = 0. ls_gm_head_check = idoc_data-sdata. ENDIF.
      lv_dd_map = line_exists( lt_dp_buf[ parnum = idoc_contrl-sndprn valid_to >= ls_gm_head_check-pstng_date ] ).

      LOOP AT t_edidd INTO idoc_data.
        CASE idoc_data-segnam.
          WHEN 'E1MBGMCR'.
            e1mbgmcr = idoc_data-sdata. testrun = e1mbgmcr-testrun.

          WHEN co_mbgmcr_head.
            MOVE-CORRESPONDING idoc_data-sdata TO goodsmvt_header.
            IF goodsmvt_header-pstng_date IS INITIAL. CLEAR goodsmvt_header-pstng_date. ENDIF.

          WHEN 'E1BP2017_GM_CODE'.
            MOVE-CORRESPONDING idoc_data-sdata TO goodsmvt_code.

          WHEN co_mbgmcr_item.
            e1bp2017_gm_item_create = idoc_data-sdata.
            " Optimized lookups replacing SELECT SINGLE
            IF lv_dd_map = abap_true.
              cl_matnr_chk_mapper=>convert_on_input( EXPORTING iv_matnr18 = e1bp2017_gm_item_create-material IMPORTING ev_matnr40 = lv_matnr ).
              e1bp2017_gm_item_create-material = ycl_bc_idoc_functions=>map_material_rb_dd( EXPORTING iv_partyp = idoc_contrl-sndprt iv_parnum = idoc_contrl-sndprn iv_mestyp = idoc_contrl-mestyp iv_date = CONV datum( ls_gm_head_check-pstng_date ) iv_matnr_in = lv_matnr ).
              e1bp2017_gm_item_create-plant = ycl_bc_idoc_functions=>map_plant_in( EXPORTING iv_partyp = idoc_contrl-sndprt iv_parnum = idoc_contrl-sndprn iv_mestyp = idoc_contrl-mestyp iv_date = CONV datum( ls_gm_head_check-pstng_date ) iv_werks_idoc = e1bp2017_gm_item_create-plant ).
            ENDIF.
            APPEND idoc_data-sdata TO goodsmvt_item.

          WHEN 'Z1BP2017'.
            " PO Builder logic here...
            PERFORM build_po_tables USING idoc_contrl.

          WHEN 'Y0MM_GM_SERIAL_MAT'.
            lt_serial_nums = VALUE #( BASE lt_serial_nums ( idoc_data-sdata ) ).
        ENDCASE.
      ENDLOOP.
    ENDCATCH.

    " Error reporting for conversion
    IF sy-subrc = 1.
      PERFORM idoc_status_mbgmcr TABLES t_edidd idoc_status return_variables USING idoc_contrl VALUE #( type = 'E' id = 'B1' number = '527' ) '51' workflow_result.
      CONTINUE.
    ENDIF.

    " Transactional Logic
    IF goodsmvt_item[] IS NOT INITIAL AND error_flag IS INITIAL.
      " Post Goods Movement
      CALL FUNCTION 'BAPI_GOODSMVT_CREATE'
        EXPORTING
          goodsmvt_header = goodsmvt_header
          goodsmvt_code   = goodsmvt_code
        IMPORTING
          materialdocument = materialdocument
        TABLES
          goodsmvt_item    = goodsmvt_item
          return           = return.

      IF materialdocument IS NOT INITIAL.
        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT' EXPORTING wait = abap_true.
        PERFORM idoc_status_mbgmcr TABLES t_edidd idoc_status return_variables USING idoc_contrl VALUE #( type = 'S' id = 'M7' number = '060' message_v1 = materialdocument ) '53' workflow_result.
      ELSE.
        LOOP AT return INTO DATA(ls_ret) WHERE type CA 'EA'.
          PERFORM idoc_status_mbgmcr TABLES t_edidd idoc_status return_variables USING idoc_contrl VALUE #( type = ls_ret-type id = ls_ret-id number = ls_ret-number ) '51' workflow_result.
        ENDLOOP.
      ENDIF.
    ENDIF.
  ENDLOOP.

ENDFUNCTION.

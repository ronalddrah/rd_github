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




* local data
  TABLES:  likp.                                            "$TP220206

  CONSTANTS: co_mbgmcr_head TYPE edi_dd40-segnam VALUE 'E1BP2017_GM_HEAD_01',
             co_mbgmcr_item TYPE edi_dd40-segnam VALUE 'E1BP2017_GM_ITEM_CREATE'.

  DATA: BEGIN OF it_lock OCCURS 0,
          ebeln LIKE ekko-ebeln,
          lock  TYPE c,
        END OF it_lock,
        gf_inbound_del_flag,                                "$TP220206
        gf_mtart            LIKE mara-mtart,                "$TP220206
        gs_ctu_params       LIKE  ctu_params  VALUE 'NS',   "$TP220206
        BEGIN OF  gt_inb_item OCCURS 0,                     "$TP220206
          vbeln LIKE likp-vbeln.                            "$TP220206
          INCLUDE STRUCTURE y0mm_vl32n_pos.                 "$TP220206
  DATA:   END OF gt_inb_item,                         "$TP220206
  gt_inb_item_det LIKE y0mm_vl32n_pos                       "$TP220206
      OCCURS 0 WITH HEADER LINE,                          "$TP220206
    gt_mess         LIKE  bdcmsgcoll                        "$TP220206
            OCCURS 0 WITH HEADER LINE,                  "$TP220206
    all_locked      TYPE c VALUE space,
    hi_flag_etikett,
    hi_menge        LIKE goodsmvt_item-entry_qnt,           "RD120406
    lt_return       LIKE bapiret2 OCCURS 0 WITH HEADER LINE.

  DATA: wa_ekbe  LIKE ekbe,
        wa_ekes  LIKE ekes,                                 "$TP220206
        wa_mseg  LIKE mseg,
        wa_marc  LIKE marc,
        hi_labst LIKE mard-labst.
  DATA: lk_tr_posted TYPE i.
  DATA: hi_arckey LIKE edidc-arckey.

* RBDC
  DATA: wa_run_i LIKE yudc_int_run_i,
        l_bwkey  TYPE bwkey,
        l_bukrs  TYPE bukrs.

  DATA: lv_dd_map TYPE abap_bool.
  DATA lv_matnr TYPE matnr.

  DATA: ls_poheader     TYPE  bapimepoheader,
        ls_poheaderx    TYPE bapimepoheaderx,
        ls_poaddrvendor TYPE bapimepoaddrvendor.
  DATA: ls_po_header_add_data TYPE bapiekkoa,
        ls_po_address         TYPE bapiaddress.
  DATA: lt_poitem                     TYPE TABLE OF bapimepoitem,
        lt_poitemx                    TYPE TABLE OF bapimepoitemx,
        lt_poschedule                 TYPE TABLE OF bapimeposchedule,
        lt_poschedulex                TYPE TABLE OF bapimeposchedulx,
        lt_return_po                  TYPE TABLE OF bapiret2,
        lt_po_item_add_data           TYPE TABLE OF bapiekpoa,
        lt_po_item_account_assignment TYPE TABLE OF bapiekkn,
        lt_po_item_text               TYPE TABLE OF bapiekpotx,
        lt_poaccount                  TYPE TABLE OF bapimepoaccount,
        lt_poaccountx                 TYPE TABLE OF bapimepoaccountx,
        lt_potextitem                 TYPE TABLE OF bapimepotext.

  DATA: BEGIN OF ls_po_ref,
          vgbel TYPE lips-vgbel,
          vgpos TYPE lips-vgpos,
        END OF ls_po_ref,
        lt_po_ref LIKE TABLE OF ls_po_ref.

  TYPES: ty_ebeln_tt TYPE SORTED TABLE OF ebeln WITH UNIQUE KEY table_line.
  DATA: lt_mara_pre   TYPE STANDARD TABLE OF mara,
        lt_ekko_pre   TYPE STANDARD TABLE OF ekko,
        lt_ekpo_pre   TYPE STANDARD TABLE OF ekpo,
        lt_likp_pre   TYPE STANDARD TABLE OF likp,
        lt_t001w_pre  TYPE STANDARD TABLE OF t001w,
        lt_t001k_pre  TYPE STANDARD TABLE OF t001k,
        lt_mbew_pre   TYPE STANDARD TABLE OF mbew.
  DATA: lv_ebumg_bme   TYPE ebumng_bme,
        lv_ebumg_vme   TYPE ebumng,
        ls_vbkok       TYPE vbkok,
        ls_vbpok       TYPE vbpok,
        lt_vbpok       TYPE vbpok_t,
        lt_vbpok_upd   TYPE vbpok_t,
        lt_prot        TYPE tab_prott,
        lt_items       TYPE y0e1bp2017_gm_item_create_t,
        lt_serial_nums TYPE y0mm_gm_serial_mat_t.

  DATA: lv_matnr40 TYPE mara-matnr.

  "GR for IBDs with HU managed SLOCS
  DATA: lt_deliv    TYPE STANDARD TABLE OF ship_deliv,
        lt_hu_head  TYPE hum_hu_header_t,
        lt_hu_items TYPE hum_hu_item_t,
        lt_objects  TYPE lepgr_objects,
        BEGIN OF ls_vbeln_hu,
          vbeln TYPE vbeln_vl,
          exidv TYPE exidv,
        END OF ls_vbeln_hu,
        lt_vbeln_hu LIKE TABLE OF ls_vbeln_hu.

  DATA: ls_gm_head_check TYPE e1bp2017_gm_head_01.

  DATA: ls_mbgmcr_head TYPE E1BP2017_GM_HEAD_01,
        ls_mbgmcr_item TYPE E1BP2017_GM_ITEM_CREATE.

  " Buffers for performance optimization
  DATA: gt_mara_buf            TYPE HASHED TABLE OF mara WITH UNIQUE KEY matnr,
        gt_ekko_buf            TYPE HASHED TABLE OF ekko WITH UNIQUE KEY ebeln,
        gt_ekpo_buf            TYPE HASHED TABLE OF ekpo WITH UNIQUE KEY ebeln ebelp
                                    WITH NON-UNIQUE SORTED KEY k_bednr COMPONENTS bednr,
        gt_eket_buf            TYPE SORTED TABLE OF eket WITH NON-UNIQUE KEY ebeln ebelp,
        gt_ekes_buf            TYPE SORTED TABLE OF ekes WITH NON-UNIQUE KEY ebeln ebelp,
        gt_ekbe_buf            TYPE SORTED TABLE OF ekbe WITH NON-UNIQUE KEY ebeln ebelp matnr werks xblnr,
        gt_likp_buf            TYPE HASHED TABLE OF likp WITH UNIQUE KEY vbeln,
        gt_lips_buf            TYPE SORTED TABLE OF lips WITH NON-UNIQUE KEY vbeln posnr
                                    WITH NON-UNIQUE SORTED KEY k_ref COMPONENTS vgbel vgpos,
        gt_t156_buf            TYPE HASHED TABLE OF t156 WITH UNIQUE KEY bwart,
        gt_t001w_buf           TYPE HASHED TABLE OF t001w WITH UNIQUE KEY werks,
        gt_t001k_buf           TYPE HASHED TABLE OF t001k WITH UNIQUE KEY bwkey,
        gt_t001l_buf           TYPE HASHED TABLE OF t001l WITH UNIQUE KEY werks lgort,
        gt_mbew_buf            TYPE HASHED TABLE OF mbew WITH UNIQUE KEY matnr bwkey,
        gt_qals_buf            TYPE SORTED TABLE OF qals WITH NON-UNIQUE KEY charg matnr werkvorg lagortvorg,
        gt_yudc_trans_buf      TYPE HASHED TABLE OF yudc_trans WITH UNIQUE KEY bukrs gm_code lgort_from bwart lgort_to,
        gt_y0ca_ale_delay_buf  TYPE HASHED TABLE OF y0ca_ale_delay WITH UNIQUE KEY mesty,
        gt_y0mm_migo_weora_buf TYPE HASHED TABLE OF y0mm_migo_weora WITH UNIQUE KEY rcvpor,
        gt_y0mm_mbgmcr_tr_buf  TYPE HASHED TABLE OF y0mm_mbgmcr_tr WITH UNIQUE KEY sndprn transfer move_type stck_type,
        gt_ybrmm_idoc_tr_buf   TYPE HASHED TABLE OF ybrmm_idoc_tr WITH UNIQUE KEY mestyp werks lgort,
        gt_y0bc_idoc_dd_plt_buf TYPE SORTED TABLE OF y0bc_idoc_dd_plt WITH NON-UNIQUE KEY partyp parnum mestyp,
        gt_y0mm_gm_matnrcnv_buf TYPE HASHED TABLE OF y0mm_gm_matnrcnv WITH UNIQUE KEY sndprn,
        gt_y0pp_calc_rbfqty_buf TYPE HASHED TABLE OF y0pp_calc_rbfqty WITH UNIQUE KEY matnr,
        gt_y0mm_gm_lifnrcnv_buf TYPE HASHED TABLE OF y0mm_gm_lifnrcnv WITH UNIQUE KEY sndprn lifnr_ext,
        gt_y0mm_proc_ebeln_buf  TYPE HASHED TABLE OF y0mm_proc_ebeln WITH UNIQUE KEY ebeln,
        gt_yusmm_mbgmcr_lib_buf TYPE HASHED TABLE OF yusmm_mbgmcr_lib WITH UNIQUE KEY sndprn,
        gv_spe_inb_vl_mm       TYPE abap_bool.

  CLEAR in_update_task.
  CLEAR call_transaction_done.
* check if the function is called correctly                            *
  READ TABLE idoc_contrl INDEX 1.
  IF sy-subrc <> 0.
    EXIT.
  ELSEIF idoc_contrl-mestyp <> 'MBGMCR'.
    RAISE wrong_function_called.
  ENDIF.

* check for duplicates
  IF line_exists( idoc_data[ segnam = co_mbgmcr_head ] ) AND
     line_exists( idoc_data[ segnam = co_mbgmcr_item ] ).
    ls_mbgmcr_head = idoc_data[ segnam = co_mbgmcr_head ]-sdata.
    ls_mbgmcr_item = idoc_data[ segnam = co_mbgmcr_item ]-sdata.
    DATA(check_result) = y0mm_cl_inbound_idoc_checks=>duplicate_check(
                           idoc_header         = idoc_contrl
                           segment_mbgmcr_item = ls_mbgmcr_item
                           segment_mbgmcr_head = ls_mbgmcr_head
                         ).
    IF line_exists( check_result[ type = 'E' ] ).
      DATA(result_line) = check_result[ type = 'E' ].
      PERFORM insert_status USING '51'
                                  result_line-type
                                  result_line-id
                                  result_line-number
                                  result_line-message_v1
                                  result_line-message_v2
                                  result_line-message_v3
                                  result_line-message_v4.
      EXIT.
    ENDIF.
  ENDIF.

* get customer customizing
  SELECT * FROM y0mm_bwart_po INTO TABLE it_bwart_po.
  SELECT * FROM y0mm_po_fixval INTO TABLE it_po_fixval.
  SELECT * FROM y0mm_gm_conv INTO TABLE it_gm_conv.
  SELECT * FROM y0mm_gmpo_noinv INTO TABLE it_noinv.
  SELECT * FROM y0mm_mbgmcr_chk INTO TABLE @DATA(gt_mbgmcr_chk).

  SELECT * FROM y0mm_inbounddeli                            "$TP220206
           INTO TABLE it_y0mm_inbounddeli                   "$TP220206
            ORDER BY PRIMARY KEY.                           "$TP220206

  " Optimize segment retrieval by sorting
  SORT idoc_data STABLE BY docnum.

  " --- PRE-FETCH LOGIC BEGIN ---
  DATA: lt_matnr_keys TYPE SORTED TABLE OF matnr WITH UNIQUE KEY table_line,
        lt_ebeln_keys TYPE SORTED TABLE OF ebeln WITH UNIQUE KEY table_line,
        lt_vbeln_keys TYPE SORTED TABLE OF vbeln WITH UNIQUE KEY table_line,
        lt_lifnr_keys TYPE SORTED TABLE OF lifnr WITH UNIQUE KEY table_line,
        lt_werks_keys TYPE SORTED TABLE OF werks WITH UNIQUE KEY table_line,
        lt_bwkey_keys TYPE SORTED TABLE OF bwkey WITH UNIQUE KEY table_line.

  LOOP AT idoc_data INTO DATA(ls_prefetch_data) WHERE segnam = co_mbgmcr_item.
    ls_mbgmcr_item = ls_prefetch_data-sdata.
    INSERT ls_mbgmcr_item-material INTO TABLE lt_matnr_keys.
    IF ls_mbgmcr_item-move_mat IS NOT INITIAL.
      INSERT ls_mbgmcr_item-move_mat INTO TABLE lt_matnr_keys.
    ENDIF.
    IF ls_mbgmcr_item-po_number IS NOT INITIAL.
      INSERT ls_mbgmcr_item-po_number INTO TABLE lt_ebeln_keys.
    ENDIF.
    IF ls_mbgmcr_item-deliv_numb_to_search IS NOT INITIAL.
      INSERT ls_mbgmcr_item-deliv_numb_to_search INTO TABLE lt_vbeln_keys.
    ENDIF.
    IF ls_mbgmcr_item-vendor IS NOT INITIAL.
      INSERT ls_mbgmcr_item-vendor INTO TABLE lt_lifnr_keys.
    ENDIF.
    INSERT ls_mbgmcr_item-plant INTO TABLE lt_werks_keys.
    IF ls_mbgmcr_item-move_plant IS NOT INITIAL.
      INSERT ls_mbgmcr_item-move_plant INTO TABLE lt_werks_keys.
    ENDIF.
  ENDLOOP.

  " Fetch document data in bulk
  IF lt_matnr_keys IS NOT INITIAL.
    SELECT * FROM mara INTO TABLE @lt_mara_pre
      FOR ALL ENTRIES IN @lt_matnr_keys WHERE matnr = @lt_matnr_keys-table_line.
    gt_mara_buf = lt_mara_pre.
  ENDIF.

  IF lt_ebeln_keys IS NOT INITIAL.
    SELECT * FROM ekko INTO TABLE @lt_ekko_pre
      FOR ALL ENTRIES IN @lt_ebeln_keys WHERE ebeln = @lt_ebeln_keys-table_line.
    SELECT * FROM ekpo INTO TABLE @lt_ekpo_pre
      FOR ALL ENTRIES IN @lt_ebeln_keys WHERE ebeln = @lt_ebeln_keys-table_line.
    SELECT * FROM eket INTO TABLE @gt_eket_buf
      FOR ALL ENTRIES IN @lt_ebeln_keys WHERE ebeln = @lt_ebeln_keys-table_line.
    SELECT * FROM ekes INTO TABLE @gt_ekes_buf
      FOR ALL ENTRIES IN @lt_ebeln_keys WHERE ebeln = @lt_ebeln_keys-table_line.
    SELECT * FROM ekbe INTO TABLE @gt_ekbe_buf
      FOR ALL ENTRIES IN @lt_ebeln_keys WHERE ebeln = @lt_ebeln_keys-table_line.
  ENDIF.

  IF lt_vbeln_keys IS NOT INITIAL.
    SELECT * FROM likp INTO TABLE @lt_likp_pre
      FOR ALL ENTRIES IN @lt_vbeln_keys WHERE vbeln = @lt_vbeln_keys-table_line.
    gt_likp_buf = lt_likp_pre.
    SELECT * FROM lips INTO TABLE @gt_lips_buf
      FOR ALL ENTRIES IN @lt_vbeln_keys WHERE vbeln = @lt_vbeln_keys-table_line.
  ENDIF.

  " Secondary PO fetch from LIPS references
  DATA(lt_ebeln_ref) = VALUE ty_ebeln_tt( FOR ls_lips IN gt_lips_buf WHERE ( vgbel IS NOT INITIAL ) ( ls_lips-vgbel ) ).
  SORT lt_ebeln_ref. DELETE ADJACENT DUPLICATES FROM lt_ebeln_ref.
  IF lt_ebeln_ref IS NOT INITIAL.
    SELECT * FROM ekko APPENDING TABLE @lt_ekko_pre
      FOR ALL ENTRIES IN @lt_ebeln_ref WHERE ebeln = @lt_ebeln_ref-table_line.
    SELECT * FROM ekpo APPENDING TABLE @lt_ekpo_pre
      FOR ALL ENTRIES IN @lt_ebeln_ref WHERE ebeln = @lt_ebeln_ref-table_line.
    SELECT * FROM eket APPENDING TABLE @gt_eket_buf
      FOR ALL ENTRIES IN @lt_ebeln_ref WHERE ebeln = @lt_ebeln_ref-table_line.
    SELECT * FROM ekes APPENDING TABLE @gt_ekes_buf
      FOR ALL ENTRIES IN @lt_ebeln_ref WHERE ebeln = @lt_ebeln_ref-table_line.
    SELECT * FROM ekbe APPENDING TABLE @gt_ekbe_buf
      FOR ALL ENTRIES IN @lt_ebeln_ref WHERE ebeln = @lt_ebeln_ref-table_line.
  ENDIF.

  " Deduplicate and move to hashed buffers
  SORT lt_ekko_pre BY ebeln. DELETE ADJACENT DUPLICATES FROM lt_ekko_pre COMPARING ebeln.
  gt_ekko_buf = lt_ekko_pre.

  SORT lt_ekpo_pre BY ebeln ebelp. DELETE ADJACENT DUPLICATES FROM lt_ekpo_pre COMPARING ebeln ebelp.
  gt_ekpo_buf = lt_ekpo_pre.

  IF lt_werks_keys IS NOT INITIAL.
    SELECT * FROM t001w INTO TABLE @lt_t001w_pre
      FOR ALL ENTRIES IN @lt_werks_keys WHERE werks = @lt_werks_keys-table_line.
    gt_t001w_buf = lt_t001w_pre.
    IF gt_t001w_buf IS NOT INITIAL.
      SELECT * FROM t001k INTO TABLE @lt_t001k_pre
        FOR ALL ENTRIES IN @gt_t001w_buf WHERE bwkey = @gt_t001w_buf-bwkey.
      gt_t001k_buf = lt_t001k_pre.
    ENDIF.
    IF lt_matnr_keys IS NOT INITIAL.
      SELECT * FROM mbew INTO TABLE @lt_mbew_pre
        FOR ALL ENTRIES IN @lt_matnr_keys WHERE matnr = @lt_matnr_keys-table_line.
      gt_mbew_buf = lt_mbew_pre.
    ENDIF.
  ENDIF.

  " Fetch configuration and other lookups
  SELECT * FROM t156 INTO TABLE @gt_t156_buf.
  SELECT * FROM yudc_trans INTO TABLE @gt_yudc_trans_buf.
  SELECT * FROM y0ca_ale_delay INTO TABLE @gt_y0ca_ale_delay_buf.
  SELECT * FROM y0mm_migo_weora INTO TABLE @gt_y0mm_migo_weora_buf.
  SELECT * FROM y0mm_mbgmcr_tr INTO TABLE @gt_y0mm_mbgmcr_tr_buf.
  SELECT * FROM yusmm_mbgmcr_lib INTO TABLE @gt_yusmm_mbgmcr_lib_buf.
  SELECT * FROM y0bc_idoc_dd_plt INTO TABLE @gt_y0bc_idoc_dd_plt_buf.
  SELECT * FROM y0mm_gm_matnrcnv INTO TABLE @gt_y0mm_gm_matnrcnv_buf.
  SELECT * FROM y0pp_calc_rbfqty INTO TABLE @gt_y0pp_calc_rbfqty_buf.
  SELECT * FROM y0mm_gm_lifnrcnv INTO TABLE @gt_y0mm_gm_lifnrcnv_buf.
  SELECT * FROM ybrmm_idoc_tr INTO TABLE @gt_ybrmm_idoc_tr_buf.
  SELECT SINGLE spe_inb_vl_mm FROM tvshp INTO @gv_spe_inb_vl_mm.

  " Fetch QALS if relevant
  IF lt_matnr_keys IS NOT INITIAL.
    SELECT * FROM qals INTO TABLE @gt_qals_buf
      FOR ALL ENTRIES IN @lt_matnr_keys WHERE matnr = @lt_matnr_keys-table_line.
  ENDIF.

  " --- PRE-FETCH LOGIC END ---

* go through all IDocs                                                 *
  DATA(lv_idoc_idx) = 1.
  LOOP AT idoc_contrl.
*   select segments belonging to one IDoc                              *
    REFRESH t_edidd.
    READ TABLE idoc_data WITH KEY docnum = idoc_contrl-docnum BINARY SEARCH TRANSPORTING NO FIELDS.
    IF sy-subrc = 0.
      lv_idoc_idx = sy-tabix.
      LOOP AT idoc_data INTO DATA(ls_idoc_data) FROM lv_idoc_idx.
        IF ls_idoc_data-docnum <> idoc_contrl-docnum.
          EXIT.
        ENDIF.
        APPEND ls_idoc_data TO t_edidd.
      ENDLOOP.
    ENDIF.

*   initialize data
    CLEAR: goodsmvt_header,
           goodsmvt_code,
           testrun,
           goodsmvt_headret,
           materialdocument,
           matdocumentyear,
           goodsmvt_item,
           goodsmvt_serialnumber,
           return,
           z1bp2017,
           hi_flag_etikett,
           it_po_header,
           it_all_po_items,
           it_all_po_schedules,
           it_ch_po_numbers,
           it_ch_all_po_items,
           it_ch_all_po_itemsx,
           it_ch_all_po_schedules,
           it_ch_all_po_schedulex,
           it_v_ekko_ekpo,
           it_eket,
           it_ekes,
           ls_gm_head_check.

    REFRESH: goodsmvt_item,
             goodsmvt_serialnumber,
             return,
             it_po_header,
             it_all_po_items,
             it_all_po_schedules,
             it_ch_po_numbers,
             it_ch_all_po_items,
             it_ch_all_po_itemsx,
             it_ch_all_po_schedules,
             it_ch_all_po_schedulex,
             it_v_ekko_ekpo,
             it_eket,
             it_ekes.

*   unlock previos po's
    IF it_lock[] IS NOT INITIAL.
      DATA(lt_unlock) = VALUE ty_ebeln_tt( FOR ls_lock IN it_lock ( ls_lock-ebeln ) ).
      DELETE y0mm_proc_ebeln FROM TABLE @lt_unlock.
      COMMIT WORK.
    ENDIF.
*   through all segments of this IDoc                                  *
    CLEAR error_flag.
    REFRESH bapi_retn_info.
    CATCH SYSTEM-EXCEPTIONS conversion_errors = 1.

      " Check if plant/DD mapping is necessary
      CLEAR: lv_dd_map, ls_gm_head_check.
      READ TABLE t_edidd INTO idoc_data WITH KEY segnam = 'E1BP2017_GM_HEAD_01'.
      IF sy-subrc = 0.
        ls_gm_head_check = idoc_data-sdata.
      ENDIF.

      " Buffer lookup for plant/DD mapping configuration
      LOOP AT gt_y0bc_idoc_dd_plt_buf INTO DATA(ls_dd_plt)
        WHERE partyp = idoc_contrl-sndprt
          AND parnum = idoc_contrl-sndprn
          AND mestyp = idoc_contrl-mestyp
          AND valid_to >= ls_gm_head_check-pstng_date.
        lv_dd_map = abap_true.
        EXIT.
      ENDLOOP.
      LOOP AT t_edidd INTO idoc_data.

        CASE idoc_data-segnam.

          WHEN 'E1MBGMCR'.

            e1mbgmcr = idoc_data-sdata.
            MOVE e1mbgmcr-testrun
              TO testrun.


          WHEN 'E1BP2017_GM_HEAD_01'.

            e1bp2017_gm_head_01 = idoc_data-sdata.
            MOVE-CORRESPONDING e1bp2017_gm_head_01
                            TO goodsmvt_header.

            IF e1bp2017_gm_head_01-pstng_date IS INITIAL.
              CLEAR goodsmvt_header-pstng_date.
            ENDIF.
            IF e1bp2017_gm_head_01-doc_date IS INITIAL.
              CLEAR goodsmvt_header-doc_date.
            ENDIF.


          WHEN 'E1BP2017_GM_CODE'.

            e1bp2017_gm_code = idoc_data-sdata.
            MOVE-CORRESPONDING e1bp2017_gm_code
                            TO goodsmvt_code.


          WHEN 'E1BP2017_GM_ITEM_CREATE'.
            e1bp2017_gm_item_create = idoc_data-sdata.

            " if necessary map plant + dd material
            IF lv_dd_map = abap_true.
              " Material might be relevant for mapping (RB to DD)
              cl_matnr_chk_mapper=>convert_on_input( EXPORTING iv_matnr18 = e1bp2017_gm_item_create-material
                                                     IMPORTING ev_matnr40 = lv_matnr ).

              e1bp2017_gm_item_create-material = ycl_bc_idoc_functions=>map_material_rb_dd( EXPORTING iv_partyp = idoc_contrl-sndprt "#EC CI_FLDEXT_OK[2215424]
                                                                                                      iv_parnum = idoc_contrl-sndprn
                                                                                                      iv_mestyp = idoc_contrl-mestyp
                                                                                                      iv_date = CONV datum( ls_gm_head_check-pstng_date )
                                                                                                      iv_matnr_in = lv_matnr ).

              " Plants might be relevant for mapping
              e1bp2017_gm_item_create-plant = ycl_bc_idoc_functions=>map_plant_in( EXPORTING iv_partyp = idoc_contrl-sndprt
                                                                                             iv_parnum = idoc_contrl-sndprn
                                                                                             iv_mestyp = idoc_contrl-mestyp
                                                                                             iv_date = CONV datum( ls_gm_head_check-pstng_date )
                                                                                             iv_werks_idoc = e1bp2017_gm_item_create-plant ).

              " If needed also to 'to' mat+plant
              IF e1bp2017_gm_item_create-move_mat IS NOT INITIAL.
                cl_matnr_chk_mapper=>convert_on_input( EXPORTING iv_matnr18 = e1bp2017_gm_item_create-move_mat
                                                       IMPORTING ev_matnr40 = lv_matnr ).

                e1bp2017_gm_item_create-move_mat = ycl_bc_idoc_functions=>map_material_rb_dd( EXPORTING iv_partyp = idoc_contrl-sndprt "#EC CI_FLDEXT_OK[2215424]
                                                                                                        iv_parnum = idoc_contrl-sndprn
                                                                                                        iv_mestyp = idoc_contrl-mestyp
                                                                                                        iv_date = CONV datum( ls_gm_head_check-pstng_date )
                                                                                                        iv_matnr_in = lv_matnr ).
              ENDIF.

              IF e1bp2017_gm_item_create-move_plant IS NOT INITIAL.
                e1bp2017_gm_item_create-move_plant = ycl_bc_idoc_functions=>map_plant_in( EXPORTING iv_partyp = idoc_contrl-sndprt
                                                                                                    iv_parnum = idoc_contrl-sndprn
                                                                                                    iv_mestyp = idoc_contrl-mestyp
                                                                                                    iv_date = CONV datum( ls_gm_head_check-pstng_date )
                                                                                                    iv_werks_idoc = e1bp2017_gm_item_create-move_plant ).
              ENDIF.

            ENDIF.

            MOVE-CORRESPONDING e1bp2017_gm_item_create
                            TO goodsmvt_item.

            "ERPMM-2668
            lt_items = VALUE #( BASE lt_items ( e1bp2017_gm_item_create ) ).

            "For BI data transfer
            IF goodsmvt_item-deliv_numb_to_search IS NOT INITIAL.
              " Buffer lookup for LIKP
              READ TABLE gt_likp_buf INTO DATA(ls_likp_prefetch)
                WITH TABLE KEY vbeln = goodsmvt_item-deliv_numb_to_search.
              IF sy-subrc = 0 AND ls_likp_prefetch-vbtyp NE '7'.
                goodsmvt_item-deliv_numb = goodsmvt_item-deliv_numb_to_search.
                goodsmvt_item-deliv_item = goodsmvt_item-deliv_item_to_search.
              ENDIF.
            ENDIF.


            IF e1bp2017_gm_item_create-ref_date IS INITIAL.
              CLEAR goodsmvt_item-ref_date.
            ENDIF.
            IF e1bp2017_gm_item_create-expirydate IS INITIAL.
              CLEAR goodsmvt_item-expirydate.
            ENDIF.
            IF e1bp2017_gm_item_create-prod_date IS INITIAL.
              CLEAR goodsmvt_item-prod_date.
            ENDIF.

*         convert material number - if partner system needs it
            READ TABLE gt_y0mm_gm_matnrcnv_buf INTO y0mm_gm_matnrcnv
                           WITH TABLE KEY sndprn = idoc_contrl-sndprn.
            IF sy-subrc = 0.
              CALL FUNCTION 'Y_0CA_PARTNER_CONVERT_MATNR'
                EXPORTING
                  matnr_in                = goodsmvt_item-material
                  direct                  = '2'
                IMPORTING
                  matnr_out               = goodsmvt_item-material
                EXCEPTIONS
                  invalid_parameters      = 1
                  material_does_not_exist = 2
                  OTHERS                  = 3.
              IF sy-subrc NE 0.
                error_flag = true.
                CLEAR bapi_retn_info.
                bapi_retn_info-type       = 'E'.
                bapi_retn_info-id         = 'Y0PP_IDOCS'.
                bapi_retn_info-number     = '014'.
                bapi_retn_info-message_v1 = goodsmvt_item-material.
                bapi_retn_info-message_v2 = l_blank_msgv.
                bapi_retn_info-message_v3 = l_blank_msgv.
                bapi_retn_info-message_v4 = l_blank_msgv.
                bapi_retn_info-parameter  = 'GOODSMVTITEM'.
                bapi_idoc_status          = '51'.
                PERFORM idoc_status_mbgmcr
                       TABLES t_edidd
                              idoc_status
                              return_variables
                        USING idoc_contrl
                              bapi_retn_info
                              bapi_idoc_status
                              workflow_result.
                EXIT.
              ENDIF.

              CALL FUNCTION 'Y_0CA_PARTNER_CONVERT_MATNR'
                EXPORTING
                  matnr_in                = goodsmvt_item-move_mat
                  direct                  = '2'
                IMPORTING
                  matnr_out               = goodsmvt_item-move_mat
                EXCEPTIONS
                  invalid_parameters      = 1
                  material_does_not_exist = 2
                  OTHERS                  = 3.
              IF sy-subrc NE 0.
                error_flag = true.
                CLEAR bapi_retn_info.
                bapi_retn_info-type       = 'E'.
                bapi_retn_info-id         = 'Y0PP_IDOCS'.
                bapi_retn_info-number     = '014'.
                bapi_retn_info-message_v1 = goodsmvt_item-material.
                bapi_retn_info-message_v2 = l_blank_msgv.
                bapi_retn_info-message_v3 = l_blank_msgv.
                bapi_retn_info-message_v4 = l_blank_msgv.
                bapi_retn_info-parameter  = 'GOODSMVTITEM'.
                bapi_idoc_status          = '51'.
                PERFORM idoc_status_mbgmcr
                       TABLES t_edidd
                              idoc_status
                              return_variables
                        USING idoc_contrl
                              bapi_retn_info
                              bapi_idoc_status
                              workflow_result.
                EXIT.
              ENDIF.
            ENDIF.

*         recalculate quantites
            READ TABLE gt_y0pp_calc_rbfqty_buf INTO y0pp_calc_rbfqty
                           WITH TABLE KEY matnr = goodsmvt_item-material.
            IF sy-subrc = 0.
*            recalculate quantity for PO Create
              LOOP AT t_edidd INTO wa_edidd WHERE segnam = 'Z1BP2017'.
                z1bp2017 = wa_edidd-sdata.
                CHECK z1bp2017-zbaret  = 'X' AND
                      z1bp2017-zbquan  = goodsmvt_item-entry_qnt AND
                      z1bp2017-zbmeins = goodsmvt_item-entry_uom.
                z1bp2017-zbquan = z1bp2017-zbquan *
                                  y0pp_calc_rbfqty-faktr.
                wa_edidd-sdata = z1bp2017.
                MODIFY t_edidd FROM wa_edidd.
              ENDLOOP.
*            recalculate item quantity
              goodsmvt_item-entry_qnt = goodsmvt_item-entry_qnt *
                                        y0pp_calc_rbfqty-faktr.
            ENDIF.

*         convert vendor number
            CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
              EXPORTING
                input  = goodsmvt_item-vendor
              IMPORTING
                output = goodsmvt_item-vendor.

            READ TABLE gt_y0mm_gm_lifnrcnv_buf INTO y0mm_gm_lifnrcnv
                           WITH TABLE KEY sndprn    = idoc_contrl-sndprn
                                          lifnr_ext = goodsmvt_item-vendor.
            IF sy-subrc = 0.
              goodsmvt_item-vendor = y0mm_gm_lifnrcnv-lifnr.
            ENDIF.

            "Plausibility check on reference number
            DATA(l_valid) = abap_true.
            IF goodsmvt_code EQ '01'.
              LOOP AT gt_mbgmcr_chk INTO DATA(ls_mbgmcr_chk) WHERE mestyp = idoc_contrl-mestyp
                                                               AND lifnr  = goodsmvt_item-vendor
                                                               AND werks  = e1bp2017_gm_item_create-plant
                                                               AND datab  =< sy-datum.
                IF idoc_contrl-sndprn CP ls_mbgmcr_chk-sndprn.
                  DATA(l_ref_doc_no) = |{ goodsmvt_header-ref_doc_no WIDTH = 16 ALPHA = IN }|.

                  IF l_ref_doc_no BETWEEN ls_mbgmcr_chk-fromnumber AND ls_mbgmcr_chk-tonumber.
                    l_valid = abap_true.
                    EXIT.
                  ELSE.
                    l_valid = abap_false.
                  ENDIF.
                ENDIF.
              ENDLOOP.
            ENDIF.

            IF l_valid EQ abap_false.
              error_flag = true.
              CLEAR bapi_retn_info.
              bapi_retn_info-type       = 'E'.
              bapi_retn_info-id         = 'Y0MM_IDOCS'.
              bapi_retn_info-number     = '050'.
              bapi_retn_info-message_v1 = goodsmvt_header-ref_doc_no.
              bapi_retn_info-message_v2 = e1bp2017_gm_item_create-plant.
              bapi_retn_info-message_v3 = l_blank_msgv.
              bapi_retn_info-message_v4 = l_blank_msgv.
*               bapi_retn_info-parameter  = 'GOODSMVTITEM'.
              bapi_idoc_status          = '51'.
              PERFORM idoc_status_mbgmcr
                     TABLES t_edidd
                            idoc_status
                            return_variables
                      USING idoc_contrl
                            bapi_retn_info
                            bapi_idoc_status
                            workflow_result.
              EXIT.
            ELSE.
              CLEAR l_valid.
            ENDIF.

*         Customer conversions
            READ TABLE it_gm_conv
                       WITH KEY parnum = idoc_contrl-sndprn
                                matnr  = goodsmvt_item-material
                                bwart  = goodsmvt_item-move_type.
            IF sy-subrc = 0.
              goodsmvt_code            = it_gm_conv-gm_code_new.
              goodsmvt_item-move_type  = it_gm_conv-bwart_new.
              goodsmvt_item-mvt_ind    = it_gm_conv-mvt_ind_new.
              goodsmvt_item-move_plant = goodsmvt_item-plant.
              goodsmvt_item-move_stloc = goodsmvt_item-stge_loc.
              goodsmvt_item-plant      = it_gm_conv-umwrk.
              goodsmvt_item-stge_loc   = it_gm_conv-umlgo.
            ENDIF.
*         Ingredient production process
*         If acceptance at origin flag is set, and movement type eq 101 - change to 109
*         Goods receipt has to be posted to delivery, not to PO.
*         In case of YIDV delivery - get PO number if not included in Idoc
            IF goodsmvt_item-po_number IS INITIAL.
              IF idoc_contrl-sndprn = 'ATCPSYS' OR idoc_contrl-sndprn = 'DEPVSFASH'.
                " Buffer lookup for LIPS
                READ TABLE gt_lips_buf INTO DATA(ls_lips_po_ref)
                  WITH KEY vbeln = goodsmvt_item-deliv_numb_to_search
                           posnr = goodsmvt_item-deliv_item_to_search.
                IF sy-subrc = 0.
                  goodsmvt_item-po_number = ls_lips_po_ref-vgbel.
                  goodsmvt_item-po_item   = ls_lips_po_ref-vgpos.
                ENDIF.
              ELSE.
                " Buffer lookup for LIKP
                READ TABLE gt_likp_buf INTO DATA(ls_likp_po_ref)
                  WITH TABLE KEY vbeln = goodsmvt_item-deliv_numb_to_search.
                IF sy-subrc = 0 AND ls_likp_po_ref-lfart = co_lfart_yidv.
                  " Buffer lookup for LIPS
                  READ TABLE gt_lips_buf INTO ls_lips_po_ref
                    WITH KEY vbeln = goodsmvt_item-deliv_numb_to_search
                             posnr = goodsmvt_item-deliv_item_to_search.
                  IF sy-subrc = 0.
                    goodsmvt_item-po_number = ls_lips_po_ref-vgbel.
                    goodsmvt_item-po_item   = ls_lips_po_ref-vgpos.
                  ENDIF.
                ENDIF.
              ENDIF.
            ENDIF.

            CLEAR hi_weora.
            " Buffer lookup for EKPO
            READ TABLE gt_ekpo_buf INTO DATA(ls_ekpo_weora)
              WITH TABLE KEY ebeln = goodsmvt_item-po_number
                             ebelp = goodsmvt_item-po_item.
            IF sy-subrc = 0 AND ls_ekpo_weora-weora = 'X'.
              hi_weora = 'X'.
              IF goodsmvt_item-move_type EQ '101'.
                IF goodsmvt_item-deliv_numb_to_search IS INITIAL.
                  " Buffer lookup for EKES
                  READ TABLE gt_ekes_buf INTO DATA(ls_ekes_prefetch)
                    WITH KEY ebeln = goodsmvt_item-po_number
                             ebelp = goodsmvt_item-po_item
                             charg = goodsmvt_item-batch.
                  IF sy-subrc = 0.
                    goodsmvt_item-deliv_numb_to_search = ls_ekes_prefetch-vbeln.
                    goodsmvt_item-deliv_item_to_search = ls_ekes_prefetch-vbelp.
                  ENDIF.
                ELSE.
                  sy-subrc = 0. " For compatibility with original check logic
                ENDIF.
**/ ATX-KEMMING Begin
                IF sy-subrc = 0 AND NOT goodsmvt_item-deliv_numb_to_search IS INITIAL.
                  IF NOT idoc_contrl-sndprn = 'ATCPSYS' AND NOT idoc_contrl-sndprn = 'DEPVSFASH'.
                    IF NOT gv_spe_inb_vl_mm EQ abap_true.
                      CLEAR: goodsmvt_item-po_number, goodsmvt_item-po_item.
                    ENDIF.
                  ENDIF.
                  goodsmvt_item-move_type = '109'.
                ELSE.
                  " Buffer lookup for EKES - alternative search for any inbound delivery
                  LOOP AT gt_ekes_buf INTO ls_ekes_prefetch
                    WHERE ebeln = goodsmvt_item-po_number
                      AND ebelp = goodsmvt_item-po_item
                      AND charg = goodsmvt_item-batch
                      AND vbeln NE space.
                    goodsmvt_item-deliv_numb_to_search = ls_ekes_prefetch-vbeln.
                    goodsmvt_item-deliv_item_to_search = ls_ekes_prefetch-vbelp.
                    CLEAR: goodsmvt_item-po_number, goodsmvt_item-po_item.
                    goodsmvt_item-move_type = '109'.
                    EXIT.
                  ENDLOOP.
                ENDIF.
**/ ATX-KEMMING End
              ELSEIF goodsmvt_item-move_type EQ '102'.
                " Buffer lookup for EKES
                READ TABLE gt_ekes_buf INTO ls_ekes_prefetch
                  WITH KEY ebeln = goodsmvt_item-po_number
                           ebelp = goodsmvt_item-po_item
                           charg = goodsmvt_item-batch.
                IF sy-subrc = 0.
                  goodsmvt_item-deliv_numb_to_search = ls_ekes_prefetch-vbeln.
                  goodsmvt_item-deliv_item_to_search = ls_ekes_prefetch-vbelp.
                ENDIF.
**/ ATX-KEMMING Begin
                IF sy-subrc = 0 AND NOT goodsmvt_item-deliv_numb_to_search IS INITIAL.
                  CLEAR: goodsmvt_item-po_number, goodsmvt_item-po_item.
                  goodsmvt_item-move_type = '110'.
                ELSE.
                  " Buffer lookup for EKES - alternative search
                  LOOP AT gt_ekes_buf INTO ls_ekes_prefetch
                    WHERE ebeln = goodsmvt_item-po_number
                      AND ebelp = goodsmvt_item-po_item
                      AND charg = goodsmvt_item-batch
                      AND vbeln NE space.
                    goodsmvt_item-deliv_numb_to_search = ls_ekes_prefetch-vbeln.
                    goodsmvt_item-deliv_item_to_search = ls_ekes_prefetch-vbelp.
                    CLEAR: goodsmvt_item-po_number, goodsmvt_item-po_item.
                    goodsmvt_item-move_type = '110'.
                    EXIT.
                  ENDLOOP.
                ENDIF.
**/ ATX-KEMMING End
              ENDIF.
            ENDIF.

*         change movementy type due to customizing table
            CLEAR it_bwart_po.
            READ TABLE it_bwart_po
                       WITH KEY bwart = goodsmvt_item-move_type.
            IF sy-subrc = 0.
              goodsmvt_item-move_type = it_bwart_po-bwart_new.
            ENDIF.

* PAU-RG    Neuber Asia Process -> find stock transfer PO in case of ZRM
*           find via tracking number and requisitioner
*           Step 1: check doc.type of PO, Hard coded ZRM
*                   only one occurence, main.view. would be overkill
            CLEAR: hi_bsart.
            " Buffer lookup for EKKO
            READ TABLE gt_ekko_buf INTO DATA(ls_ekko_prefetch)
              WITH TABLE KEY ebeln = goodsmvt_item-po_number.
            IF sy-subrc = 0.
              hi_bsart = ls_ekko_prefetch-bsart.
            ENDIF.
            IF hi_bsart = 'ZRM'.
*              Step 2: Get ZRU PO Items via Tracking Number
              REFRESH it_ekpo.
              " Buffer lookup for EKPO using bednr
              LOOP AT gt_ekpo_buf INTO DATA(ls_ekpo_bednr) USING KEY k_bednr
                WHERE bednr = goodsmvt_item-po_number.
                APPEND CORRESPONDING #( ls_ekpo_bednr ) TO it_ekpo.
              ENDLOOP.
*              Step 3: Search with requisitioner
*                      loop where clause disregards leading zero
*                      diffenc problem of the select statement
              LOOP AT it_ekpo WHERE afnam = goodsmvt_item-po_item.
                EXIT.
              ENDLOOP.
              IF sy-subrc = 0.
                goodsmvt_item-po_number = it_ekpo-ebeln.
                goodsmvt_item-po_item   = it_ekpo-ebelp.
              ENDIF.
            ENDIF.

* PAU-TP Beg Call transaction for VL32N aDDED "$TP220206
* POS inbound delivery
            IF NOT goodsmvt_item-deliv_numb_to_search IS INITIAL.
              " Buffer lookup for MARA
              READ TABLE gt_mara_buf INTO DATA(ls_mara_prefetch)
                WITH TABLE KEY matnr = goodsmvt_item-material.
              IF sy-subrc = 0.
                gf_mtart = ls_mara_prefetch-mtart.
              ENDIF.

              " Buffer lookup for LIKP
              READ TABLE gt_likp_buf INTO DATA(ls_likp_pos)
                WITH TABLE KEY vbeln = goodsmvt_item-deliv_numb_to_search.
              IF sy-subrc = 0.
                likp-lfart = ls_likp_pos-lfart.
              ENDIF.
              READ TABLE it_y0mm_inbounddeli
                          WITH KEY zndprn  = idoc_contrl-sndprn
                                    lfart  = likp-lfart
                                    bwart  = goodsmvt_item-move_type
                                    mtart  = gf_mtart.
              IF sy-subrc EQ 0.
                gf_inbound_del_flag = 'X'.
                gt_inb_item-vbeln = goodsmvt_item-deliv_numb_to_search.
                gt_inb_item-posnr = goodsmvt_item-deliv_item_to_search.
                gt_inb_item-matnr = goodsmvt_item-material.
                gt_inb_item-lfimg = goodsmvt_item-entry_qnt.
                gt_inb_item-vrkme = goodsmvt_item-entry_uom.

                APPEND gt_inb_item.
                CLEAR gt_inb_item.
              ENDIF.

              "In case of inbound delivery clear DELIV_NUMB DELIV_ITEM
              "as this would cause a dump in case of goods movement process
*              IF likp-vbtyp = '7'.
*                CLEAR: goodsmvt_item-deliv_numb, goodsmvt_item-deliv_item.
*              ENDIF.
            ENDIF.
* PAU-TP end Call transaction for VL32N aDDED "$TP220206


* PAU-RD: By reverse of goods receipt it´s necessary to fill some more
* fields, therefor table EKBE (history of purchase doc.) must be read
* to get the data.
            IF gf_inbound_del_flag NE 'X'.                  "$TP220206
              " Buffer lookup for T156
              READ TABLE gt_t156_buf INTO t156
                WITH TABLE KEY bwart = goodsmvt_item-move_type.
              IF sy-subrc = 0 AND t156-shkzg EQ 'H'.

                CLEAR wa_ekbe.
                " Buffer lookup for EKBE
                LOOP AT gt_ekbe_buf INTO wa_ekbe
                  WHERE ebeln = goodsmvt_item-po_number
                    AND ebelp = goodsmvt_item-po_item
                    AND matnr = goodsmvt_item-material
                    AND werks = goodsmvt_item-plant
                    AND xblnr = goodsmvt_header-ref_doc_no
                    AND menge = goodsmvt_item-entry_qnt
                    AND shkzg = 'S'
                    AND vgabe = '1'.

                  IF wa_ekbe-shkzg EQ 'S'.
                    DATA(lv_found_rev) = abap_false.
                    LOOP AT gt_ekbe_buf INTO ekbe
                      WHERE ebeln = goodsmvt_item-po_number
                        AND ebelp = goodsmvt_item-po_item
                        AND matnr = goodsmvt_item-material
                        AND werks = goodsmvt_item-plant
                        AND menge = goodsmvt_item-entry_qnt
                        AND lfgja = wa_ekbe-lfgja
                        AND lfbnr = wa_ekbe-lfbnr
                        AND lfpos = wa_ekbe-lfpos
                        AND shkzg = 'H'
                        AND vgabe = '1'.
                      lv_found_rev = abap_true.
                      EXIT.
                    ENDLOOP.

                    IF lv_found_rev = abap_false.
                      goodsmvt_item-ref_doc_yr = wa_ekbe-lfgja.
                      goodsmvt_item-ref_doc    = wa_ekbe-lfbnr.
                      goodsmvt_item-ref_doc_it = wa_ekbe-lfpos.
                    ENDIF.
                  ENDIF.
                ENDLOOP.
*   IF no entry in EKBE is found, check on part delivery
                IF goodsmvt_item-ref_doc IS INITIAL.        "12-73618
                  CLEAR wa_ekbe.
*    Search for PO with gt quantity
                  LOOP AT gt_ekbe_buf INTO wa_ekbe
                    WHERE ebeln = goodsmvt_item-po_number
                      AND ebelp = goodsmvt_item-po_item
                      AND matnr = goodsmvt_item-material
                      AND werks = goodsmvt_item-plant
                      AND xblnr = goodsmvt_header-ref_doc_no
                      AND menge > goodsmvt_item-entry_qnt
                      AND shkzg = 'S'
                      AND vgabe = '1'.

                    CLEAR hi_menge.
*    Get all cancellations
                    LOOP AT gt_ekbe_buf INTO ekbe
                      WHERE ebeln = goodsmvt_item-po_number
                        AND ebelp = goodsmvt_item-po_item
                        AND matnr = goodsmvt_item-material
                        AND werks = goodsmvt_item-plant
                        AND lfgja = wa_ekbe-lfgja
                        AND lfbnr = wa_ekbe-lfbnr
                        AND lfpos = wa_ekbe-lfpos
                        AND shkzg = 'H'
                        AND vgabe = '1'.

                      ADD ekbe-menge TO hi_menge.
                    ENDLOOP.
                    SUBTRACT hi_menge FROM wa_ekbe-menge.
                    IF wa_ekbe-menge GE goodsmvt_item-entry_qnt.
                      goodsmvt_item-ref_doc_yr = wa_ekbe-lfgja.
                      goodsmvt_item-ref_doc    = wa_ekbe-lfbnr.
                      goodsmvt_item-ref_doc_it = wa_ekbe-lfpos.
                      EXIT.
                    ELSE.
                      CLEAR hi_menge.
                    ENDIF.
                  ENDLOOP.
                ENDIF.
              ENDIF.


*-----------------------------------
* Check material is a label -- Field Labor on materialmaster eq Z00
* Reversal will be created manually
              " Buffer lookup for MARA
              READ TABLE gt_mara_buf INTO ls_mara_prefetch
                WITH TABLE KEY matnr = goodsmvt_item-material.
              IF sy-subrc = 0 AND ls_mara_prefetch-labor = co_labor_etikett.

                IF goodsmvt_code = '01'.
                  IF t156-shkzg EQ 'S'.

* Save order quantity and item
                    hi_entry_qnt  = goodsmvt_item-entry_qnt.
                    goodsmvt_item_save = goodsmvt_item.

*                   SELECT  * FROM v_ekko_ekpo INTO TABLE it_v_ekko_ekpo
                    REFRESH it_v_ekko_ekpo.
                    LOOP AT gt_ekpo_buf INTO DATA(ls_ekpo_join)
                      WHERE werks = goodsmvt_item-plant
                        AND matnr = goodsmvt_item-material
                        AND loekz = space
                        AND elikz = space
                        AND bstyp = 'F'.

                      READ TABLE gt_ekko_buf INTO DATA(ls_ekko_join)
                        WITH TABLE KEY ebeln = ls_ekpo_join-ebeln.
                      IF sy-subrc = 0 AND ls_ekko_join-lifnr = goodsmvt_item-vendor.
                        APPEND VALUE #( ebeln = ls_ekpo_join-ebeln
                                        ebelp = ls_ekpo_join-ebelp
                                        bedat = ls_ekko_join-bedat ) TO it_v_ekko_ekpo.
                      ENDIF.
                    ENDLOOP.
                    SORT it_v_ekko_ekpo BY bedat DESCENDING.

                    IF it_v_ekko_ekpo IS NOT INITIAL.
                      REFRESH it_eket.
                      LOOP AT it_v_ekko_ekpo INTO DATA(ls_v_ekko_ekpo).
                        LOOP AT gt_eket_buf INTO DATA(ls_eket_join)
                          WHERE ebeln = ls_v_ekko_ekpo-ebeln
                            AND ebelp = ls_v_ekko_ekpo-ebelp.
                          APPEND ls_eket_join TO it_eket.
                        ENDLOOP.
                      ENDLOOP.

                      IF it_eket IS NOT INITIAL.

* Only open orders
                        DELETE it_eket WHERE wemng >= menge.

* Sort by date
                        SORT it_eket BY bedat ebeln ebelp.

* Get open quantitiy
                        LOOP AT it_eket.
                          REFRESH it_ekes.
                          CLEAR hi_bmeng.
                          LOOP AT gt_ekes_buf INTO DATA(ls_ekes_join)
                            WHERE ebeln = it_eket-ebeln
                              AND ebelp = it_eket-ebelp
                              AND loekz = space.
                            APPEND ls_ekes_join TO it_ekes.
                          ENDLOOP.

                          IF it_ekes IS NOT INITIAL.
*  Check, if enough quantity
*  Calculate quantity for save
                            LOOP AT it_ekes.
                              hi_omeng = it_ekes-menge
                                         - it_ekes-dabmg.

                              IF hi_omeng LT hi_entry_qnt.
                                hi_entry_qnt = hi_entry_qnt - hi_omeng.
                              ELSE.
                                hi_entry_qnt = 0.
                              ENDIF.
* If all quantity is saved, exit
                              IF hi_entry_qnt EQ 0.
                                EXIT.
                              ENDIF.
                            ENDLOOP.
                          ENDIF.
* If all quantity is saved, exit
                          IF hi_entry_qnt EQ 0.
                            EXIT.
                          ENDIF.
                        ENDLOOP.
                      ENDIF.
                    ENDIF.

*--------------------------------------------------------
* If quantity is enough, recalculate and post goods movements
                    IF hi_entry_qnt EQ 0.
                      hi_flag_etikett = 'X'.             "Mark for label
* Sort by date
                      SORT it_eket BY bedat ebeln ebelp.
                      hi_entry_qnt  = goodsmvt_item-entry_qnt.

* Get open quantitiy
                      LOOP AT it_eket.
                        REFRESH it_ekes.
                        CLEAR hi_bmeng.
                        LOOP AT gt_ekes_buf INTO DATA(ls_ekes_label)
                                 WHERE ebeln EQ it_eket-ebeln
                                   AND ebelp EQ it_eket-ebelp
                                   AND loekz EQ space.
                          APPEND ls_ekes_label TO it_ekes.
                        ENDLOOP.

                        IF it_ekes IS NOT INITIAL.
*      Calculate quantity for save
                          LOOP AT it_ekes.
                            hi_omeng = it_ekes-menge - it_ekes-dabmg.

                            IF hi_omeng LT hi_entry_qnt.
                              goodsmvt_item-entry_qnt = hi_omeng.
                              goodsmvt_item-no_more_gr = 'X'.
                              hi_entry_qnt = hi_entry_qnt - hi_omeng.
                            ELSE.
                              goodsmvt_item-entry_qnt = hi_entry_qnt.
                              goodsmvt_item-no_more_gr = space.
                              hi_entry_qnt = 0.
                            ENDIF.
* Order number and position will be saved in field unloading point
                            CONCATENATE goodsmvt_item-po_number ' '
                            goodsmvt_item-po_item INTO
                            goodsmvt_item-unload_pt.
                            goodsmvt_item-po_number = it_ekes-ebeln.
                            goodsmvt_item-po_item   = it_ekes-ebelp.

                            APPEND goodsmvt_item.

* Post goods movement -----------------------------
* call BAPI-function in this system                                  *
                            CALL FUNCTION 'BAPI_GOODSMVT_CREATE'  "#EC CI_USAGE_OK[2438131]
                              EXPORTING
                                goodsmvt_header       = goodsmvt_header
                                goodsmvt_code         = goodsmvt_code
                                testrun               = testrun
                              IMPORTING
                                goodsmvt_headret      = goodsmvt_headret
                                materialdocument      = materialdocument
                                matdocumentyear       = matdocumentyear
                              TABLES
                                goodsmvt_item         = goodsmvt_item
                                goodsmvt_serialnumber = goodsmvt_serialnumber
                                return                = return
                              EXCEPTIONS
                                OTHERS                = 1.
                            IF sy-subrc <> 0.
*     write IDoc status-record as error                                *
                              CLEAR bapi_retn_info.
                              bapi_retn_info-type       = 'E'.
                              bapi_retn_info-id         = sy-msgid.
                              bapi_retn_info-number     = sy-msgno.
                              bapi_retn_info-message_v1 = sy-msgv1.
                              bapi_retn_info-message_v2 = sy-msgv2.
                              bapi_retn_info-message_v3 = sy-msgv3.
                              bapi_retn_info-message_v4 = sy-msgv4.
                              bapi_idoc_status          = '51'.
                              PERFORM idoc_status_mbgmcr
                                      TABLES t_edidd
                                             idoc_status
                                             return_variables
                                       USING idoc_contrl
                                             bapi_retn_info
                                             bapi_idoc_status
                                             workflow_result.
                            ELSE.
                              LOOP AT return.
                                IF NOT return IS INITIAL.
                                  CLEAR bapi_retn_info.
                                  MOVE-CORRESPONDING return TO bapi_retn_info.
                                  IF return-type = 'A' OR return-type = 'E'.
                                    error_flag = 'X'.
                                  ENDIF.
                                  APPEND bapi_retn_info.
                                ENDIF.
                              ENDLOOP.
                              LOOP AT bapi_retn_info.
*       write IDoc status-record                                       *
                                IF error_flag IS INITIAL.
                                  bapi_idoc_status = '53'.
                                ELSE.
                                  bapi_idoc_status = '51'.
                                  IF bapi_retn_info-type = 'S'.
                                    CONTINUE.
                                  ENDIF.
                                ENDIF.
                                PERFORM idoc_status_mbgmcr
                                        TABLES t_edidd
                                               idoc_status
                                               return_variables
                                         USING idoc_contrl
                                               bapi_retn_info
                                               bapi_idoc_status
                                               workflow_result.
                              ENDLOOP.
                              IF sy-subrc <> 0.
*      'RETURN' is empty write idoc status-record as successful        *
                                CLEAR bapi_retn_info.
                                bapi_retn_info-type       = 'S'.
                                bapi_retn_info-id         = 'B1'.
                                bapi_retn_info-number     = '501'.
                                bapi_retn_info-message_v1 = 'CREATEFROMDATA'.
                                bapi_idoc_status          = '53'.
                                PERFORM idoc_status_mbgmcr
                                        TABLES t_edidd
                                               idoc_status
                                               return_variables
                                         USING idoc_contrl
                                               bapi_retn_info
                                               bapi_idoc_status
                                               workflow_result.
                              ENDIF.
                              IF error_flag IS INITIAL.
*       write linked object keys                                       *
                                CLEAR return_variables.
                                return_variables-wf_param = 'Appl_Objects'.
                                return_variables-doc_number+00 = materialdocument.
                                return_variables-doc_number+10 = matdocumentyear.
                                APPEND return_variables.

                              ENDIF.
                            ENDIF.
* Commit
                            CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
                              EXPORTING
                                wait = true.


                            REFRESH goodsmvt_item.

* If all quantity is saved, exit
                            IF hi_entry_qnt EQ 0.
                              goodsmvt_item = goodsmvt_item_save.
                              APPEND goodsmvt_item.
                              EXIT.
                            ENDIF.
                          ENDLOOP.
                        ENDIF.
* If all quantity is saved, exit
                        IF hi_entry_qnt EQ 0.
                          goodsmvt_item = goodsmvt_item_save.
                          APPEND goodsmvt_item.
                          EXIT.
                        ENDIF.
                      ENDLOOP.

* If not all quantitiy can be saved, set IDOC-status on error
                    ELSE.
                      bapi_retn_info-type   = 'E'.
                      bapi_retn_info-id     = 'Y0MM_IDOCS'.
                      bapi_retn_info-number = '011'.
                      bapi_retn_info-message_v1 = idoc_data-segnam.
                      bapi_idoc_status      = '51'.
                      PERFORM idoc_status_mbgmcr
                              TABLES t_edidd
                                     idoc_status
                                     return_variables
                               USING idoc_contrl
                                     bapi_retn_info
                                     bapi_idoc_status
                                     workflow_result.
                      CONTINUE.
                    ENDIF.
*---- Reversal
                  ELSE.

                    CLEAR bapi_retn_info.
                    bapi_retn_info-type       = 'E'.
                    bapi_retn_info-id         = 'Y0MM_IDOCS'.
                    bapi_retn_info-number     = '009'.
                    bapi_retn_info-message_v1 = goodsmvt_item-po_number.
                    bapi_retn_info-message_v2 = goodsmvt_item-po_item.
                    bapi_retn_info-message_v3 = l_blank_msgv.
                    bapi_retn_info-message_v4 = l_blank_msgv.
                    bapi_idoc_status          = '51'.
                    PERFORM idoc_status_mbgmcr
                                        TABLES t_edidd
                                               idoc_status
                                               return_variables
                                         USING idoc_contrl
                                               bapi_retn_info
                                               bapi_idoc_status
                                               workflow_result.
                    error_flag = true.

                    CONTINUE.

*                ENDIF.

                  ENDIF.
                ELSE.
                  APPEND goodsmvt_item.
                ENDIF.
              ELSE.
*               AVATOR
                IF ( idoc_contrl-sndprn = 'ATCPSYS'  OR idoc_contrl-sndprn = 'DEPVSFASH' ) AND
                   goodsmvt_item-move_type = '102'.
*                  In case of reversal get corresponding 101 GR
                  " Buffer lookup for LIPS
                  READ TABLE gt_lips_buf INTO DATA(ls_lips_rev)
                         WITH KEY vbeln = goodsmvt_item-deliv_numb_to_search
                                  posnr = goodsmvt_item-deliv_item_to_search.
                  IF sy-subrc = 0.
                    goodsmvt_item-po_number = ls_lips_rev-vgbel.
                    goodsmvt_item-po_item   = ls_lips_rev-vgpos.
                  ENDIF.

                  " Buffer lookup for EKBE
                  LOOP AT gt_ekbe_buf INTO wa_ekbe
                         WHERE ebeln = goodsmvt_item-po_number
                           AND ebelp = goodsmvt_item-po_item
                           AND bwart = '101'
                           AND menge >= goodsmvt_item-entry_qnt
                           AND shkzg = 'S'.

*                    Check if there is already an existing 102 posting
                    READ TABLE gt_ekbe_buf INTO ekbe
                           WITH KEY ebeln = goodsmvt_item-po_number
                                    ebelp = goodsmvt_item-po_item
                                    lfgja = wa_ekbe-lfgja
                                    lfbnr = wa_ekbe-lfbnr
                                    lfpos = wa_ekbe-lfpos
                                    bwart = '102'.
                    IF sy-subrc <> 0.
                      goodsmvt_item-ref_doc_yr = wa_ekbe-lfgja.
                      goodsmvt_item-ref_doc    = wa_ekbe-lfbnr.
                      goodsmvt_item-ref_doc_it = wa_ekbe-lfpos.
                      EXIT.
                    ENDIF.
                  ENDLOOP.
                ELSE.
                  "LIBERTY MBGCMR - determine delibery to seach by PO number and item
                  "Needed as correct delivery number and item is not available in FS1/FS27FS3
                  " Buffer lookup for YUSMM_MBGMCR_LIB
                  READ TABLE gt_yusmm_mbgmcr_lib_buf INTO DATA(ls_lib)
                         WITH TABLE KEY sndprn = idoc_contrl-sndprn.

                  IF sy-subrc = 0.
                    " Buffer lookup for EKBE
                    LOOP AT gt_ekbe_buf INTO wa_ekbe
                           WHERE ebeln = goodsmvt_item-po_number
                             AND ebelp = goodsmvt_item-po_item
                             AND vgabe = '8'
                             AND menge = 0.
                      goodsmvt_item-deliv_numb_to_search = wa_ekbe-belnr.
                      goodsmvt_item-deliv_item_to_search = wa_ekbe-buzei.
                      EXIT.
                    ENDLOOP.
                  ENDIF.
                ENDIF.

                APPEND goodsmvt_item.
              ENDIF.

*          APPEND GOODSMVT_ITEM.

*YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY
            ENDIF. "$TP220206. end inbound delivery

          WHEN 'E1BP2017_GM_SERIALNUMBER'.

            e1bp2017_gm_serialnumber = idoc_data-sdata.
            MOVE-CORRESPONDING e1bp2017_gm_serialnumber
                            TO goodsmvt_serialnumber.

            APPEND goodsmvt_serialnumber.

          WHEN 'Z1BP2017'.

            z1bp2017 = idoc_data-sdata.
*         determine if material is label.
            " Buffer lookup for MARA
            READ TABLE gt_mara_buf INTO ls_mara_prefetch
                   WITH TABLE KEY matnr = goodsmvt_item-material.

            IF sy-subrc = 0 AND ls_mara_prefetch-labor = co_labor_etikett.
              z1bp2017-zbaret = false.
            ENDIF.

*         determine if purchase order must be created first            *
            IF z1bp2017-zbaret = true.
              PERFORM build_po_tables USING idoc_contrl.
              IF error_flag = true.
                PERFORM idoc_status_mbgmcr
                        TABLES t_edidd
                               idoc_status
                               return_variables
                         USING idoc_contrl
                               bapi_retn_info
                               bapi_idoc_status
                               workflow_result.
                EXIT.
              ENDIF.
            ENDIF.
          WHEN 'Y0MM_GM_SERIAL_MAT'. " ERPMM-2668
            DATA ls_serial_mat TYPE y0mm_gm_serial_mat.
            ls_serial_mat = idoc_data-sdata.
            lt_serial_nums = VALUE #( BASE lt_serial_nums ( ls_serial_mat ) ).
        ENDCASE.
      ENDLOOP.

    ENDCATCH.
    IF sy-subrc = 1.
*     write IDoc status-record as error and continue                   *
      CLEAR bapi_retn_info.
      bapi_retn_info-type   = 'E'.
      bapi_retn_info-id     = 'B1'.
      bapi_retn_info-number = '527'.
      bapi_retn_info-message_v1 = idoc_data-segnam.
      bapi_idoc_status      = '51'.
      PERFORM idoc_status_mbgmcr
              TABLES t_edidd
                     idoc_status
                     return_variables
               USING idoc_contrl
                     bapi_retn_info
                     bapi_idoc_status
                     workflow_result.
      CONTINUE.
    ENDIF.
*  break plautdev02.

* beg "$TP220206
    IF gf_inbound_del_flag NE 'X'.                          "$TP220206

* Check if there is an GR for the PO with movement type 107.
* If there is one, and the actual movement type is 101 - change to 109
      CLEAR hi_weora.
      REFRESH: it_ekbe, it_ekbe_rev, it_ekbe_rev_cancel, goodsmvt_item_append.
      " Buffer lookup for Y0MM_MIGO_WEORA
      READ TABLE gt_y0mm_migo_weora_buf INTO DATA(ls_weora_buf)
                           WITH TABLE KEY rcvpor = idoc_contrl-sndprn.

      IF sy-subrc = 0.
        LOOP AT goodsmvt_item.
          IF goodsmvt_item-move_type EQ '101' OR
             goodsmvt_item-move_type EQ '109'.
*    Check if PO is relevant
*    Get order history - GR with movement type 107
            LOOP AT gt_ekbe_buf INTO wa_ekbe
                          WHERE ebeln = goodsmvt_item-po_number
                            AND ebelp = goodsmvt_item-po_item
                            AND bwart = '107'
                            AND weora <> space.
              APPEND CORRESPONDING #( wa_ekbe ) TO it_ekbe.
            ENDLOOP.

*       Get possible reverse documents
            LOOP AT gt_ekbe_buf INTO wa_ekbe
                          WHERE ebeln = goodsmvt_item-po_number
                            AND ebelp = goodsmvt_item-po_item
                            AND bwart = '109'.
              MOVE-CORRESPONDING wa_ekbe TO it_ekbe_rev.
              COLLECT it_ekbe_rev.
            ENDLOOP.

*            Get possible reverse docs from 109
            LOOP AT gt_ekbe_buf INTO wa_ekbe
                     WHERE ebeln = goodsmvt_item-po_number
                       AND ebelp = goodsmvt_item-po_item
                       AND ( bwart = '110' OR
                             bwart = '108' ).
              MOVE-CORRESPONDING wa_ekbe TO it_ekbe_rev_cancel.
              COLLECT it_ekbe_rev_cancel.
            ENDLOOP.


            LOOP AT it_ekbe.
*           Check 109 posting
              LOOP AT it_ekbe_rev WHERE ebeln = it_ekbe-ebeln
                                    AND ebelp = it_ekbe-ebelp
                                    AND lfbnr = it_ekbe-belnr
                                    AND lfpos = it_ekbe-buzei.

*             Is there a reversel for the 109 posting (110).
                LOOP AT it_ekbe_rev_cancel WHERE ebeln = it_ekbe_rev-ebeln
                                             AND ebelp = it_ekbe_rev-ebelp
                                             AND lfbnr = it_ekbe_rev-lfbnr
                                             AND lfpos = it_ekbe_rev-lfpos
                                             AND buzei = it_ekbe_rev-buzei
                                             AND bwart = '110'.

                  IF it_ekbe_rev-bamng EQ it_ekbe_rev_cancel-bamng.
                    DELETE it_ekbe_rev.
                    DELETE it_ekbe_rev_cancel.
                  ELSE.
                    it_ekbe_rev-bamng = it_ekbe_rev-bamng - it_ekbe_rev_cancel-bamng.
                    it_ekbe-bamng = it_ekbe-bamng - it_ekbe_rev-bamng.
                    MODIFY it_ekbe.
                    DELETE it_ekbe_rev.
                    DELETE it_ekbe_rev_cancel.
                  ENDIF.
                ENDLOOP.

*                 No reversel for 109 - subtract from 107
                IF sy-subrc IS NOT INITIAL.
                  it_ekbe-bamng = it_ekbe-bamng - it_ekbe_rev-bamng.
                  MODIFY it_ekbe.
                  DELETE it_ekbe_rev.
                ENDIF.
              ENDLOOP.
            ENDLOOP.

*             Check on reversel of 107 (108)
            LOOP AT it_ekbe.
              LOOP AT it_ekbe_rev_cancel WHERE ebeln EQ it_ekbe-ebeln
                                           AND ebelp EQ it_ekbe-ebelp
                                           AND lfbnr EQ it_ekbe-belnr
                                           AND lfpos EQ it_ekbe-buzei.
                "                                          AND bwart = '108'.

                it_ekbe-bamng = it_ekbe-bamng - it_ekbe_rev_cancel-bamng.
                MODIFY it_ekbe.
              ENDLOOP.
            ENDLOOP.

*       Sum up on document level
            REFRESH it_ekbe_rev.
            CLEAR: it_ekbe_rev, hi_bamng.
            it_ekbe_rev[] = it_ekbe[].
            REFRESH it_ekbe.
            CLEAR it_ekbe.

            LOOP AT it_ekbe_rev.
              it_ekbe-ebeln = it_ekbe_rev-ebeln.
              it_ekbe-ebelp = it_ekbe_rev-ebelp.
              it_ekbe-bamng = it_ekbe_rev-bamng.
              COLLECT it_ekbe.
            ENDLOOP.

            DELETE it_ekbe_rev WHERE bamng EQ 0.


            READ TABLE it_ekbe INDEX 1.
            IF sy-subrc IS INITIAL.
*              LOOP AT goodsmvt_item.
              CLEAR it_ekbe.
              READ TABLE it_ekbe WITH KEY ebeln = goodsmvt_item-po_number
                                          ebelp = goodsmvt_item-po_item.
              IF goodsmvt_item-entry_qnt GT it_ekbe-bamng.
                "Fehler ausgeben
                CLEAR bapi_retn_info.
                bapi_retn_info-type       = 'E'.
                bapi_retn_info-id         = 'Y0MM_IDOCS'.
                bapi_retn_info-number     = '012'.
                bapi_retn_info-message_v1 = goodsmvt_item-po_number.
                bapi_retn_info-message_v2 = goodsmvt_item-po_item.
                bapi_retn_info-message_v3 = l_blank_msgv.
                bapi_retn_info-message_v4 = l_blank_msgv.
                bapi_idoc_status          = '51'.
                PERFORM idoc_status_mbgmcr
                                    TABLES t_edidd
                                           idoc_status
                                           return_variables
                                     USING idoc_contrl
                                           bapi_retn_info
                                           bapi_idoc_status
                                           workflow_result.
                error_flag = true.
                CONTINUE.
              ELSE.
                it_ekbe-bamng = goodsmvt_item-entry_qnt.
                MODIFY it_ekbe INDEX sy-tabix.              "05.06.
              ENDIF.
*              ENDLOOP.

*          Update goodsmvt_item table with 109 movements
              IF error_flag = false.
                LOOP AT goodsmvt_item.
                  CLEAR: hi_bamng, hi_tabix, hi_posted_quant.
                  hi_check_meng = goodsmvt_item-entry_qnt.

                  LOOP AT it_ekbe_rev WHERE ebeln = goodsmvt_item-po_number
                                        AND ebelp = goodsmvt_item-po_item.

                    ADD 1 TO hi_tabix.
                    ADD it_ekbe_rev-bamng TO hi_posted_quant.

                    IF goodsmvt_item-stck_type IS INITIAL.
                      " Buffer lookup for EKPO
                      READ TABLE gt_ekpo_buf INTO DATA(ls_ekpo_stck)
                             WITH TABLE KEY ebeln = goodsmvt_item-po_number
                                            ebelp = goodsmvt_item-po_item.
                      IF sy-subrc = 0.
                        goodsmvt_item-stck_type = ls_ekpo_stck-insmk.
                      ENDIF.
                    ENDIF.

                    goodsmvt_item-move_type = '109'.
                    goodsmvt_item-mvt_ind = 'B'.
                    IF hi_posted_quant LE hi_check_meng.
                      goodsmvt_item-entry_qnt = it_ekbe_rev-bamng.
                    ELSE.
                      IF hi_tabix GT 1.
                        goodsmvt_item-entry_qnt = hi_check_meng - hi_bamng.
                      ELSE.
                        goodsmvt_item-entry_qnt = hi_check_meng.
                      ENDIF.
                    ENDIF.
                    goodsmvt_item-ref_doc = it_ekbe_rev-belnr.
                    goodsmvt_item-ref_doc_it = it_ekbe_rev-buzei.

                    IF hi_tabix EQ 1.
                      MODIFY goodsmvt_item.
                    ELSE.
                      APPEND goodsmvt_item TO goodsmvt_item_append.
                    ENDIF.
                    ADD it_ekbe_rev-bamng TO hi_bamng.

*                 Quantity reached?
                    IF hi_check_meng LE hi_posted_quant.
                      EXIT.
                    ENDIF.

                  ENDLOOP.

                ENDLOOP.
              ENDIF.

            ENDIF.

          ENDIF.
        ENDLOOP.
      ENDIF.

* Append additional items in case of 109 movement
      IF goodsmvt_item_append[] IS NOT INITIAL.
        LOOP AT goodsmvt_item_append.
          goodsmvt_item = goodsmvt_item_append.
          APPEND goodsmvt_item.
        ENDLOOP.
      ENDIF.

* No Items with quantity 0.
      DELETE goodsmvt_item WHERE entry_qnt EQ 0.


*   check error flag
      CHECK error_flag = false.
*   lock purchase orders
*   try to lock the purchase orders
      REFRESH it_lock.
      LOOP AT goodsmvt_item.
        CLEAR it_lock.
        it_lock-ebeln = goodsmvt_item-po_number.
        COLLECT it_lock.
      ENDLOOP.
*   get delay values
      " Buffer lookup for Y0CA_ALE_DELAY
      READ TABLE gt_y0ca_ale_delay_buf INTO y0ca_ale_delay
            WITH TABLE KEY mesty = idoc_contrl-mestyp.
      IF sy-subrc <> 0.
        CLEAR y0ca_ale_delay.
      ENDIF.
      ADD 1 TO y0ca_ale_delay-retry.

      all_locked = space.
      WHILE all_locked = space AND y0ca_ale_delay-retry > 0.
        " Bulk check for existing locks
        REFRESH gt_y0mm_proc_ebeln_buf.
        IF it_lock[] IS NOT INITIAL.
          SELECT * FROM y0mm_proc_ebeln INTO TABLE @gt_y0mm_proc_ebeln_buf
            FOR ALL ENTRIES IN @it_lock WHERE ebeln = @it_lock-ebeln.
        ENDIF.

        LOOP AT it_lock WHERE lock = space.
          READ TABLE gt_y0mm_proc_ebeln_buf WITH TABLE KEY ebeln = it_lock-ebeln TRANSPORTING NO FIELDS.
          IF sy-subrc NE 0.
            " Try to insert lock
            INSERT y0mm_proc_ebeln FROM @( VALUE #( ebeln = it_lock-ebeln ) ).
            IF sy-subrc = 0.
              COMMIT WORK.
              it_lock-lock = 'X'.
              MODIFY it_lock.
            ENDIF.
          ENDIF.
        ENDLOOP.

        READ TABLE it_lock WITH KEY lock = space TRANSPORTING NO FIELDS.
        IF sy-subrc <> 0.
          all_locked = 'X'.
        ELSE.
          WAIT UP TO y0ca_ale_delay-delay SECONDS.
        ENDIF.
        SUBTRACT 1 FROM y0ca_ale_delay-retry.
      ENDWHILE.
*   Create PO's
      LOOP AT it_po_header.
*     prepare item and schedule tables for bapi calls
        REFRESH: it_po_items, it_po_schedules.
        LOOP AT it_all_po_items
                WHERE po_number = it_po_header-po_number.
          CLEAR it_po_items.
          it_po_items = it_all_po_items.
          APPEND it_po_items.
        ENDLOOP.
        LOOP AT it_all_po_schedules
                WHERE po_number = it_po_header-po_number.
          CLEAR it_po_schedules.
          MOVE-CORRESPONDING it_all_po_schedules TO it_po_schedules.
          APPEND it_po_schedules.
        ENDLOOP.
*     call BAPI-function for PO create in this system
*        BAPI_PO_CREATE is obsolete, so coding was converted to BAPI_PO_CREATE1 - BEGIN

        CALL FUNCTION 'Y0MM_PO_BAPI_CONVERT'
          EXPORTING
            i_po_header                  = it_po_header
            i_po_header_add_data         = ls_po_header_add_data                 " Transfer Structure: PO Header Additional Data
            i_po_address                 = ls_po_address                 " BAPI Transfer Structure for Addresses
          IMPORTING
            e_poheader                   = ls_poheader
            e_poheaderx                  = ls_poheaderx
            e_poaddrvendor               = ls_poaddrvendor
          TABLES
            i_po_items                   = it_po_items
            i_po_item_add_data           = lt_po_item_add_data
            i_po_item_schedules          = it_po_schedules
            i_po_item_account_assignment = lt_po_item_account_assignment                 " Transfer Structure: Display/List: PO Account Assignment
            i_po_item_text               = lt_po_item_text
            e_poitem                     = lt_poitem
            e_poitemx                    = lt_poitemx
            e_poschedule                 = lt_poschedule
            e_poschedulex                = lt_poschedulex
            e_poaccount                  = lt_poaccount                 " Account Assignment Fields for Purchase Order
            e_poaccountx                 = lt_poaccountx                 " Account Assignment Fields in Purchase Order (Change Toolbar)
            e_potextitem                 = lt_potextitem
          EXCEPTIONS
            error_ddif_nametab_get       = 1
            error_period_date_convert    = 2
            OTHERS                       = 3.
        IF sy-subrc = 0.

          "External Number Range for items should be considered!
          ls_poheaderx-item_intvl = 'X'.
          CLEAR: lt_return_po.
          CALL FUNCTION 'BAPI_PO_CREATE1' "#EC CI_USAGE_OK[2438131]
            EXPORTING
              poheader         = ls_poheader                " Header Data
              poheaderx        = ls_poheaderx                 " Header Data (Change Parameter)
            IMPORTING
              exppurchaseorder = purchaseorder                 " Purchasing Document Number
            TABLES
              return           = lt_return_po                " Return Parameter
              poitem           = lt_poitem                " Item Data
              poitemx          = lt_poitemx                " Item Data (Change Parameter)
              poschedule       = lt_poschedule                " Delivery Schedule
              poschedulex      = lt_poschedulex.                " Delivery Schedule (Change Parameter)
        ENDIF.
*        BAPI_PO_CREATE is obsolete, so coding was converted to BAPI_PO_CREATE1 - END


        IF sy-subrc NE 0.
*        write IDoc status-record as error
          error_flag = true.
          CLEAR bapi_retn_info.
          bapi_retn_info-type       = 'E'.
          bapi_retn_info-id         = sy-msgid.
          bapi_retn_info-number     = sy-msgno.
          bapi_retn_info-message_v1 = sy-msgv1.
          bapi_retn_info-message_v2 = sy-msgv2.
          bapi_retn_info-message_v3 = sy-msgv3.
          bapi_retn_info-message_v4 = sy-msgv4.
          bapi_idoc_status          = '51'.
          PERFORM idoc_status_mbgmcr
                TABLES t_edidd
                       idoc_status
                       return_variables
                USING idoc_contrl
                       bapi_retn_info
                       bapi_idoc_status
                       workflow_result.
        ELSE.
          IF purchaseorder IS INITIAL.
*           write IDoc status-record as error                       *
            error_flag = true.
            LOOP AT lt_return_po INTO DATA(ls_return_po)."
              CLEAR bapi_retn_info.
              bapi_retn_info-type       = ls_return_po-type.
              bapi_retn_info-id         = ls_return_po-id.
              bapi_retn_info-number     = ls_return_po-number.
              bapi_retn_info-message_v1 = ls_return_po-message_v1.
              bapi_retn_info-message_v2 = ls_return_po-message_v2.
              bapi_retn_info-message_v3 = ls_return_po-message_v3.
              bapi_retn_info-message_v4 = ls_return_po-message_v4.
        bapi_idoc_status          = '51'.
              PERFORM idoc_status_mbgmcr
                    TABLES t_edidd
                           idoc_status
                           return_variables
                     USING idoc_contrl
                           bapi_retn_info
                           bapi_idoc_status
                           workflow_result.
            ENDLOOP.
          ELSE.
            CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
              EXPORTING
                wait = true.
          ENDIF.
        ENDIF.
      ENDLOOP.
*   check error flag
      CHECK error_flag = false.
*   change PO's
      LOOP AT it_ch_po_numbers.
*     prepare item and schedule tables for bapi calls
        REFRESH: it_ch_po_items,
                 it_ch_po_itemsx,
                 it_ch_po_schedules,
                 it_ch_po_schedulex.
*     items
        LOOP AT it_ch_all_po_items
                WHERE po_number = it_ch_po_numbers.
          CLEAR: it_ch_po_items.
          MOVE-CORRESPONDING it_ch_all_po_items TO it_ch_po_items.
          APPEND it_ch_po_items.
        ENDLOOP.
*     item change flags
        LOOP AT it_ch_all_po_itemsx
                WHERE po_number = it_ch_po_numbers.
          CLEAR: it_ch_po_itemsx.
          MOVE-CORRESPONDING it_ch_all_po_itemsx TO it_ch_po_itemsx.
          APPEND it_ch_po_itemsx.
        ENDLOOP.
*     schedules
        LOOP AT it_ch_all_po_schedules
                WHERE po_number = it_ch_po_numbers.
          CLEAR it_ch_po_schedules.
          MOVE-CORRESPONDING it_ch_all_po_schedules TO it_ch_po_schedules.
          APPEND it_ch_po_schedules.
        ENDLOOP.
*     schedules change flags
        LOOP AT it_ch_all_po_schedulex
                WHERE po_number = it_ch_po_numbers.
          CLEAR it_ch_po_schedulex.
          MOVE-CORRESPONDING it_ch_all_po_schedulex TO it_ch_po_schedulex.
          APPEND it_ch_po_schedulex.
        ENDLOOP.
*     call BAPI-function for PO change in this system
        CALL FUNCTION 'BAPI_PO_CHANGE' "#EC CI_USAGE_OK[2438131]
          EXPORTING
            purchaseorder = it_ch_po_numbers
          TABLES
            return        = it_ch_po_return
            poitem        = it_ch_po_items
            poitemx       = it_ch_po_itemsx
            poschedule    = it_ch_po_schedules
            poschedulex   = it_ch_po_schedulex
          EXCEPTIONS
            OTHERS        = 1.
        IF sy-subrc NE 0.
*        write IDoc status-record as error
          error_flag = true.
          CLEAR bapi_retn_info.
          bapi_retn_info-type       = 'E'.
          bapi_retn_info-id         = sy-msgid.
          bapi_retn_info-number     = sy-msgno.
          bapi_retn_info-message_v1 = sy-msgv1.
          bapi_retn_info-message_v2 = sy-msgv2.
          bapi_retn_info-message_v3 = sy-msgv3.
          bapi_retn_info-message_v4 = sy-msgv4.
          bapi_idoc_status          = '51'.
          PERFORM idoc_status_mbgmcr
                TABLES t_edidd
                       idoc_status
                       return_variables
                USING idoc_contrl
                       bapi_retn_info
                       bapi_idoc_status
                       workflow_result.
        ELSE.
          LOOP AT it_ch_po_return WHERE type = 'E' OR type = 'A'.
*          write IDoc status-record as error                       *
            error_flag = true.
            CLEAR bapi_retn_info.
            bapi_retn_info-type       = it_ch_po_return-type.
            bapi_retn_info-id         = it_ch_po_return-id.
            bapi_retn_info-number     = it_ch_po_return-number.
            bapi_retn_info-message_v1 = it_ch_po_return-message_v1.
            bapi_retn_info-message_v2 = it_ch_po_return-message_v1.
            bapi_retn_info-message_v3 = it_ch_po_return-message_v1.
            bapi_retn_info-message_v4 = it_ch_po_return-message_v1.
            bapi_idoc_status          = '51'.
            PERFORM idoc_status_mbgmcr
                  TABLES t_edidd
                         idoc_status
                         return_variables
                   USING idoc_contrl
                         bapi_retn_info
                         bapi_idoc_status
                         workflow_result.
          ENDLOOP.
          IF sy-subrc NE 0.
            CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
              EXPORTING
                wait = true.
          ENDIF.
        ENDIF.
      ENDLOOP.
*   check error flag
      CHECK error_flag = false.
      CHECK hi_flag_etikett = space.
*   before posting goods movement check PO items for deletion flag
      LOOP AT goodsmvt_item.
        CLEAR ekpo-loekz.
        " Buffer lookup for EKPO
        READ TABLE gt_ekpo_buf INTO DATA(ls_ekpo_del)
                                WITH TABLE KEY ebeln = goodsmvt_item-po_number
                                               ebelp = goodsmvt_item-po_item.
        IF sy-subrc = 0.
          ekpo-loekz = ls_ekpo_del-loekz.
        ENDIF.
*     if one PO item is marked for deletion -> error
        IF NOT ekpo-loekz IS INITIAL.
          CLEAR bapi_retn_info.
          bapi_retn_info-type       = 'E'.
          bapi_retn_info-id         = 'Y0MM_IDOCS'.
          bapi_retn_info-number     = '020'.
          bapi_retn_info-message_v1 = goodsmvt_item-po_number.
          bapi_retn_info-message_v2 = goodsmvt_item-po_item.
          bapi_retn_info-message_v3 = l_blank_msgv.
          bapi_retn_info-message_v4 = l_blank_msgv.
          bapi_idoc_status          = '51'.
          PERFORM idoc_status_mbgmcr
                              TABLES t_edidd
                                     idoc_status
                                     return_variables
                               USING idoc_contrl
                                     bapi_retn_info
                                     bapi_idoc_status
                                     workflow_result.
          error_flag = true.
        ENDIF.
      ENDLOOP.
*   check error flag
      CHECK error_flag = false.

*   Hotfix Loxxess - wrong material plant at loxxess
      IF idoc_contrl-sndprn = 'MERSYS'.
        LOOP AT goodsmvt_item.
          IF goodsmvt_item-plant = '9501' OR
             goodsmvt_item-plant = '9502'.
            " ok
          ELSE.
            goodsmvt_item-plant = '95XX'.
          ENDIF.

          MODIFY goodsmvt_item.

          IF goodsmvt_item-move_type EQ 'X53'. " or
            "goodsmvt_item-MOVE_TYPE eq '311'.
            goodsmvt_item-move_type = 'ZZZ'.
            MODIFY goodsmvt_item.
          ENDIF.
        ENDLOOP.
      ENDIF.

* Task 11-59036 inspection stock handling
* If movement type is "321" and an inspection lot exists for material,
* batch and plant then post a usage decision insteaf of a goods movement.
      DATA: ls_qals   TYPE qals,
            l_vcgrp   TYPE qvgruppe,
            l_vcode   TYPE qvcode,
            ls_udata  TYPE bapi2045ud,
            ls_return TYPE bapireturn1,
            l_lines   TYPE sytabix.
      LOOP AT goodsmvt_item.
        IF goodsmvt_item-move_type = '321'.
          " Buffer lookup for QALS
          READ TABLE gt_qals_buf INTO ls_qals
            WITH KEY charg = goodsmvt_item-batch
                     matnr = goodsmvt_item-material
                     werkvorg = goodsmvt_item-plant
                     lagortvorg = goodsmvt_item-stge_loc.
          IF sy-subrc = 0.
            CLEAR: ls_udata, ls_return.
            ls_udata-insplot             = ls_qals-prueflos.
            ls_udata-ud_plant            = ls_qals-werk.
            ls_udata-ud_selected_set     = 'USAGE'.
            ls_udata-ud_code_group       = 'OK/NOK'.
            ls_udata-ud_code             = 'OK'.
            ls_udata-ud_force_completion = 'X'.
            ls_udata-ud_stock_posting    = 'X'.
            ls_udata-ud_recorded_by_user = sy-uname.
            ls_udata-ud_recorded_on_date = sy-datum.
            ls_udata-ud_recorded_at_time = sy-uzeit.
            sy-subrc = 0.
* set usage decision
            CALL FUNCTION 'BAPI_INSPLOT_SETUSAGEDECISION'  "#EC CI_USAGE_OK[2438131]
              EXPORTING
                number  = ls_qals-prueflos
                ud_data = ls_udata
              IMPORTING
                return  = ls_return.
            IF ls_return-type <> 'E' AND ls_return-type <> 'A'.
              CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
                EXPORTING
                  wait = 'X'.
            ELSE.
              CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
            ENDIF.
            REFRESH return.
            MOVE-CORRESPONDING ls_return TO return.
            APPEND return.
            DELETE goodsmvt_item.
          ENDIF.
        ENDIF.
      ENDLOOP.
      DESCRIBE TABLE goodsmvt_item LINES l_lines.
      IF l_lines > 0.

                                                            "S4H-1922
        "S4: If posting is GR + relates to inbound del. with packing we must post via inb. del!
        "check if flag for document flow is set
        IF goodsmvt_code = '01' AND NOT line_exists( goodsmvt_item[ move_type = '107' ] ). "techn. can be checked via T156-KZWES = 'S'!
          IF /spe/cl_cust=>is_vl_mm_active( ) = abap_true.

            "get PO item references (due to different item number length)
            CLEAR lt_po_ref.
            LOOP AT goodsmvt_item INTO DATA(ls_migo_itm) WHERE po_number IS NOT INITIAL
                                                           AND po_item IS NOT INITIAL
                                                           AND deliv_numb_to_search IS INITIAL. "if delivery is provided -> selected in next step!
              ls_po_ref-vgbel = ls_migo_itm-po_number.
              ls_po_ref-vgpos = |{ ls_migo_itm-po_item ALPHA = IN }|.
              APPEND ls_po_ref TO lt_po_ref.
            ENDLOOP.

            " check if packing rel. inbound del. exists
            " also select completed GR items as still this shows that must post via del.
      REFRESH lt_inb_lips.
            IF lt_po_ref IS NOT INITIAL.
        LOOP AT lt_po_ref INTO ls_po_ref.
          LOOP AT gt_lips_buf INTO DATA(ls_lips_prefetch) USING KEY k_ref
            WHERE vgbel = ls_po_ref-vgbel
              AND vgpos = ls_po_ref-vgpos.

            READ TABLE gt_likp_buf INTO DATA(ls_likp_prefetch)
              WITH TABLE KEY vbeln = ls_lips_prefetch-vbeln.
          IF sy-subrc = 0 AND ls_likp_prefetch-vbtyp = '7' AND ls_likp_prefetch-pkstk <> ''.
            APPEND VALUE #( vbeln = ls_lips_prefetch-vbeln
                            posnr = ls_lips_prefetch-posnr
                            werks = ls_lips_prefetch-werks
                            lgort = ls_lips_prefetch-lgort
                            uecha = ls_lips_prefetch-uecha
                            matnr = ls_lips_prefetch-matnr
                            charg = ls_lips_prefetch-charg
                            meins = ls_lips_prefetch-meins
                            vrkme = ls_lips_prefetch-vrkme
                            vgbel = ls_lips_prefetch-vgbel
                            vgpos = ls_lips_prefetch-vgpos
                            wbsta = ls_lips_prefetch-wbsta ) TO lt_inb_lips.
          ENDIF.
        ENDLOOP.
            ENDIF.

            "If we have the inbound as reference use this directly for selection
            IF goodsmvt_item[] IS NOT INITIAL.
        LOOP AT goodsmvt_item INTO ls_migo_itm.
          LOOP AT gt_lips_buf INTO ls_lips_prefetch
            WHERE vbeln = ls_migo_itm-deliv_numb_to_search
              AND ( posnr = ls_migo_itm-deliv_item_to_search OR uecha = ls_migo_itm-deliv_item_to_search ).

            READ TABLE gt_likp_buf INTO ls_likp_prefetch
              WITH TABLE KEY vbeln = ls_lips_prefetch-vbeln.
            IF sy-subrc = 0 AND ls_likp_prefetch-vbtyp = '7' AND ls_likp_prefetch-pkstk <> ''.
              APPEND VALUE #( vbeln = ls_lips_prefetch-vbeln
                              posnr = ls_lips_prefetch-posnr
                              werks = ls_lips_prefetch-werks
                              lgort = ls_lips_prefetch-lgort
                              uecha = ls_lips_prefetch-uecha
                              matnr = ls_lips_prefetch-matnr
                              charg = ls_lips_prefetch-charg
                              meins = ls_lips_prefetch-meins
                              vrkme = ls_lips_prefetch-vrkme
                              vgbel = ls_lips_prefetch-vgbel
                              vgpos = ls_lips_prefetch-vgpos
                              wbsta = ls_lips_prefetch-wbsta ) TO lt_inb_lips.
            ENDIF.
          ENDLOOP.
        ENDLOOP.
            ENDIF.

          ENDIF.
        ENDIF.

        "check if HU managed and get the HUs
        CLEAR: lt_deliv, lt_hu_head, lt_hu_items.
        IF lt_inb_lips IS NOT INITIAL.
    LOOP AT lt_inb_lips INTO DATA(ls_inb_lips_hu).
      READ TABLE gt_t001l_buf INTO DATA(ls_t001l_prefetch)
        WITH TABLE KEY werks = ls_inb_lips_hu-werks
                       lgort = ls_inb_lips_hu-lgort.
      IF sy-subrc = 0 AND ls_t001l_prefetch-xhupf = 'X'.
        INSERT VALUE #( vbeln = |{ ls_inb_lips_hu-vbeln ALPHA = IN }| ) INTO TABLE lt_deliv.
      ENDIF.
    ENDLOOP.
    SORT lt_deliv. DELETE ADJACENT DUPLICATES FROM lt_deliv.
          IF lt_deliv IS NOT INITIAL.
            CALL FUNCTION 'SD_SHIPMENT_DELIVERY_HUS'
              IMPORTING
                et_header   = lt_hu_head
                et_items    = lt_hu_items
              TABLES
                i_deliv     = lt_deliv
              EXCEPTIONS
                hu_changed  = 1
                fatal_error = 2
                OTHERS      = 3.
            IF sy-subrc = 0.
            ENDIF.
          ENDIF.
        ENDIF.

        "Post GR via (inb.) del. update
        IF lt_inb_lips IS NOT INITIAL.
          CLEAR: ls_vbkok, lt_objects, lt_vbeln_hu.

          "now remove inb. del items with GR status no open/in process
          DELETE lt_inb_lips WHERE wbsta CN 'AB'.

          "Build update table
          CLEAR: bapi_retn_info.
          LOOP AT goodsmvt_item INTO ls_migo_itm.
            CLEAR ls_vbpok.

            "get the correct del. item
            "1st with inb. del. reference
            LOOP AT lt_inb_lips INTO ls_inb_lips WHERE vbeln = ls_migo_itm-deliv_numb_to_search
                                                   AND ( posnr = ls_migo_itm-deliv_item_to_search OR uecha = ls_migo_itm-deliv_item_to_search )
                                                   AND matnr = ls_migo_itm-material
                                                   AND charg = ls_migo_itm-batch.
              EXIT. "take first found entry
            ENDLOOP.
            IF sy-subrc <> 0.
              "2nd with PO reference
              ls_po_ref-vgbel = ls_migo_itm-po_number.
              ls_po_ref-vgpos = |{ ls_migo_itm-po_item ALPHA = IN }|.
              READ TABLE lt_inb_lips INTO ls_inb_lips WITH KEY vgbel = ls_po_ref-vgbel
                                                               vgpos = ls_po_ref-vgpos
                                                               matnr = ls_migo_itm-material
                                                               charg = ls_migo_itm-batch.
              IF sy-subrc <> 0.
                " write IDoc status-record as error                                *
                bapi_retn_info-type       = 'E'.
                bapi_retn_info-id         = 'Y0MM_IDOCS'.
                bapi_retn_info-number     = '042'.
                IF ls_migo_itm-deliv_item_to_search IS NOT INITIAL.
                  bapi_retn_info-message_v1 = ls_migo_itm-deliv_numb_to_search.
                  bapi_retn_info-message_v2 = |{ ls_migo_itm-deliv_item_to_search ALPHA = OUT }|.
                ELSE.
                  bapi_retn_info-message_v1 = ls_po_ref-vgbel.
                  bapi_retn_info-message_v2 = |{ ls_po_ref-vgpos ALPHA = OUT }|.
                ENDIF.
                bapi_retn_info-message_v3 = |{ ls_migo_itm-material ALPHA = OUT }|.
                bapi_retn_info-message_v4 = ls_migo_itm-batch.
                bapi_idoc_status          = '51'.
                PERFORM idoc_status_mbgmcr
                        TABLES t_edidd
                               idoc_status
                               return_variables
                         USING idoc_contrl
                               bapi_retn_info
                               bapi_idoc_status
                               workflow_result.
              ENDIF.
            ENDIF.

            "if return info is filled -> error happended
            IF bapi_retn_info IS NOT INITIAL.
              RETURN.
            ENDIF.

            IF ls_migo_itm-entry_uom = ls_inb_lips-meins OR ls_migo_itm-entry_uom IS INITIAL.
              lv_ebumg_bme = ls_migo_itm-entry_qnt.
            ELSE. "otherwise convert
              lv_matnr40 = ls_migo_itm-material.
              CALL FUNCTION 'MD_CONVERT_MATERIAL_UNIT'     "#EC CI_FLDEXT_OK[2215424]
                EXPORTING
                  i_matnr              = lv_matnr40
                  i_in_me              = ls_migo_itm-entry_uom
                  i_out_me             = ls_inb_lips-meins
                  i_menge              = ls_migo_itm-entry_qnt
                IMPORTING
                  e_menge              = lv_ebumg_bme
                EXCEPTIONS
                  error_in_application = 1
                  error                = 2
                  OTHERS               = 3.
              IF sy-subrc <> 0.
                " Implement suitable error handling here
              ENDIF.

            ENDIF.

            ls_vbpok-vbeln_vl = ls_inb_lips-vbeln.
            ls_vbpok-posnr_vl = ls_inb_lips-posnr.
            ls_vbpok-ebumg_bme = lv_ebumg_bme."Base UoM
*            ls_vbpok-spe_ebumg = lv_ebumg_vme."Sales UoM

            APPEND ls_vbpok TO lt_vbpok.

            "remember the HUs per delivery
            APPEND VALUE #( vbeln = ls_inb_lips-vbeln exidv = |{ ls_migo_itm-item_text ALPHA = IN }| ) TO lt_vbeln_hu.
          ENDLOOP.

          "if bapi_retn_info is filled error happened -> nur further processing
          CHECK bapi_retn_info IS INITIAL.

          "Post partial GR
          SORT lt_vbpok BY vbeln_vl posnr_vl.
          LOOP AT lt_vbpok INTO ls_vbpok.

            "header data
            AT NEW vbeln_vl.
              CLEAR: ls_vbkok, lt_vbpok_upd, lt_objects.

              "Fix values copied from VL60 (FM call in method INTERFACE_UPDATE (/SPE/CL_ID_HANDLING))

              "Header
              ls_vbkok-vbeln_vl = ls_vbpok-vbeln_vl.
              ls_vbkok-wabuc = 'X'. "GR posting
              ls_vbkok-wadat_ist = goodsmvt_header-pstng_date.
              ls_vbkok-kzebu = 'X'. "Partial GR

              "needed for HU managed SLOCs
              IF lt_hu_head IS NOT INITIAL.
                ls_vbkok-spe_inb_dlv = 'X'. "inb. del
                ls_vbkok-spe_dist_proc_code = 'C'. "check but no distr.
                ls_vbkok-spe_no_hu_cons_check = 'X'.
                ls_vbkok-spe_ret_hu_update_request = 'A'.
                ls_vbkok-spe_orig_sys = '3'. "ERP
                ls_vbkok-no_lfimg_check_mmli = 'X'. "no del. qty check

                "Add all HUs for this delivery if needed
                LOOP AT lt_vbeln_hu INTO ls_vbeln_hu WHERE vbeln = ls_vbkok-vbeln_vl.
                  READ TABLE lt_hu_head INTO DATA(ls_hu_head) WITH KEY exidv = ls_vbeln_hu-exidv.
                  IF sy-subrc = 0.
                    ls_hu_head-venum = |{ ls_hu_head-venum ALPHA = IN }|.
                    APPEND VALUE pgr_objects( objtyp = '01' objkey = ls_hu_head-venum ) TO lt_objects.
                  ENDIF.
                ENDLOOP.
              ENDIF.

            ENDAT.

            "Item data
            "ls_vbpok-lianp = 'X'.
            APPEND ls_vbpok TO lt_vbpok_upd.

            "Next Delivery -> post
            AT END OF vbeln_vl.

              "Del. update
              SET UPDATE TASK LOCAL.
              CALL FUNCTION 'WS_DELIVERY_UPDATE_2'
                EXPORTING
                  vbkok_wa   = ls_vbkok
                  synchron   = 'X'
                  commit     = 'X'
                  delivery   = ls_vbkok-vbeln_vl
                TABLES
                  vbpok_tab  = lt_vbpok_upd
                  it_objects = lt_objects
                  prot       = lt_prot.

              "check on errors
              LOOP AT lt_prot INTO DATA(ls_prot) WHERE msgty CA 'AE'.
                " write IDoc status-record as error                                *
                CLEAR bapi_retn_info.
                bapi_retn_info-type       = 'E'.
                bapi_retn_info-id         = ls_prot-msgid.
                bapi_retn_info-number     = ls_prot-msgno.
                bapi_retn_info-message_v1 = ls_prot-msgv1.
                bapi_retn_info-message_v2 = ls_prot-msgv2.
                bapi_retn_info-message_v3 = ls_prot-msgv3.
                bapi_retn_info-message_v4 = ls_prot-msgv4.
                bapi_idoc_status          = '51'.
                PERFORM idoc_status_mbgmcr
                        TABLES t_edidd
                               idoc_status
                               return_variables
                         USING idoc_contrl
                               bapi_retn_info
                               bapi_idoc_status
                               workflow_result.
              ENDLOOP.
              " at least one loop -> error -> exit
              IF sy-subrc = 0.
                RETURN.
              ELSE. "no loop -> success
                " write IDoc status-record as success                              *
                CLEAR bapi_retn_info.
                bapi_retn_info-type       = 'S'.
                bapi_retn_info-id         = 'Y0MM_IDOCS'.
                bapi_retn_info-number     = '043'.
                bapi_retn_info-message_v1 = ls_vbkok-vbeln_vl.
                bapi_idoc_status          = '53'.
                PERFORM idoc_status_mbgmcr
                        TABLES t_edidd
                               idoc_status
                               return_variables
                         USING idoc_contrl
                               bapi_retn_info
                               bapi_idoc_status
                               workflow_result.

                "After posting check&save SSCCs for inbound del.
                ycl_sd_functions_tm_if=>update_sscc_verifation( EXPORTING it_gm_items = goodsmvt_item[]
                                                                          iv_vbeln = ls_vbkok-vbeln_vl
                                                                          iv_docnum = idoc_contrl-docnum
                                                                          iv_commit = 'X'
                                                                IMPORTING ev_fail = DATA(lv_sscc_ver_fail) ).
                "failed SSCC verifcation? -> Set warning status record
                IF lv_sscc_ver_fail = 'X'.
                  CLEAR bapi_retn_info.
                  bapi_retn_info-type       = 'W'.
                  bapi_retn_info-id         = 'Y0MM_IDOCS'.
                  bapi_retn_info-number     = '048'.
                  bapi_retn_info-message_v1 = sy-msgv1.
                  bapi_retn_info-message_v2 = sy-msgv2.
                  bapi_retn_info-message_v3 = sy-msgv3.
                  bapi_retn_info-message_v4 = sy-msgv4.
                  bapi_idoc_status          = '52'.
                  PERFORM idoc_status_mbgmcr
                          TABLES t_edidd
                                 idoc_status
                                 return_variables
                           USING idoc_contrl
                                 bapi_retn_info
                                 bapi_idoc_status
                                 workflow_result.
                ENDIF.

              ENDIF.

            ENDAT.

          ENDLOOP.

        ELSE.  "MIGO posting

          "For specific partner we need to perform first a transfer posting
          "e.g.: Scrap from blocked stock -> we need first to perform a move to unr. stock
          PERFORM transfer_posting USING 'X'. "Parameter: pre-posting

          " check error flag
          CHECK error_flag = false.

          " call BAPI-function in this system                                  *
          CALL FUNCTION 'BAPI_GOODSMVT_CREATE'    "#EC CI_USAGE_OK[2438131]
            EXPORTING
              goodsmvt_header       = goodsmvt_header
              goodsmvt_code         = goodsmvt_code
              testrun               = testrun
            IMPORTING
              goodsmvt_headret      = goodsmvt_headret
              materialdocument      = materialdocument
              matdocumentyear       = matdocumentyear
            TABLES
              goodsmvt_item         = goodsmvt_item
              goodsmvt_serialnumber = goodsmvt_serialnumber
              return                = return
            EXCEPTIONS
              OTHERS                = 1.
        ENDIF.

      ENDIF.
*tp eob
      IF sy-subrc <> 0.
*     write IDoc status-record as error                                *
        CLEAR bapi_retn_info.
        bapi_retn_info-type       = 'E'.
        bapi_retn_info-id         = sy-msgid.
        bapi_retn_info-number     = sy-msgno.
        bapi_retn_info-message_v1 = sy-msgv1.
        bapi_retn_info-message_v2 = sy-msgv2.
        bapi_retn_info-message_v3 = sy-msgv3.
        bapi_retn_info-message_v4 = sy-msgv4.
        bapi_idoc_status          = '51'.
        PERFORM idoc_status_mbgmcr
                TABLES t_edidd
                       idoc_status
                       return_variables
                 USING idoc_contrl
                       bapi_retn_info
                       bapi_idoc_status
                       workflow_result.

    " RBDC - Save document/IDOC information
        IF idoc_contrl-mescod EQ 'RDC'.
          READ TABLE goodsmvt_item INDEX 1.

    " Buffer lookup for T001W
    READ TABLE gt_t001w_buf INTO DATA(ls_t001w_rbdc)
           WITH TABLE KEY werks = goodsmvt_item-plant.
    IF sy-subrc = 0.
      l_bwkey = ls_t001w_rbdc-bwkey.
    ENDIF.

    " Buffer lookup for T001K
    READ TABLE gt_t001k_buf INTO DATA(ls_t001k_rbdc)
           WITH TABLE KEY bwkey = l_bwkey.
    IF sy-subrc = 0.
      l_bukrs = ls_t001k_rbdc-bukrs.
    ENDIF.

    " Buffer lookup for YUDC_TRANS
    READ TABLE gt_yudc_trans_buf INTO DATA(ls_yudc_rbdc)
                  WITH TABLE KEY bukrs = l_bukrs
                                 gm_code = goodsmvt_code
                                 lgort_from = goodsmvt_item-stge_loc
                                 bwart = goodsmvt_item-move_type
                                 lgort_to = goodsmvt_item-move_stloc.
    IF sy-subrc = 0.
      wa_run_i-zztrans_id = ls_yudc_rbdc-zztrans_id.
    ENDIF.

          wa_run_i-zzfacility_id = idoc_contrl-sndprn.
          wa_run_i-docnum = idoc_contrl-docnum.
          wa_run_i-status = bapi_idoc_status.
          wa_run_i-belnr  = materialdocument.
          wa_run_i-zzdate = sy-datum.
          wa_run_i-zztime = sy-uzeit.

          hi_arckey = idoc_contrl-arckey.
          SHIFT hi_arckey LEFT DELETING LEADING ' '.

          DO.
            SHIFT hi_arckey LEFT.
            IF hi_arckey(1) EQ space.
              SHIFT hi_arckey LEFT DELETING LEADING ' '.
              EXIT.
            ENDIF.
          ENDDO.
          wa_run_i-arckey = hi_arckey.

          MODIFY yudc_int_run_i FROM wa_run_i .
        ENDIF.

      ELSE.
        LOOP AT return.
          IF NOT return IS INITIAL.
            CLEAR bapi_retn_info.
            MOVE-CORRESPONDING return TO bapi_retn_info.
            IF return-type = 'A' OR return-type = 'E'.
              error_flag = 'X'.
            ENDIF.
            APPEND bapi_retn_info.
          ENDIF.
        ENDLOOP.
        LOOP AT bapi_retn_info.
*       write IDoc status-record                                       *
          IF error_flag IS INITIAL.
            bapi_idoc_status = '53'.
          ELSE.
            bapi_idoc_status = '51'.
            IF bapi_retn_info-type = 'S'.
              CONTINUE.
            ENDIF.
          ENDIF.
          PERFORM idoc_status_mbgmcr
                  TABLES t_edidd
                         idoc_status
                         return_variables
                   USING idoc_contrl
                         bapi_retn_info
                         bapi_idoc_status
                         workflow_result.

    " RBDC - Save document/IDOC information
          IF idoc_contrl-mescod EQ 'RDC'.
            READ TABLE goodsmvt_item INDEX 1.
      " Buffer lookup for YUDC_TRANS
      READ TABLE gt_yudc_trans_buf INTO ls_yudc_rbdc
                    WITH TABLE KEY bukrs = l_bukrs
                                   gm_code = goodsmvt_code
                                   lgort_from = goodsmvt_item-stge_loc
                                   bwart = goodsmvt_item-move_type
                                   lgort_to = goodsmvt_item-move_stloc.
      IF sy-subrc = 0.
        wa_run_i-zztrans_id = ls_yudc_rbdc-zztrans_id.
      ENDIF.

            wa_run_i-zzfacility_id = idoc_contrl-sndprn.
            wa_run_i-docnum = idoc_contrl-docnum.
            wa_run_i-status = bapi_idoc_status.
            wa_run_i-belnr  = materialdocument.
            wa_run_i-zzdate = sy-datum.
            wa_run_i-zztime = sy-uzeit.

            hi_arckey = idoc_contrl-arckey.
            SHIFT hi_arckey LEFT DELETING LEADING ' '.

            DO.
              SHIFT hi_arckey LEFT.
              IF hi_arckey(1) EQ space.
                SHIFT hi_arckey LEFT DELETING LEADING ' '.
                EXIT.
              ENDIF.
            ENDDO.
            wa_run_i-arckey = hi_arckey.

            MODIFY yudc_int_run_i FROM wa_run_i .
          ENDIF.

        ENDLOOP.
        IF sy-subrc <> 0 AND materialdocument IS NOT INITIAL.
*      'RETURN' is empty write idoc status-record as successful        *
          PERFORM insert_status USING '53' 'S' 'M7' '060' materialdocument space space space.
          CLEAR bapi_retn_info.
          bapi_retn_info-type       = 'S'.
          bapi_retn_info-id         = 'B1'.
          bapi_retn_info-number     = '501'.
          bapi_retn_info-message_v1 = 'CREATEFROMDATA'.
          bapi_idoc_status          = '53'.
          PERFORM idoc_status_mbgmcr
                  TABLES t_edidd
                         idoc_status
                         return_variables
                   USING idoc_contrl
                         bapi_retn_info
                         bapi_idoc_status
                         workflow_result.

    " RBDC - Save document/IDOC information
          IF idoc_contrl-mescod EQ 'RDC'.
            READ TABLE goodsmvt_item INDEX 1.
      " Buffer lookup for YUDC_TRANS
      READ TABLE gt_yudc_trans_buf INTO ls_yudc_rbdc
                    WITH TABLE KEY bukrs = l_bukrs
                                   gm_code = goodsmvt_code
                                   lgort_from = goodsmvt_item-stge_loc
                                   bwart = goodsmvt_item-move_type
                                   lgort_to = goodsmvt_item-move_stloc.
      IF sy-subrc = 0.
        wa_run_i-zztrans_id = ls_yudc_rbdc-zztrans_id.
      ENDIF.

            wa_run_i-zzfacility_id = idoc_contrl-sndprn.
            wa_run_i-docnum = idoc_contrl-docnum.
            wa_run_i-status = '53'.
            wa_run_i-belnr  = materialdocument.
            wa_run_i-zzdate = sy-datum.
            wa_run_i-zztime = sy-uzeit.

            hi_arckey = idoc_contrl-arckey.
            SHIFT hi_arckey LEFT DELETING LEADING ' '.

            DO.
              SHIFT hi_arckey LEFT.
              IF hi_arckey(1) EQ space.
                SHIFT hi_arckey LEFT DELETING LEADING ' '.
                EXIT.
              ENDIF.
            ENDDO.
            wa_run_i-arckey = hi_arckey.

            MODIFY yudc_int_run_i FROM wa_run_i .
          ENDIF.

          "For specific partner we need to perform a transfer posting
          "e.g.: cancelation of Scrap from blocked: transfer to block after cancelation
          PERFORM transfer_posting USING ''. "Parameter: post-posting

        ENDIF.
        IF error_flag IS INITIAL.
*       write linked object keys                                       *
          CLEAR return_variables.
          return_variables-wf_param = 'Appl_Objects'.
          return_variables-doc_number+00 = materialdocument.
          return_variables-doc_number+10 = matdocumentyear.
          APPEND return_variables.
        ENDIF.
      ENDIF.

*     BR process - transfer posting
      REFRESH lt_return.
      lk_tr_posted = 0.
      PERFORM transfer_posting_br TABLES lt_return
                                   USING goodsmvt_header-ref_doc_no lk_tr_posted.

      IF lk_tr_posted = 0.
        CLEAR return_variables.
        return_variables-wf_param = co_error_idocs.
        return_variables-doc_number = idoc_contrl-docnum.
        APPEND return_variables.
        LOOP AT lt_return.
          PERFORM insert_status
          USING '51' lt_return-type lt_return-id lt_return-number
                     lt_return-message_v1 lt_return-message_v2
                     lt_return-message_v3 lt_return-message_v4.
        ENDLOOP.
      ENDIF.

    ELSE.                                "Beg              "$TP220206
      LOOP AT gt_inb_item.
        MOVE-CORRESPONDING  gt_inb_item TO  gt_inb_item_det.
        APPEND gt_inb_item_det.

        AT END OF vbeln.
          CALL FUNCTION 'Y0MM_VL32N'
            EXPORTING
              vbeln          = gt_inb_item-vbeln
              i_optio        = gs_ctu_params
            TABLES
              i_item_tab     = gt_inb_item_det
              e_messtab      = gt_mess
            EXCEPTIONS
              call_tr_failed = 1
              OTHERS         = 2.

          IF sy-subrc <> 0.
            LOOP AT gt_mess.
              CLEAR bapi_retn_info.
              bapi_retn_info-type       = 'I'.
              bapi_retn_info-id         = gt_mess-msgid.
              bapi_retn_info-number     = gt_mess-msgnr.
              bapi_retn_info-message_v1 = gt_mess-msgv1.
              bapi_retn_info-message_v2 = gt_mess-msgv2.
              bapi_retn_info-message_v3 = gt_mess-msgv3.
              bapi_retn_info-message_v4 = gt_mess-msgv4.
              bapi_idoc_status          = '51'.
              PERFORM idoc_status_mbgmcr
                      TABLES t_edidd
                             idoc_status
                             return_variables
                       USING idoc_contrl
                             bapi_retn_info
                             bapi_idoc_status
                             workflow_result.
            ENDLOOP.
          ELSE.
            LOOP AT gt_mess.
              CLEAR bapi_retn_info.
              bapi_retn_info-type       = 'I'.
              bapi_retn_info-id         = gt_mess-msgid.
              bapi_retn_info-number     = gt_mess-msgnr.
              bapi_retn_info-message_v1 = gt_mess-msgv1.
              bapi_retn_info-message_v2 = gt_mess-msgv2.
              bapi_retn_info-message_v3 = gt_mess-msgv3.
              bapi_retn_info-message_v4 = gt_mess-msgv4.
              bapi_idoc_status          = '53'.
            ENDLOOP.
            PERFORM idoc_status_mbgmcr
                    TABLES t_edidd
                           idoc_status
                           return_variables
                     USING idoc_contrl
                           bapi_retn_info
                           bapi_idoc_status
                           workflow_result.

          ENDIF.
          REFRESH gt_inb_item_det.


        ENDAT.

      ENDLOOP.
    ENDIF.                               "end      "$TP220206

    " ERPMM-2668
    IF NOT lt_serial_nums IS INITIAL AND NOT line_exists( idoc_status[ status = '51' ] ).
      y0mm_cl_visit_idoc_helper=>create_log(
        EXPORTING
          is_head        = e1bp2017_gm_head_01
          it_items       = lt_items
          it_serial_nums = lt_serial_nums
          iv_idoc_num    = idoc_contrl-docnum
        IMPORTING
          ev_subrc       = DATA(lv_subrc)
          et_bapiret2    = DATA(lt_ret)
      ).
      IF lt_ret IS NOT INITIAL.
        LOOP AT lt_ret INTO DATA(ls_ret).
          CLEAR idoc_status.
          idoc_status-docnum   = idoc_contrl-docnum.
          idoc_status-msgty    = ls_ret-type.
          idoc_status-msgid    = '00'.
          idoc_status-msgno    = '368'.
          idoc_status-msgv1    = ls_ret-message.
          idoc_status-repid    = sy-repid.
          idoc_status-status   = '52'.
          APPEND idoc_status.
        ENDLOOP.

      ENDIF.
    ENDIF.

  ENDLOOP.                             " idoc_contrl

ENDFUNCTION.
*&---------------------------------------------------------------------*
*&      Form  TRANSFER_POSTING
*&---------------------------------------------------------------------*
*       Post the necessary transfers (LGORT to LGORT)
*----------------------------------------------------------------------*
FORM transfer_posting_br TABLES lt_return
                         USING vbeln
                               us_posted TYPE i.

  DATA: it_lips     LIKE lips OCCURS 0 WITH HEADER LINE,
        it_braziltr LIKE ybrmm_idoc_tr OCCURS 0 WITH HEADER LINE.

  DATA: lk_meins TYPE meins,
        lk_peinh TYPE peinh,
        lk_bwprs TYPE bwprs,
        lk_menge TYPE lfimg.

* parameters
  DATA: lk_head LIKE bapi2017_gm_head_01,
        lk_code LIKE bapi2017_gm_code,
        lt_item LIKE bapi2017_gm_item_create OCCURS 0 WITH HEADER LINE.
* return paramteres
  DATA: lk_mblnr LIKE bapi2017_gm_head_ret-mat_doc,
        lk_mjahr LIKE bapi2017_gm_head_ret-doc_year.

* init
  CLEAR: lk_head,
         lk_code,
         lk_mblnr,
         lk_mjahr.

  REFRESH: lt_item,
           lt_return.

  REFRESH: it_lips, it_braziltr.


* item data
  LOOP AT goodsmvt_item.
    CLEAR it_lips.
    it_lips-werks = goodsmvt_item-plant.
    it_lips-lgort = goodsmvt_item-stge_loc.
    it_lips-matnr = goodsmvt_item-material.
    it_lips-vrkme = goodsmvt_item-entry_uom.
    it_lips-lfimg = goodsmvt_item-entry_qnt.
    it_lips-charg = goodsmvt_item-batch.
    COLLECT it_lips.
  ENDLOOP.

  us_posted = 1.
* remove items with zero values (main items of items to be splitted)
  DELETE it_lips WHERE lfimg = 0.
  CHECK it_lips[] IS NOT INITIAL. "Nothing to do

* get customizing settings
  REFRESH it_braziltr.
  LOOP AT it_lips.
    " Buffer lookup for YBRMM_IDOC_TR
    READ TABLE gt_ybrmm_idoc_tr_buf INTO DATA(ls_br_tr)
      WITH TABLE KEY mestyp = idoc_contrl-mestyp
                     werks  = it_lips-werks
                     lgort  = it_lips-lgort.
    IF sy-subrc = 0.
      APPEND ls_br_tr TO it_braziltr.
    ENDIF.
  ENDLOOP.
  CHECK it_braziltr[] IS NOT INITIAL.

* create header
  lk_code-gm_code    = '04'.      "Transfer Posting
  lk_head-pstng_date = sy-datum.
  lk_head-doc_date   = sy-datum.
  lk_head-ref_doc_no = vbeln.
* create items
  LOOP AT it_lips.
    CLEAR: lt_item,
           it_braziltr.
*   get settings
    READ TABLE it_braziltr WITH KEY werks = it_lips-werks
                                    lgort = it_lips-lgort.
    CHECK sy-subrc = 0.
*   set item data
    lt_item-material  = it_lips-matnr.
    lt_item-plant     = it_lips-werks.
    lt_item-stge_loc  = it_braziltr-lgort_from.
    lt_item-batch     = it_lips-charg.
    lt_item-entry_qnt = it_lips-lfimg.
    lt_item-entry_uom = it_lips-vrkme.
*   set transfer target
    lt_item-move_mat   = it_lips-matnr.
    lt_item-move_plant = it_lips-werks.
    lt_item-move_stloc = it_braziltr-lgort_to.
    lt_item-move_batch = it_lips-charg.
    lt_item-move_type  = it_braziltr-bwart.
    lt_item-mvt_ind    = it_braziltr-kzbew.
    lt_item-no_more_gr = 'X'.
*   nota fiscal part
*   Vendor and Tax Code
    lt_item-vendor   = it_braziltr-lifnr.
    lt_item-tax_code = it_braziltr-mwskz.
*   calculate base amount - price is stored in tax price 1 field of the material master
    IF it_braziltr-calc_base_amount IS NOT INITIAL.
*      get data
      " Buffer lookup for MARA
      READ TABLE gt_mara_buf INTO DATA(ls_mara_br)
        WITH TABLE KEY matnr = it_lips-matnr.
      IF sy-subrc = 0.
        lk_meins = ls_mara_br-meins.
      ENDIF.

      " Buffer lookup for MBEW
      READ TABLE gt_mbew_buf INTO DATA(ls_mbew_br)
        WITH TABLE KEY matnr = it_lips-matnr
                       bwkey = it_lips-werks.
      IF sy-subrc = 0.
        lk_peinh = ls_mbew_br-peinh.
        lk_bwprs = ls_mbew_br-bwprs.
        IF it_lips-vrkme NE lk_meins. "unit conversion
          CALL FUNCTION 'Y0CA_MATERIAL_UNIT_CONVERSION'
            EXPORTING
              input             = it_lips-lfimg
              matnr             = it_lips-matnr
              source_meins      = it_lips-vrkme
              target_meins      = lk_meins
            IMPORTING
              output            = lk_menge
            EXCEPTIONS
              invalid_material  = 1
              conversion_failed = 2
              OTHERS            = 3.
          IF sy-subrc NE 0.
            lk_menge = it_lips-lfimg.
          ENDIF.
        ELSE.
          lk_menge = it_lips-lfimg.
        ENDIF.
*         calculate
        lt_item-ext_base_amount = ( lk_menge / lk_peinh ) * lk_bwprs.
      ENDIF.
    ENDIF.
*
    APPEND lt_item.
  ENDLOOP.

* only if entries were relevant process the goods movement
* the check is this late because of possible masked entries
  CHECK NOT lt_item[] IS INITIAL.

* Commit before posting: GM create cannot be processed twice wihtout commits in between
*                        GR to PO was alreadey posted, stock transfer posted now -> commit before posting
  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
    EXPORTING
      wait = 'X'.
* post transfers
  CALL FUNCTION 'BAPI_GOODSMVT_CREATE'  "#EC CI_USAGE_OK[2438131]
    EXPORTING
      goodsmvt_header  = lk_head
      goodsmvt_code    = lk_code
    IMPORTING
      materialdocument = lk_mblnr
      matdocumentyear  = lk_mjahr
    TABLES
      goodsmvt_item    = lt_item
      return           = lt_return.
  IF lk_mblnr IS INITIAL.
    us_posted = 0.
  ELSE.
*    success - commit and insert status with document number
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.
    PERFORM insert_status
      USING '53' 'S' 'M7' '060' lk_mblnr space space space.
    us_posted = 1.
  ENDIF.

ENDFORM.                    "TRANSFER_POSTING_BR
FORM transfer_posting USING p_pre_posting TYPE flag.
  DATA: lv_mat_doc        TYPE bapi2017_gm_head_ret-mat_doc,
        ls_gm_head        TYPE bapi2017_gm_head_01,
        ls_gm_item_create TYPE bapi2017_gm_item_create,
        lt_gm_item_create TYPE TABLE OF bapi2017_gm_item_create.

  SET UPDATE TASK LOCAL.

  "Perform transfer posting if needed
  CLEAR: ls_gm_head, lt_gm_item_create.

  "check cust.
  " Buffer lookup for Y0MM_MBGMCR_TR
  REFRESH lt_mbgmcr_tr.
  LOOP AT gt_y0mm_mbgmcr_tr_buf INTO DATA(ls_tr_buf)
    WHERE sndprn = idoc_contrl-sndprn
      AND transfer = p_pre_posting.
    APPEND ls_tr_buf TO lt_mbgmcr_tr.
  ENDLOOP.
  CHECK lt_mbgmcr_tr IS NOT INITIAL.

  "process after the standard MIGO -> then first commit as multiple calls w/o commit not allowed
  IF p_pre_posting = ''.
    COMMIT WORK AND WAIT.
  ENDIF.

  LOOP AT goodsmvt_item ASSIGNING FIELD-SYMBOL(<fs_goodsmvt_item>).
    "relevant?
    READ TABLE lt_mbgmcr_tr INTO DATA(ls_mbgmcr_tr) WITH KEY move_type = <fs_goodsmvt_item>-move_type
                                                             stck_type = <fs_goodsmvt_item>-stck_type.
    CHECK sy-subrc = 0.

    "clear stock type in original item
    CLEAR <fs_goodsmvt_item>-stck_type.

    "take over fields
    ls_gm_item_create = <fs_goodsmvt_item>.
    ls_gm_item_create-move_type = ls_mbgmcr_tr-move_type_tr.
    ls_gm_item_create-move_mat = ls_gm_item_create-material.
    ls_gm_item_create-move_plant = ls_gm_item_create-plant.
    ls_gm_item_create-move_stloc = ls_gm_item_create-stge_loc.
    ls_gm_item_create-move_batch = ls_gm_item_create-batch.
    CLEAR: ls_gm_item_create-move_reas.

    APPEND ls_gm_item_create TO lt_gm_item_create.
  ENDLOOP.

  CHECK lt_gm_item_create IS NOT INITIAL.

  "Header is same as original posting
  ls_gm_head = goodsmvt_header.

  " call BAPI-function in this system
  CLEAR: lv_mat_doc, return.
  CALL FUNCTION 'BAPI_GOODSMVT_CREATE' "#EC CI_USAGE_OK[2438131]
    EXPORTING
      goodsmvt_header  = ls_gm_head
      goodsmvt_code    = '04' "fix transfer
      testrun          = testrun
    IMPORTING
      materialdocument = lv_mat_doc
    TABLES
      goodsmvt_item    = lt_gm_item_create
      return           = return
    EXCEPTIONS
      OTHERS           = 1.

  "Error?
  LOOP AT return INTO DATA(ls_return) WHERE type CA 'EAX'.
    CLEAR bapi_retn_info.
    bapi_retn_info-type       = 'E'.
    bapi_retn_info-id         = ls_return-id.
    bapi_retn_info-number     = ls_return-number.
    bapi_retn_info-message_v1 = ls_return-message_v1.
    bapi_retn_info-message_v2 = ls_return-message_v2.
    bapi_retn_info-message_v3 = ls_return-message_v3.
    bapi_retn_info-message_v4 = ls_return-message_v4.
    bapi_idoc_status          = '51'.
    PERFORM idoc_status_mbgmcr
            TABLES t_edidd
                   idoc_status
                   return_variables
             USING idoc_contrl
                   bapi_retn_info
                   bapi_idoc_status
                   workflow_result.
  ENDLOOP.
  IF sy-subrc = 0. "Error
    error_flag = 'X'.
    ROLLBACK WORK.

  ELSEIF lv_mat_doc IS NOT INITIAL.
    COMMIT WORK AND WAIT.

    " 'RETURN' has no errors -> write idoc status-record as successful        *
    PERFORM insert_status USING '53' 'S' 'Y0MM_IDOCS' '049' lv_mat_doc space space space.
    CLEAR bapi_retn_info.
    bapi_retn_info-type       = 'S'.
    bapi_retn_info-id         = 'B1'.
    bapi_retn_info-number     = '501'.
    bapi_retn_info-message_v1 = 'CREATEFROMDATA'.
    bapi_idoc_status          = '53'.
    PERFORM idoc_status_mbgmcr
            TABLES t_edidd
                   idoc_status
                   return_variables
             USING idoc_contrl
                   bapi_retn_info
                   bapi_idoc_status
                   workflow_result.
  ENDIF.
ENDFORM.

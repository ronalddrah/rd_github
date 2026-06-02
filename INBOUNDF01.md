*----------------------------------------------------------------------*
***INCLUDE LY0_PP_FM_IDOC_INBOUNDF01 .
*----------------------------------------------------------------------*
DATA: BEGIN OF ty_mara_buf,
        matnr TYPE matnr,
        mtart TYPE mtart,
        meins TYPE meins,
        xchpf TYPE xchpf,
        bismt TYPE bismt,
      END OF ty_mara_buf.
DATA: gt_mara_buf HASHED TABLE OF ty_mara_buf WITH UNIQUE KEY matnr
                                              WITH NON-UNIQUE SORTED KEY bismt COMPONENTS bismt.

DATA: BEGIN OF ty_mkal_buf,
        matnr TYPE matnr,
        werks TYPE werks_d,
        verid TYPE verid,
        adatu TYPE adatu,
      END OF ty_mkal_buf.
DATA: gt_mkal_buf SORTED TABLE OF ty_mkal_buf WITH NON-UNIQUE KEY matnr werks
                                              WITH NON-UNIQUE KEY matnr_werks COMPONENTS matnr werks.

DATA: BEGIN OF ty_mch1_buf,
        matnr TYPE matnr,
        werks TYPE werks_d,
        charg TYPE charg_d,
      END OF ty_mch1_buf.
DATA: gt_mch1_buf SORTED TABLE OF ty_mch1_buf WITH NON-UNIQUE KEY matnr charg.

DATA: BEGIN OF ty_plaf_buf,
        plnum TYPE plnum,
        pwwrk TYPE werks_d,
      END OF ty_plaf_buf.
DATA: gt_plaf_buf HASHED TABLE OF ty_plaf_buf WITH UNIQUE KEY plnum.

DATA: gt_rbfqty_buf TYPE HASHED TABLE OF y0pp_calc_rbfqty WITH UNIQUE KEY matnr pstyp.
DATA: gt_svpo_buf TYPE HASHED TABLE OF y0mm_svpo_fixval WITH UNIQUE KEY matnr werks ponum.
DATA: gt_fill_plant_buf TYPE HASHED TABLE OF y0pp_fill_plant WITH UNIQUE KEY werks_prod.
DATA: gt_rem_srvplnt_buf TYPE HASHED TABLE OF y0pp_rem_srvplnt WITH UNIQUE KEY werks.
DATA: gt_zatpde_send_buf TYPE HASHED TABLE OF y0pp_zatpde_send WITH UNIQUE KEY plnum.
DATA: gt_rem_service_buf TYPE SORTED TABLE OF y0pp_rem_service WITH NON-UNIQUE KEY hmatn werks.
DATA: gt_zatpde_calc_buf TYPE HASHED TABLE OF y0pp_zatpde_calc WITH UNIQUE KEY sender plorder display component.

DATA: BEGIN OF ty_mseg_buf,
        matnr TYPE matnr,
        werks TYPE werks_d,
        charg TYPE charg_d,
        aufnr TYPE aufnr,
      END OF ty_mseg_buf.
DATA: gt_mseg_buf HASHED TABLE OF ty_mseg_buf WITH UNIQUE KEY matnr werks charg.

DATA: BEGIN OF ty_ckmlmv013_buf,
        aufnr TYPE aufnr,
        verid TYPE verid,
      END OF ty_ckmlmv013_buf.
DATA: gt_ckmlmv013_buf HASHED TABLE OF ty_ckmlmv013_buf WITH UNIQUE KEY aufnr.

DATA: BEGIN OF ty_cabn_buf,
        atinn TYPE atinn,
        atnam TYPE atnam,
        anzst TYPE anzst,
        atfor TYPE atfor,
      END OF ty_cabn_buf.
DATA: gt_cabn_buf HASHED TABLE OF ty_cabn_buf WITH UNIQUE KEY atnam.

DATA: BEGIN OF ty_class_chars_buf,
        atnam TYPE atnam,
      END OF ty_class_chars_buf.
DATA: gt_class_chars_buf HASHED TABLE OF ty_class_chars_buf WITH UNIQUE KEY atnam.

DATA: BEGIN OF ty_char_detail_buf,
        atnam TYPE atnam,
        atbew TYPE atbew,
      END OF ty_char_detail_buf.
DATA: gt_char_detail_buf HASHED TABLE OF ty_char_detail_buf WITH UNIQUE KEY atnam.

*&---------------------------------------------------------------------*
*&      Form  ZAREPBF_IDOC_PARSE
*&---------------------------------------------------------------------*
* Change : RBDK910355
* Autor:  Pau-Rd
*--------------------------------------------
FORM zarepbf_idoc_parse.

  DATA: h_menge   TYPE sa_erfmg,
        lv_dd_map TYPE abap_bool.

  TYPES: BEGIN OF ty_rem_srvplnt_buf_local,
           werks TYPE werks_d,
         END OF ty_rem_srvplnt_buf_local.

  TYPES: BEGIN OF ty_rem_service_buf,
           hmatn TYPE matnr,
           werks TYPE werks_d,
         END OF ty_rem_service_buf.

  DATA: lt_matnr_keys TYPE STANDARD TABLE OF ty_mara_buf WITH EMPTY KEY,
        lt_mkal_keys  TYPE STANDARD TABLE OF ty_mkal_buf WITH EMPTY KEY,
        lt_mch1_keys  TYPE STANDARD TABLE OF ty_mch1_buf WITH EMPTY KEY,
        lt_plaf_keys  TYPE STANDARD TABLE OF ty_plaf_buf WITH EMPTY KEY,
        lt_rbfqty_keys TYPE STANDARD TABLE OF ty_mara_buf WITH EMPTY KEY,
        lt_werks_keys TYPE STANDARD TABLE OF ty_rem_srvplnt_buf_local WITH EMPTY KEY,
        lt_rem_service_keys TYPE STANDARD TABLE OF ty_rem_service_buf WITH EMPTY KEY,
        lt_char_keys TYPE STANDARD TABLE OF ty_cabn_buf WITH EMPTY KEY.

  " Collect all keys for pre-fetching
  LOOP AT idoc_data.
    CASE idoc_data-segnam.
      WHEN co_zarmmts.
        DATA(ls_seg_zarmmts) = CONV zarmmts( idoc_data-sdata ).
        DATA(lv_matnr_long) = y0_ca_converter=>matnr18_to_matnr( ls_seg_zarmmts-materialnr ).
        DATA(lv_hmat_long) = y0_ca_converter=>matnr18_to_matnr( ls_seg_zarmmts-y0_hmat ).

        APPEND VALUE #( matnr = lv_matnr_long ) TO lt_matnr_keys.
        APPEND VALUE #( matnr = lv_hmat_long ) TO lt_matnr_keys.
        APPEND VALUE #( matnr = lv_matnr_long ) TO lt_rbfqty_keys.
        APPEND VALUE #( matnr = lv_matnr_long werks = ls_seg_zarmmts-prodplant ) TO lt_mkal_keys.
        APPEND VALUE #( matnr = lv_hmat_long werks = ls_seg_zarmmts-prodplant ) TO lt_mkal_keys.
        APPEND VALUE #( matnr = lv_hmat_long werks = ls_seg_zarmmts-prodplant charg = ls_seg_zarmmts-y0_hcharg ) TO lt_mch1_keys.
        APPEND VALUE #( matnr = lv_matnr_long werks = ls_seg_zarmmts-prodplant charg = ls_seg_zarmmts-batch ) TO lt_mch1_keys.
        APPEND VALUE #( matnr = lv_hmat_long werks = ls_seg_zarmmts-prodplant charg = ls_seg_zarmmts-planorder+2 ) TO lt_mch1_keys. "For mseg lookup
        APPEND VALUE #( plnum = ls_seg_zarmmts-planorder ) TO lt_plaf_keys.
        APPEND VALUE #( werks = ls_seg_zarmmts-prodplant ) TO lt_werks_keys.
        APPEND VALUE #( hmatn = lv_matnr_long werks = ls_seg_zarmmts-prodplant ) TO lt_rem_service_keys.

      WHEN co_zarmcls.
        DATA(ls_seg_zarmcls) = CONV zarmcls( idoc_data-sdata ).
        APPEND VALUE #( atnam = ls_seg_zarmcls-id ) TO lt_char_keys.
    ENDCASE.
  ENDLOOP.

  " Perform bulk SELECTs
  IF lt_matnr_keys IS NOT INITIAL.
    SORT lt_matnr_keys BY matnr.
    DELETE ADJACENT DUPLICATES FROM lt_matnr_keys COMPARING matnr.
    SELECT matnr, mtart, meins, xchpf, bismt FROM mara INTO TABLE @gt_mara_buf
      FOR ALL ENTRIES IN @lt_matnr_keys WHERE matnr = @lt_matnr_keys-matnr.

    " Pre-fetch all materials linked by BISMT for service material logic
    IF gt_mara_buf IS NOT INITIAL.
      SELECT matnr, mtart, meins, xchpf, bismt FROM mara APPENDING TABLE @gt_mara_buf
        FOR ALL ENTRIES IN @gt_mara_buf WHERE bismt = @gt_mara_buf-matnr.
      SORT gt_mara_buf BY matnr.
      DELETE ADJACENT DUPLICATES FROM gt_mara_buf COMPARING matnr.
    ENDIF.
  ENDIF.

  IF lt_mkal_keys IS NOT INITIAL.
    SORT lt_mkal_keys BY matnr werks.
    DELETE ADJACENT DUPLICATES FROM lt_mkal_keys COMPARING matnr werks.
    SELECT matnr, werks, verid, adatu FROM mkal INTO TABLE @gt_mkal_buf
      FOR ALL ENTRIES IN @lt_mkal_keys WHERE matnr = @lt_mkal_keys-matnr AND werks = @lt_mkal_keys-werks.
  ENDIF.

  IF lt_mch1_keys IS NOT INITIAL.
    SORT lt_mch1_keys BY matnr werks charg.
    DELETE ADJACENT DUPLICATES FROM lt_mch1_keys COMPARING matnr werks charg.
    " MCH1 selection (cross-plant batch existence)
    SELECT matnr, charg FROM mch1 INTO CORRESPONDING FIELDS OF TABLE @gt_mch1_buf
      FOR ALL ENTRIES IN @lt_mch1_keys WHERE matnr = @lt_mch1_keys-matnr AND charg = @lt_mch1_keys-charg.
    " MSEG selection (production GRs)
    SELECT matnr, werks, charg, aufnr FROM mseg INTO TABLE @gt_mseg_buf
      FOR ALL ENTRIES IN @lt_mch1_keys
      WHERE matnr = @lt_mch1_keys-matnr AND werks = @lt_mch1_keys-werks AND charg = @lt_mch1_keys-charg AND bwart = '131'.
    IF gt_mseg_buf IS NOT INITIAL.
      SELECT aufnr, verid FROM ckmlmv013 INTO TABLE @gt_ckmlmv013_buf
        FOR ALL ENTRIES IN @gt_mseg_buf WHERE aufnr = @gt_mseg_buf-aufnr.
    ENDIF.
  ENDIF.

  IF lt_plaf_keys IS NOT INITIAL.
    SORT lt_plaf_keys BY plnum.
    DELETE ADJACENT DUPLICATES FROM lt_plaf_keys COMPARING plnum.
    SELECT plnum, pwwrk FROM plaf INTO TABLE @gt_plaf_buf
      FOR ALL ENTRIES IN @lt_plaf_keys WHERE plnum = @lt_plaf_keys-plnum.
    SELECT plnum, matnr FROM y0pp_zatpde_send INTO TABLE @gt_zatpde_send_buf
      FOR ALL ENTRIES IN @lt_plaf_keys WHERE plnum = @lt_plaf_keys-plnum.
    SELECT * FROM y0pp_zatpde_calc INTO TABLE @gt_zatpde_calc_buf
      FOR ALL ENTRIES IN @lt_plaf_keys WHERE sender = @idoc_contrl-sndprn AND plorder = @lt_plaf_keys-plnum.
  ENDIF.

  IF lt_rbfqty_keys IS NOT INITIAL.
    SELECT * FROM y0pp_calc_rbfqty INTO TABLE @gt_rbfqty_buf
      FOR ALL ENTRIES IN @lt_rbfqty_keys WHERE matnr = @lt_rbfqty_keys-matnr.
  ENDIF.

  IF lt_werks_keys IS NOT INITIAL.
    SORT lt_werks_keys BY werks.
    DELETE ADJACENT DUPLICATES FROM lt_werks_keys COMPARING werks.
    SELECT * FROM y0mm_svpo_fixval INTO TABLE @gt_svpo_buf
      FOR ALL ENTRIES IN @lt_werks_keys WHERE werks = @lt_werks_keys-werks.
    SELECT * FROM y0pp_fill_plant INTO TABLE @gt_fill_plant_buf
      FOR ALL ENTRIES IN @lt_werks_keys WHERE werks_prod = @lt_werks_keys-werks.
    SELECT * FROM y0pp_rem_srvplnt INTO TABLE @gt_rem_srvplnt_buf
      FOR ALL ENTRIES IN @lt_werks_keys WHERE werks = @lt_werks_keys-werks.
  ENDIF.

  IF lt_rem_service_keys IS NOT INITIAL.
    SORT lt_rem_service_keys BY hmatn werks.
    DELETE ADJACENT DUPLICATES FROM lt_rem_service_keys COMPARING hmatn werks.
    SELECT * FROM y0pp_rem_service INTO TABLE @gt_rem_service_buf
      FOR ALL ENTRIES IN @lt_rem_service_keys WHERE hmatn = @lt_rem_service_keys-hmatn AND werks = @lt_rem_service_keys-werks.
  ENDIF.

  " Session-constant selects
  SELECT SINGLE * FROM y0mm_gm_matnrcnv INTO @y0mm_gm_matnrcnv
    WHERE sndprn = @idoc_contrl-sndprn.

  " Pre-fetch CABN data
  IF lt_char_keys IS NOT INITIAL.
    SORT lt_char_keys BY atnam.
    DELETE ADJACENT DUPLICATES FROM lt_char_keys COMPARING atnam.
    SELECT atinn, atnam, anzst, atfor FROM cabn INTO TABLE @gt_cabn_buf
      FOR ALL ENTRIES IN @lt_char_keys WHERE atnam = @lt_char_keys-atnam AND anzst = 18 AND atfor = 'CHAR'.
  ENDIF.

  " Pre-fetch Class Characteristics and Details
  IF lt_char_keys IS NOT INITIAL.
    DATA: lt_char_temp TYPE STANDARD TABLE OF bapi_char,
          lt_vals_temp TYPE STANDARD TABLE OF bapi_char_values.
    CALL FUNCTION 'BAPI_CLASS_GET_CHARACTERISTICS'
      EXPORTING
        classnum        = 'Y0_FINISHED_GOODS'
        classtype       = '023'
      TABLES
        characteristics = lt_char_temp
        char_values     = lt_vals_temp.

    LOOP AT lt_char_temp INTO DATA(ls_char_temp).
      INSERT VALUE #( atnam = ls_char_temp-name_char ) INTO TABLE gt_class_chars_buf.
    ENDLOOP.

    LOOP AT lt_char_keys INTO DATA(ls_char_key).
      IF line_exists( gt_class_chars_buf[ atnam = ls_char_key-atnam ] ).
        DATA: ls_chardt_temp TYPE bapicharactdetail.
        CALL FUNCTION 'BAPI_CHARACT_GETDETAIL'
          EXPORTING
            charactname   = ls_char_key-atnam
          IMPORTING
            charactdetail = ls_chardt_temp.
        INSERT VALUE #( atnam = ls_char_key-atnam atbew = ls_chardt_temp-value_assignment ) INTO TABLE gt_char_detail_buf.
      ENDIF.
    ENDLOOP.
  ENDIF.

  " Check if plant/DD mapping is necessary
  " If yes -> Map plant& material
  CLEAR lv_dd_map.
  SELECT SINGLE @abap_true FROM y0bc_idoc_dd_plt WHERE partyp = @idoc_contrl-sndprt
                                                   AND parnum = @idoc_contrl-sndprn
                                                   AND mestyp = @idoc_contrl-mestyp
                                                 INTO @lv_dd_map.
  IF lv_dd_map = abap_true.

    LOOP AT idoc_data.
      IF idoc_data-segnam = co_zarmmts.
        wa_zarmmts = idoc_data-sdata.
        " Map material if necessary
*{   REPLACE        R9SK901046                                        1
*\        wa_zarmmts-materialnr = ycl_bc_idoc_functions=>map_material_rb_dd( EXPORTING iv_partyp = idoc_contrl-sndprt
        wa_zarmmts-materialnr = ycl_bc_idoc_functions=>map_material18_rb_dd( EXPORTING iv_partyp = idoc_contrl-sndprt
*}   REPLACE
                                                                                                 iv_parnum = idoc_contrl-sndprn
                                                                                                 iv_mestyp = idoc_contrl-mestyp
                                                                                                 iv_date = CONV datum( wa_zarmmts-y0_proddate )
                                                                                                 iv_matnr_in = wa_zarmmts-materialnr ).
*{   REPLACE        R9SK901046                                        2
*\        wa_zarmmts-y0_hmat = ycl_bc_idoc_functions=>map_material_rb_dd( EXPORTING iv_partyp = idoc_contrl-sndprt
        wa_zarmmts-y0_hmat = ycl_bc_idoc_functions=>map_material18_rb_dd( EXPORTING iv_partyp = idoc_contrl-sndprt
*}   REPLACE
                                                                                              iv_parnum = idoc_contrl-sndprn
                                                                                              iv_mestyp = idoc_contrl-mestyp
                                                                                              iv_date = CONV datum( wa_zarmmts-y0_proddate )
                                                                                              iv_matnr_in = wa_zarmmts-y0_hmat ).

        " Map plant if necessary
        wa_zarmmts-prodplant = ycl_bc_idoc_functions=>map_plant_in( EXPORTING iv_partyp = idoc_contrl-rcvprt
                                                                              iv_parnum = idoc_contrl-sndprn
                                                                              iv_mestyp = idoc_contrl-mestyp
                                                                              iv_date = CONV datum( wa_zarmmts-y0_proddate )
                                                                              iv_werks_idoc = wa_zarmmts-prodplant ).
        wa_zarmmts-planplant = ycl_bc_idoc_functions=>map_plant_in( EXPORTING iv_partyp = idoc_contrl-sndprt
                                                                                          iv_parnum = idoc_contrl-sndprn
                                                                                          iv_mestyp = idoc_contrl-mestyp
                                                                                          iv_date = CONV datum( wa_zarmmts-y0_proddate )
                                                                                         iv_werks_idoc = wa_zarmmts-planplant ).
        idoc_data-sdata = wa_zarmmts.
        MODIFY idoc_data.
      ENDIF.
    ENDLOOP.
  ENDIF.


  LOOP AT idoc_data.
*   Backflush Segment
    IF idoc_data-segnam = co_zarmmts.
      CLEAR it_zarmmts.
*{   REPLACE        R9SK901046                                        8
*\      it_zarmmts = idoc_data-sdata.
      it_zarmmts = idoc_data-sdata.          "#EC CI_FLDEXT_OK[2215424]
*}   REPLACE

**dhoermann RITM01139851 check open period
*      SELECT SINGLE bukrs INTO @DATA(lv_bukrs) FROM t001k
*        WHERE bwkey = @it_zarmmts-prodplant.
*      IF sy-subrc IS INITIAL.
*        SELECT SINGLE lfgja, lfmon, vmgja, vmmon FROM marv
*          INTO @DATA(ls_marv)
*          WHERE bukrs = @lv_bukrs.
*        IF sy-subrc IS INITIAL.
*          IF ( ls_marv-lfgja = it_zarmmts-postdate+0(4)
*            AND ls_marv-lfmon = it_zarmmts-postdate+4(2) ).
*            "ok
*          ELSE.
*            "error
*            idoc_status-status = co_idoc_status_error.
*            PERFORM insert_status USING idoc_status-status
*                                        'E'
*                                        'FR'
*                                        '165'
*                                        '' '' '' ''.
*          ENDIF.
*        ELSE.
*          "error
*          idoc_status-status = co_idoc_status_error.
*          PERFORM insert_status USING idoc_status-status
*                                      'E'
*                                      'FIEU_SAFT'
*                                      '312'
*                                      lv_bukrs '' '' ''.
*        ENDIF.
*      ENDIF.


      it_zarmmts-segnum = idoc_data-segnum.
*{   INSERT         R9SK901046                                        3
      it_zarmmts-material_long = y0_ca_converter=>matnr18_to_matnr( it_zarmmts-materialnr ).
      it_zarmmts-y0_hmat_long = y0_ca_converter=>matnr18_to_matnr( it_zarmmts-y0_hmat ).
*}   INSERT
*      convert material numbers - if partner system needs it
      CLEAR y0mm_gm_matnrcnv.
*dhoermann 20230301 get header material from planned order - if empty (only for WA)
* ERPMM-2489
      IF it_zarmmts-y0_postype EQ co_postype_wa AND it_zarmmts-y0_hmat IS INITIAL.
*{   REPLACE        R9SK901046                                        6
*\        SELECT SINGLE matnr INTO it_zarmmts-y0_hmat FROM y0pp_zatpde_send
        it_zarmmts-y0_hmat_long = VALUE #( gt_zatpde_send_buf[ plnum = it_zarmmts-planorder ]-matnr OPTIONAL ).
*}   REPLACE
*{   INSERT         R9SK901046                                        7
        it_zarmmts-y0_hmat = y0_ca_converter=>matnr_to_matnr18( it_zarmmts-y0_hmat_long ).
*}   INSERT
        idoc_status-status = co_idoc_status_edited.
        PERFORM insert_status USING idoc_status-status
                                    'I'
                                    'Y0PP_IDOCS'
                                    '035'
                                    'it_zarmmts-y0_hmat'
                                    '' '' ''.
      ENDIF.
      " SELECT SINGLE * FROM y0mm_gm_matnrcnv moved to pre-fetch logic
      IF y0mm_gm_matnrcnv IS NOT INITIAL.
*         Convert component material number
        CALL FUNCTION 'Y_0CA_PARTNER_CONVERT_MATNR'
          EXPORTING
            matnr_in                = it_zarmmts-materialnr
            direct                  = '2'
          IMPORTING
            matnr_out               = it_zarmmts-materialnr
          EXCEPTIONS
            invalid_parameters      = 1
            material_does_not_exist = 2
            OTHERS                  = 3.
        IF sy-subrc <> 0.
          repbf_code = 4.
          PERFORM insert_status USING co_idoc_status_error 'E' 'Y0PP_IDOCS' '014' it_zarmmts-materialnr space space space.
          CONTINUE.
        ENDIF.
*        Convert header material number
        CALL FUNCTION 'Y_0CA_PARTNER_CONVERT_MATNR'
          EXPORTING
            matnr_in                = it_zarmmts-y0_hmat
            direct                  = '2'
          IMPORTING
            matnr_out               = it_zarmmts-y0_hmat
          EXCEPTIONS
            invalid_parameters      = 1
            material_does_not_exist = 2
            OTHERS                  = 3.
        IF sy-subrc <> 0.
          repbf_code = 4.
          PERFORM insert_status USING co_idoc_status_error 'E' 'Y0PP_IDOCS' '014' it_zarmmts-y0_hmat space space space.
          CONTINUE.
        ENDIF.
      ENDIF.

*      determine if field batch should be deleted
      CLEAR: mara-mtart, mara-meins, mara-xchpf.
      DATA(ls_mara_buf_local) = VALUE #( gt_mara_buf[ matnr = it_zarmmts-material_long ] OPTIONAL ).
      mara-mtart = ls_mara_buf_local-mtart.
      mara-meins = ls_mara_buf_local-meins.
      mara-xchpf = ls_mara_buf_local-xchpf.
      IF mara-xchpf IS INITIAL.
        CLEAR it_zarmmts-batch.
      ENDIF.

*      Re-Calculate quantity
      DATA(ls_rbfqty_buf_local) = VALUE #( gt_rbfqty_buf[ matnr = it_zarmmts-material_long
                                                          pstyp = it_zarmmts-y0_postype ] OPTIONAL ).
      IF ls_rbfqty_buf_local IS NOT INITIAL.
        CLEAR h_menge.
        TRANSLATE it_zarmmts-backflquant USING ',.'.
        h_menge = it_zarmmts-backflquant.
        h_menge = h_menge * ls_rbfqty_buf_local-faktr.
        it_zarmmts-backflquant = h_menge.
      ENDIF.

*      format for call transaction
      PERFORM translate_quan_for_gui USING it_zarmmts-backflquant.

      CASE it_zarmmts-y0_postype.
        WHEN co_postype_we.
          CLEAR it_we.
          it_we = it_zarmmts.
          APPEND it_we.

        WHEN co_postype_wa.
          IF it_zarmmts-y0_hmat NE it_zarmmts-materialnr.
*                goods issue
            CLEAR it_wa.
            it_wa = it_zarmmts.
            APPEND it_wa.
          ELSE.
*                reversal
            CLEAR it_re.
            it_re = it_zarmmts.
            APPEND it_re.
          ENDIF.
        WHEN OTHERS.        "Error
      ENDCASE.

      APPEND it_zarmmts.
    ENDIF.
*   Classification Segment
    IF idoc_data-segnam = co_zarmcls.
      "only if ok til now
      CHECK repbf_code = 0.
      "move
      CLEAR: wa_zarmcls,
             it_zarmcls.
      wa_zarmcls = idoc_data-sdata.
      IF wa_zarmcls-id IS NOT INITIAL AND wa_zarmcls-value IS NOT INITIAL.
        MOVE-CORRESPONDING it_zarmmts TO it_zarmcls.
        MOVE-CORRESPONDING wa_zarmcls TO it_zarmcls.
        "check characteristic existance
        PERFORM check_characteristic_existance USING 'Y0_FINISHED_GOODS' '023' it_zarmcls-id
                                            CHANGING sy-subrc.
        IF sy-subrc NE 0.
          repbf_code = 4.
          PERFORM insert_status USING co_idoc_status_error 'E' 'CL' '033' it_zarmcls-id space space space.
        ENDIF.
        CHECK repbf_code = 0.
        IF wa_zarmcls-id  NE 'Y0_PD_RECIPE'.
          "check if value even can be a material number
          " SELECT SINGLE COUNT(*) FROM cabn WHERE atinn = wa_zarmcls-id
          "                                   AND anzst = 18 AND atfor = 'CHAR'.
          IF line_exists( gt_cabn_buf[ atnam = wa_zarmcls-id ] ).
            "convert the value (old material number to RB material number)
            CALL FUNCTION 'Y_0CA_PARTNER_CONVERT_MATNR'
              EXPORTING
                matnr_in  = it_zarmcls-value
                direct    = idoc_contrl-direct
              IMPORTING
                matnr_out = it_zarmcls-value
              EXCEPTIONS
                OTHERS    = 1.
          ENDIF.
        ENDIF.
        "remember
        COLLECT it_zarmcls.
      ENDIF.
    ENDIF.
  ENDLOOP.


* Add filling plant
  PERFORM zarepbf_add_filling_plant.

  " If we did a plant/DD material mapping -> classification must be copied (posting for DD + RB material)
  IF lv_dd_map = abap_true.

    " classification segment -> copy and map
    LOOP AT it_zarmcls.
      DATA(wa_zarmcls_map) = it_zarmcls.

      " Map material if necessary
      wa_zarmcls_map-y0_hmat = ycl_bc_idoc_functions=>map_material_dd_rb( EXPORTING iv_partyp = idoc_contrl-sndprt
                                                                                    iv_parnum = idoc_contrl-sndprn
                                                                                    iv_mestyp = idoc_contrl-mestyp
                                                                                    iv_date = wa_zarmcls_map-y0_proddate
                                                                                    iv_matnr_in = wa_zarmcls_map-y0_hmat ).
      " map plant if necessary
      wa_zarmcls_map-prodplant = ycl_bc_idoc_functions=>map_plant_out( EXPORTING iv_partyp = idoc_contrl-rcvprt
                                                                                iv_parnum = idoc_contrl-sndprn
                                                                                iv_mestyp = idoc_contrl-mestyp
                                                                                iv_date = wa_zarmcls_map-y0_proddate
                                                                                iv_werks_rb = wa_zarmcls_map-prodplant ).

      " If material was mapped -> copy data instead of mapping only
      IF wa_zarmcls_map-y0_hmat <> it_zarmcls-y0_hmat.
        APPEND wa_zarmcls_map TO it_zarmcls[].
      ENDIF.

    ENDLOOP.

  ENDIF.

ENDFORM.                    " ZAREPBF_IDOC_PARSE
*&---------------------------------------------------------------------*
*&      Form  zarepbf_init_data
*&---------------------------------------------------------------------*
FORM zarepbf_init_data.

  CLEAR: it_zarmmts,
         it_zarmcls,
         gs_zatpde_cust,
         it_we,
         it_wa,
         it_re,
         it_ra,
         trans_called,
         trans_ok,

         wa_dcpfm.

  REFRESH: it_zarmmts,
           it_zarmcls,
           it_we,
           it_wa,
           it_re,
           it_ra,
           gt_mara_buf,
           gt_mkal_buf,
           gt_mch1_buf,
           gt_plaf_buf,
           gt_rbfqty_buf,
           gt_svpo_buf,
           gt_fill_plant_buf,
           gt_rem_srvplnt_buf,
           gt_zatpde_send_buf,
           gt_rem_service_buf,
           gt_zatpde_calc_buf,
           gt_mseg_buf,
           gt_ckmlmv013_buf,
           gt_cabn_buf,
           gt_class_chars_buf,
           gt_char_detail_buf.

  IF input_method IS INITIAL.
    bdc_mode = 'N'.
  ELSE.
    bdc_mode = input_method.
  ENDIF.

  SELECT SINGLE dcpfm FROM usr01 INTO wa_dcpfm WHERE bname = sy-uname.

*dhoermann 20230301 get customizing
  SELECT SINGLE * FROM y0pp_zatpde_cust INTO gs_zatpde_cust
    WHERE sndprn = idoc_contrl-sndprn.
*
ENDFORM.                    " zarepbf_init_data
*&---------------------------------------------------------------------*
*&      Form  ZAREPBF_POST
*&---------------------------------------------------------------------*
FORM zarepbf_post.
*locals
  DATA: lv_umrez        TYPE umrez,
        lv_meins        TYPE meins,
        lv_backflquant  TYPE i,
        ls_bapi_gen     TYPE bapi_rm_datgen,
        ls_bapi_ext     TYPE bapi_rm_datext,
        lt_bapi_item    TYPE TABLE OF bapi_rm_item,
        ls_bapi_return  TYPE bapiret2,
        lv_conf_confirm TYPE bapi_conf_key-conf_confirm,
        lv_conf_counter TYPE bapi_conf_key-conf_confirm,
        lv_m_doc        TYPE bapi_conf_key-m_doc,
        lv_m_year       TYPE bapi_conf_key-m_year.

* process reversals
  LOOP AT it_re.
    CLEAR: ls_bapi_gen, ls_bapi_ext, lt_bapi_item, ls_bapi_return, lv_conf_confirm, lv_conf_counter, lv_m_doc, lv_m_year.
    ADD 1 TO trans_called.

    ls_bapi_gen-material_long  = it_re-material_long.
    ls_bapi_gen-plant          = it_re-prodplant.
    DATA(lv_qty_in) = it_re-backflquant.
    TRANSLATE lv_qty_in USING ',.'.
    ls_bapi_gen-bckfl_qty      = abs( CONV erfmg( lv_qty_in ) ).
    ls_bapi_gen-unitofmeas     = it_re-unitofmeasure.
    ls_bapi_gen-post_date      = it_re-postdate.
    ls_bapi_gen-doc_date       = it_re-docdate.
    ls_bapi_gen-batch          = it_re-batch.
    ls_bapi_gen-storageloc     = it_re-storageloc.

    CASE it_re-insmk.
      WHEN ' ' OR 'F'. ls_bapi_gen-stock_type = ' '.
      WHEN 'X' OR '2'. ls_bapi_gen-stock_type = 'X'.
      WHEN 'S'.        ls_bapi_gen-stock_type = 'S'.
    ENDCASE.

    ls_bapi_ext-proddate    = it_re-y0_proddate.
    ls_bapi_ext-vfdat       = it_re-y0_seldate.
    ls_bapi_ext-bckfltype   = '1'. "Assembly backflush

    PERFORM map_header_text_bapi USING it_re 'WE' CHANGING ls_bapi_gen-header_txt.
    PERFORM map_prod_version_bapi USING it_re CHANGING ls_bapi_gen-prod_ver ls_bapi_gen-planned_or.

    " Component corrections
    LOOP AT it_ra WHERE y0_hmat = it_re-materialnr AND y0_hcharg = it_re-batch.
      DATA(lv_ra_qty) = it_ra-backflquant.
      TRANSLATE lv_ra_qty USING ',.'.
      APPEND VALUE #( material_long = it_ra-material_long
                      plant         = it_ra-prodplant
                      bckfl_qty     = abs( CONV erfmg( lv_ra_qty ) )
                      unitofmeas    = it_ra-unitofmeasure
                      storageloc    = it_ra-storageloc
                      batch         = it_ra-batch ) TO lt_bapi_item.
      DELETE it_ra.
    ENDLOOP.

    CALL FUNCTION 'BAPI_REPMANCONF1_CREATE_MTS'
      EXPORTING
        bflushdatagen = ls_bapi_gen
        bflushdatext  = ls_bapi_ext
        reversal      = abap_true
      IMPORTING
        return        = ls_bapi_return
        confirmation  = lv_conf_confirm
        confcounter   = lv_conf_counter
        mat_doc       = lv_m_doc
        doc_year      = lv_m_year
      TABLES
        itemdata      = lt_bapi_item.

    PERFORM handle_bapi_return USING ls_bapi_return 'RE' it_re-materialnr it_re-batch space.
  ENDLOOP.

* Process WE
  LOOP AT it_we.
    CLEAR: ls_bapi_gen, ls_bapi_ext, lt_bapi_item, ls_bapi_return, lv_conf_confirm, lv_conf_counter, lv_m_doc, lv_m_year.
    ADD 1 TO trans_called.

    ls_bapi_gen-material_long  = it_we-material_long.
    ls_bapi_gen-plant          = it_we-prodplant.
    DATA(lv_we_qty) = it_we-backflquant.
    TRANSLATE lv_we_qty USING ',.'.
    ls_bapi_gen-bckfl_qty      = abs( CONV erfmg( lv_we_qty ) ).
    ls_bapi_gen-unitofmeas     = it_we-unitofmeasure.
    ls_bapi_gen-post_date      = it_we-postdate.
    ls_bapi_gen-doc_date       = it_we-docdate.
    ls_bapi_gen-batch          = it_we-batch.
    ls_bapi_gen-storageloc     = it_we-storageloc.

    CASE it_we-insmk.
      WHEN ' ' OR 'F'. ls_bapi_gen-stock_type = ' '.
      WHEN 'X' OR '2'. ls_bapi_gen-stock_type = 'X'.
      WHEN 'S'.        ls_bapi_gen-stock_type = 'S'.
    ENDCASE.

    ls_bapi_ext-proddate    = it_we-y0_proddate.
    ls_bapi_ext-vfdat       = it_we-y0_seldate.
    ls_bapi_ext-bckfltype   = '1'. "Assembly backflush

    PERFORM map_header_text_bapi USING it_we 'WE' CHANGING ls_bapi_gen-header_txt.
    PERFORM map_prod_version_bapi USING it_we CHANGING ls_bapi_gen-prod_ver ls_bapi_gen-planned_or.

    " Component corrections
    LOOP AT it_wa WHERE y0_hmat = it_we-materialnr AND y0_hcharg = it_we-batch.
      DATA(lv_wa_qty) = it_wa-backflquant.
      TRANSLATE lv_wa_qty USING ',.'.
      APPEND VALUE #( material_long = it_wa-material_long
                      plant         = it_wa-prodplant
                      bckfl_qty     = abs( CONV erfmg( lv_wa_qty ) )
                      unitofmeas    = it_wa-unitofmeasure
                      storageloc    = it_wa-storageloc
                      batch         = it_wa-batch ) TO lt_bapi_item.
      DELETE it_wa.
    ENDLOOP.

    CALL FUNCTION 'BAPI_REPMANCONF1_CREATE_MTS'
      EXPORTING
        bflushdatagen = ls_bapi_gen
        bflushdatext  = ls_bapi_ext
      IMPORTING
        return        = ls_bapi_return
        confirmation  = lv_conf_confirm
        confcounter   = lv_conf_counter
        mat_doc       = lv_m_doc
        doc_year      = lv_m_year
      TABLES
        itemdata      = lt_bapi_item.

    PERFORM handle_bapi_return USING ls_bapi_return 'WE' it_we-materialnr it_we-batch space.
  ENDLOOP.

* if WA's are left (WA's without corresponding WE) process them
  LOOP AT it_wa.
    CLEAR: ls_bapi_gen, ls_bapi_ext, lt_bapi_item, ls_bapi_return, lv_conf_confirm, lv_conf_counter, lv_m_doc, lv_m_year.
    ADD 1 TO trans_called.

* calculation tr1->can
    IF it_wa-unitofmeasure EQ 'TR1'.
      DATA(ls_zatpde_calc_buf) = VALUE #( gt_zatpde_calc_buf[ sender = idoc_contrl-sndprn
                                                             plorder = it_wa-planorder
                                                             display = it_wa-y0_hmat
                                                             component = it_wa-materialnr ] OPTIONAL ).
      IF ls_zatpde_calc_buf IS NOT INITIAL.
        lv_meins = ls_zatpde_calc_buf-meins.
        lv_umrez = ls_zatpde_calc_buf-umrez.
        it_wa-unitofmeasure = lv_meins.
        TRANSLATE it_wa-backflquant USING ',.'.
        lv_backflquant = it_wa-backflquant * lv_umrez.
        it_wa-backflquant = lv_backflquant.
        SHIFT it_wa-backflquant LEFT DELETING LEADING space.
*write info-status to idoc
        idoc_status-status = co_idoc_status_edited.
        PERFORM insert_status USING idoc_status-status
                                    'I'
                                    'Y0PP_IDOCS'
                                    '036'
                                    lv_backflquant
                                    lv_meins '' ''.
      ENDIF.
    ENDIF.

    ls_bapi_gen-material_long  = it_wa-y0_hmat_long.
    ls_bapi_gen-plant          = it_wa-prodplant.
    DATA(lv_comp_qty_raw) = it_wa-backflquant.
    TRANSLATE lv_comp_qty_raw USING ',.'.
    ls_bapi_gen-bckfl_qty      = 0. "Component only
    ls_bapi_gen-post_date      = it_wa-postdate.
    ls_bapi_gen-doc_date       = it_wa-docdate.
    ls_bapi_gen-batch          = it_wa-y0_hcharg.

    ls_bapi_ext-proddate    = it_wa-y0_proddate.
    ls_bapi_ext-vfdat       = it_wa-y0_seldate.
    ls_bapi_ext-bckfltype   = '2'. "Component backflush

    PERFORM map_header_text_bapi USING it_wa 'WA' CHANGING ls_bapi_gen-header_txt.

    DATA(lv_comp_qty_mapped) = it_wa-backflquant.
    TRANSLATE lv_comp_qty_mapped USING ',.'.
    APPEND VALUE #( material_long = it_wa-material_long
                    plant         = it_wa-prodplant
                    bckfl_qty     = abs( CONV erfmg( lv_comp_qty_mapped ) )
                    unitofmeas    = it_wa-unitofmeasure
                    storageloc    = it_wa-storageloc
                    batch         = it_wa-batch ) TO lt_bapi_item.

    CALL FUNCTION 'BAPI_REPMANCONF1_CREATE_MTS'
      EXPORTING
        bflushdatagen = ls_bapi_gen
        bflushdatext  = ls_bapi_ext
      IMPORTING
        return        = ls_bapi_return
        confirmation  = lv_conf_confirm
        confcounter   = lv_conf_counter
        mat_doc       = lv_m_doc
        doc_year      = lv_m_year
      TABLES
        itemdata      = lt_bapi_item.

    PERFORM handle_bapi_return USING ls_bapi_return 'WA' it_wa-materialnr it_wa-y0_hmat it_wa-y0_hcharg.
  ENDLOOP.

ENDFORM.                    " ZAREPBF_POST
*&---------------------------------------------------------------------*
*&---------------------------------------------------------------------*
*&      Form  check_msg
*&---------------------------------------------------------------------*
FORM check_msg USING VALUE(us_suctyp) LIKE bdcmsgcoll-msgtyp
                     VALUE(us_sucid)  LIKE bdcmsgcoll-msgid
                     VALUE(us_sucnr)  LIKE bdcmsgcoll-msgnr
                     VALUE(us_msgtyp) LIKE bdcmsgcoll-msgtyp
                     VALUE(us_msgid)  LIKE bdcmsgcoll-msgid
                     VALUE(us_msgnr)  LIKE bdcmsgcoll-msgnr
                     VALUE(us_msgv1)
                     VALUE(us_msgv2)
                     VALUE(us_msgv3)
                     VALUE(us_msgv4).

**dhoermann missing dynpros in batch input have message type S in bdcmsg...
**  so the idoc gets a wrong status
*  READ TABLE bdcmsg WITH KEY msgtyp = 'S'
*                             msgid  = '00'
*                             msgnr  = '344'.
*  IF sy-subrc IS INITIAL.
*    idoc_status-status = co_idoc_status_error.
*    LOOP AT bdcmsg.
*      PERFORM insert_status USING idoc_status-status
*                                  bdcmsg-msgtyp
*                                  bdcmsg-msgid
*                                  bdcmsg-msgnr
*                                  bdcmsg-msgv1
*                                  bdcmsg-msgv2
*                                  bdcmsg-msgv3
*                                  bdcmsg-msgv4.
*    ENDLOOP.
*    EXIT.
*  ENDIF.
  READ TABLE bdcmsg WITH KEY msgtyp = us_suctyp
                             msgid  = us_sucid
                             msgnr  = us_sucnr.
  IF sy-subrc = 0 AND bdcmsg-msgv1 IS NOT INITIAL. "MSGV1 should contain the GR/GI document!
    idoc_status-status = co_idoc_status_ok.
    PERFORM insert_status USING idoc_status-status
                                us_msgtyp
                                us_msgid
                                us_msgnr
                                us_msgv1
                                us_msgv2
                                us_msgv3
                                us_msgv4.
    PERFORM insert_status USING idoc_status-status
                                bdcmsg-msgtyp
                                bdcmsg-msgid
                                bdcmsg-msgnr
                                bdcmsg-msgv1
                                bdcmsg-msgv2
                                bdcmsg-msgv3
                                bdcmsg-msgv4.
    ADD 1 TO trans_ok.
    COMMIT WORK.
  ELSE.
    idoc_status-status = co_idoc_status_error.
*    loop at bdcmsg where msgtyp = 'E' or
*                         msgtyp = 'W'.
    LOOP AT bdcmsg. "testsetup - issue alle messages to identify cases which are falsely categorized as error
      PERFORM insert_status USING idoc_status-status
                                  bdcmsg-msgtyp
                                  bdcmsg-msgid
                                  bdcmsg-msgnr
                                  bdcmsg-msgv1
                                  bdcmsg-msgv2
                                  bdcmsg-msgv3
                                  bdcmsg-msgv4.
    ENDLOOP.
    PERFORM insert_status USING idoc_status-status
                                'E' "us_msgtyp, damit das Idoc im AIF auf Fehler läuft
                                us_msgid
                                us_msgnr
                                us_msgv1
                                us_msgv2
                                us_msgv3
                                us_msgv4.
  ENDIF.

ENDFORM.                    " check_msg
*&---------------------------------------------------------------------*
*&      Form  ZAREPBF_result_set
*&---------------------------------------------------------------------*
FORM zarepbf_result_set.

  CLEAR in_update_task.
  CLEAR call_transaction_done.

  IF repbf_code NE 0.          "Failure during parsing
    workflow_result = co_result_error.
    return_variables-wf_param = co_error_idocs.
    return_variables-doc_number = idoc_contrl-docnum.
    APPEND return_variables.
  ENDIF.

  IF trans_called = trans_ok AND trans_ok NE 0.     "Everything OK
    workflow_result = co_result_ok.
    return_variables-wf_param = co_processed_idocs.
    return_variables-doc_number = idoc_contrl-docnum.
    APPEND return_variables.
  ENDIF.

  IF trans_called > 0 AND trans_ok = 0.          "All failed
    workflow_result = co_result_error.
    return_variables-wf_param = co_error_idocs.
    return_variables-doc_number = idoc_contrl-docnum.
    APPEND return_variables.
  ENDIF.

  IF trans_called NE trans_ok AND trans_ok NE 0. "Partially failed
    workflow_result = co_result_error.
    return_variables-wf_param = co_error_idocs.
    return_variables-doc_number = idoc_contrl-docnum.
    APPEND return_variables.

    CLEAR idoc_status.
    idoc_status-docnum = idoc_contrl-docnum.
    idoc_status-msgid = co_msgid.
    idoc_status-status = co_idoc_status_incomplete.
    idoc_status-msgty = 'W'.
    idoc_status-msgno = '019'.
    APPEND idoc_status.
  ENDIF.

ENDFORM.                    " ZAREPBF_result_set
*&---------------------------------------------------------------------*
*&      Form  ZAATPDET_init_data
*&---------------------------------------------------------------------*
FORM zaatpdet_init_data.

  CLEAR: it_stat,
         it_plnum,
         it_whplt,
         it_locn,
         it_unicv,
         wa_nrange,
         wa_fixval,
         wa_atpdet,
         it_poheader,
         trans_called,
         trans_ok.

  REFRESH: it_stat,
           it_plnum,
           it_whplt,
           it_unicv,
           it_poheader.

* clear status_code
  atpdet_code = 0.
* get number range
  IF idoc_contrl-mestyp EQ 'ZATPDE_PR'.
    SELECT * FROM y0pp_po_pnrg INTO TABLE it_nrange
                                     WHERE parnum = idoc_contrl-sndprn.
  ELSE.
    SELECT * FROM y0pp_po_pnrg INTO TABLE it_nrange
                                     WHERE parnum = idoc_contrl-sndprn
                                       AND mestyp = idoc_contrl-mestyp.
  ENDIF.
*  select single * from y0pp_po_pnrg into wa_nrange
*                                   where parnum = idoc_contrl-sndprn
*                                     and mestyp = idoc_contrl-mestyp.

  IF sy-subrc NE 0.
    PERFORM insert_message USING 'E' co_msgid '001' idoc_contrl-sndprn
                                                    space space space.
    atpdet_code = 1.
  ENDIF.
* get constants
  SELECT SINGLE * FROM y0pp_atp_fixval INTO wa_fixval
                                      WHERE parnum = idoc_contrl-sndprn.
  IF sy-subrc NE 0.
    PERFORM insert_message USING 'E' co_msgid '002' idoc_contrl-sndprn
                                                    space space space.
    atpdet_code = 1.
  ENDIF.
* get warehouse -> plant conversion
  SELECT * FROM y0pp_wareh_plant INTO TABLE it_whplt.
  IF sy-subrc NE 0.
    PERFORM insert_message USING 'E' co_msgid '003' space space
                                                    space space.
    atpdet_code = 1.
  ENDIF.
* get location -> storage location/version conversion
  SELECT * FROM y0pp_prod_locn INTO TABLE it_locn.
* get unit conversions
  SELECT * FROM y0pp_unit_conv INTO TABLE it_unicv.
  IF sy-subrc NE 0.
    PERFORM insert_message USING 'E' co_msgid '011' space space
                                                    space space.
    atpdet_code = 1.
  ENDIF.

ENDFORM.                    " ZAATPDET_init_data
*&---------------------------------------------------------------------*
*&      Form  ZAATPDET_IDOC_PARSE
*&---------------------------------------------------------------------*
FORM zaatpdet_idoc_parse.
*  TABLES: marm.

  DATA: dup_ponumbers LIKE bapiplaf_i1-plannedorder_num
                           OCCURS 0 WITH HEADER LINE.

  CHECK atpdet_code = 0.

  REFRESH dup_ponumbers.
  LOOP AT idoc_data.
*   check segment
    CHECK idoc_data-segnam = co_zaatpdet.

    CLEAR: wa_atpdet, it_poheader.
    wa_atpdet = idoc_data-sdata.
*   check constants
    CHECK wa_atpdet-dttp = wa_fixval-zdttp AND
          wa_atpdet-corp = wa_fixval-zcorp.
*   convert warehouse
    READ TABLE it_whplt WITH KEY zwhse = wa_atpdet-whse.
    IF sy-subrc NE 0.
      PERFORM insert_message USING 'E' co_msgid '004' wa_atpdet-whse
                                   space space space.
      atpdet_code = 2.
    ENDIF.
*   convert unit of measure
    READ TABLE it_unicv WITH KEY zumsr = wa_atpdet-umsr.
    IF sy-subrc NE 0.
      PERFORM insert_message USING 'E' co_msgid '012' wa_atpdet-umsr
                                   space space space.
      atpdet_code = 2.
    ENDIF.
*   convert location
    CLEAR it_locn.
    READ TABLE it_locn WITH KEY zlocn = wa_atpdet-locn
                                zwhse = wa_atpdet-whse.
*   Check mandatory fields
    PERFORM field_check USING wa_atpdet-schd 'SCHD'.
    PERFORM field_check USING wa_atpdet-resc 'RESC'.
    PERFORM field_check USING wa_atpdet-dued 'DUED'.
    PERFORM field_check USING wa_atpdet-qyex 'QYEX'.
    PERFORM field_check USING wa_atpdet-umsr 'UMSR'.
    CHECK atpdet_code = 0.

    it_poheader-material         = wa_atpdet-resc.
*   Convert external materialnumber (BISMT) to materialnr.
    CALL FUNCTION 'Y_0CA_PARTNER_CONVERT_MATNR'
      EXPORTING
        matnr_in                = it_poheader-material
        direct                  = '2'
      IMPORTING
        matnr_out               = it_poheader-material
      EXCEPTIONS
        invalid_parameters      = 1
        material_does_not_exist = 2
        OTHERS                  = 3.
    IF sy-subrc NE 0 OR it_poheader-material IS INITIAL.
      PERFORM insert_message USING 'E' co_msgid '014'
                                   wa_atpdet-resc space space space.
      atpdet_code = 2.
      CONTINUE.
    ENDIF.
*   Convert material number into internal format
    CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
      EXPORTING
        input        = it_poheader-material
      IMPORTING
        output       = it_poheader-material
      EXCEPTIONS
        length_error = 1
        OTHERS       = 2.

*   Check if material exists
    SELECT SINGLE matnr FROM marc INTO marc-matnr
                                 WHERE matnr = it_poheader-material
                                   AND werks = it_whplt-werks.
    IF sy-subrc NE 0.
      PERFORM insert_message USING 'E' co_msgid '005'
                                   it_poheader-material it_whplt-werks
                                   space space.
      atpdet_code = 2.
      CONTINUE.
    ENDIF.
*
    it_poheader-total_plord_qty  = wa_atpdet-qyex - wa_atpdet-qyrv.
*   Check Quantity ne 0
    IF it_poheader-total_plord_qty = 0.
      PERFORM insert_message USING 'I' co_msgid '006' wa_atpdet-schd
                                       space space space.
      CONTINUE.
    ENDIF.

*---> Einbau Mengenconversion
*   not for new type
    CLEAR marm.
    SELECT SINGLE * FROM marm INTO marm
                   WHERE matnr EQ it_poheader-material
                     AND meinh EQ it_unicv-meins.
    IF sy-subrc IS INITIAL.
      it_poheader-total_plord_qty = it_poheader-total_plord_qty *
                  ( marm-umrez / marm-umren ).
    ENDIF.

    it_poheader-plannedorder_num = wa_atpdet-schd.
*   check for duplicate plannedorders
    READ TABLE dup_ponumbers WITH KEY it_poheader-plannedorder_num.
    IF sy-subrc = 0.
      atpdet_code = 2.
      PERFORM insert_message USING 'E' co_msgid '013'
                                   it_poheader-plannedorder_num
                                   space space space.
      CONTINUE.
    ELSE.
      dup_ponumbers = it_poheader-plannedorder_num.
      APPEND dup_ponumbers.
    ENDIF.
    it_poheader-pldord_profile   = wa_fixval-pasch.
    it_poheader-plan_plant       = it_whplt-werks.
    it_poheader-prod_plant       = it_whplt-werks.
    it_poheader-order_fin_date   = wa_atpdet-dued.
    it_poheader-base_uom      = it_unicv-meins.
    it_poheader-stge_loc         = it_locn-lgort.
    it_poheader-version          = it_locn-verid.
    it_poheader-firming_ind      = 'X'.
    it_poheader-det_schedule     = 'X'.

    APPEND it_poheader.
  ENDLOOP.
* if no valid atp details -> errorcode 2
  IF it_poheader[] IS INITIAL.
    PERFORM insert_message USING 'E' co_msgid '008' idoc_contrl-docnum
                                                    space space space.
    atpdet_code = 2.
  ENDIF.

ENDFORM.                    " ZAATPDET_IDOC_PARSE
*&---------------------------------------------------------------------*
*&      Form  zaatpdet_process_delete
*&---------------------------------------------------------------------*
FORM zaatpdet_process_delete.
  CHECK atpdet_code = 0.

  LOOP AT it_plnum.
    CALL FUNCTION 'BAPI_PLANNEDORDER_DELETE'
      EXPORTING
        plannedorder = it_plnum
      IMPORTING
        return       = wa_bapireturn.
    IF wa_bapireturn-type   NE co_podel_msg-msgtyp OR
       wa_bapireturn-id     NE co_podel_msg-msgid  OR
       wa_bapireturn-number NE co_podel_msg-msgnr.
      PERFORM insert_message USING wa_bapireturn-type
                                   wa_bapireturn-id
                                   wa_bapireturn-number
                                   wa_bapireturn-message_v1
                                   wa_bapireturn-message_v2
                                   wa_bapireturn-message_v3
                                   wa_bapireturn-message_v4.
      PERFORM insert_message USING 'E' co_msgid '010' space space
                                                      space space.
      atpdet_code = 3.
      EXIT.
    ENDIF.
  ENDLOOP.

ENDFORM.                    " zaatpdet_process_delete
*&---------------------------------------------------------------------*
*&      Form  zaatpdet_process_create
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM zaatpdet_process_create.

  DATA: plannedorder LIKE bapi_pldord-pldord_num,
        hf_plnum     LIKE plaf-plnum,
        hf_tries     TYPE i.

  CHECK atpdet_code = 0.

* Commit must be carried out -> duplicate Plannedorder Numbers
  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
    EXPORTING
      wait = 'X'.

* wait 1 more second -> there seem to be Problems that the orders
* aren't completely deleted before recreation starts in case a lot
* of orders have to be deleted
  WAIT UP TO 1 SECONDS.

  LOOP AT it_nrange INTO wa_nrange.
    PERFORM insert_message USING 'I' co_msgid '009' wa_nrange-nrfrom
                                                    wa_nrange-nrto
                                                    space space.
  ENDLOOP.

  LOOP AT it_poheader.
*   due to problems with the update task (too slow) check again if
*   planned order is allready deleted, if not delete again and commit
    SELECT SINGLE plnum FROM plaf
                        INTO hf_plnum
                       WHERE plnum = it_poheader-plannedorder_num.
    IF sy-subrc = 0.
*      delete dirty - do not check return values
      CALL FUNCTION 'BAPI_PLANNEDORDER_DELETE'
        EXPORTING
          plannedorder = it_poheader-plannedorder_num
        IMPORTING
          return       = wa_bapireturn.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = 'X'.
    ENDIF.

*   create
    PERFORM insert_message USING 'I' co_msgid '015'
                                 it_poheader-plannedorder_num
                                 it_poheader-material
                                 space space.
*   try 3 times (locking / update process problems) -> planned order
*   might still exist or be locked
    CLEAR plannedorder.
    hf_tries = 0.

    WHILE plannedorder IS INITIAL.
      hf_tries = hf_tries + 1.

*{   REPLACE        R9SK901046                                        1
*\      CALL FUNCTION 'BAPI_PLANNEDORDER_CREATE'
      CALL FUNCTION 'BAPI_PLANNEDORDER_CREATE'                        "#EC CI_USAGE_OK[2438131]
*}   REPLACE
        EXPORTING
          headerdata   = it_poheader
        IMPORTING
          return       = wa_bapireturn
          plannedorder = plannedorder.
      PERFORM insert_message USING wa_bapireturn-type
                                   wa_bapireturn-id
                                   wa_bapireturn-number
                                   wa_bapireturn-message_v1
                                   wa_bapireturn-message_v2
                                   wa_bapireturn-message_v3
                                   wa_bapireturn-message_v4.

      IF plannedorder IS INITIAL.
        IF hf_tries = 3.
          atpdet_code = 4.
          ADD 1 TO trans_called.
          plannedorder = 'X'. "To exit the loop
        ELSE.
          WAIT UP TO 1 SECONDS. "Wait a bit til the next attempt
        ENDIF.
      ELSE.
        ADD 1 TO trans_ok.
        ADD 1 TO trans_called.
      ENDIF.
    ENDWHILE.
  ENDLOOP.
ENDFORM.                    " zaatpdet_process_create
*&---------------------------------------------------------------------*
*&      Form  ZAATPDET_result_set
*&---------------------------------------------------------------------*
FORM zaatpdet_result_set.

  CLEAR in_update_task.
  CLEAR call_transaction_done.

  CLEAR idoc_status.
  idoc_status-docnum = idoc_contrl-docnum.

  CASE atpdet_code.
    WHEN 0. "Everything OK
    WHEN 1. "Customizing not maintained
    WHEN 2. "IDOC contained error segments
    WHEN 3. "Error during PO DELETE
    WHEN 4. "Error during PO Create/Change
  ENDCASE.

* Everything OK
  IF atpdet_code = 0.
    workflow_result = co_result_ok.
    return_variables-wf_param = co_processed_idocs.
    return_variables-doc_number = idoc_contrl-docnum.
    APPEND return_variables.
    idoc_status-status = co_idoc_status_ok.
    IF trans_called > 1.
      PERFORM insert_message USING 'S' co_msgid '007'
                                   space space space space.
    ENDIF.
  ENDIF.
* Errors occured
  IF atpdet_code NE 0.
    workflow_result = co_result_error.
    return_variables-wf_param = co_error_idocs.
    return_variables-doc_number = idoc_contrl-docnum.
    APPEND return_variables.
  ENDIF.
* Determine if it was a complete or incomplete error
  IF atpdet_code = 1 OR atpdet_code = 2 OR atpdet_code = 3.
    idoc_status-status = co_idoc_status_error.
  ELSEIF atpdet_code = 4.
    IF trans_called > 0 AND trans_ok = 0.
      idoc_status-status = co_idoc_status_error.
    ELSEIF trans_called > 0 AND trans_ok > 0.
      idoc_status-status = co_idoc_status_incomplete.
    ELSE.
      idoc_status-status = co_idoc_status_error.
    ENDIF.
  ENDIF.
* Commit or rollback
  IF idoc_status-status = co_idoc_status_ok OR
     idoc_status-status = co_idoc_status_incomplete.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.
  ELSEIF idoc_status-status = co_idoc_status_error.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
  ENDIF.
* Return messages
  LOOP AT it_stat.
    idoc_status-msgty = it_stat-msgty.
    idoc_status-msgid = it_stat-msgid.
    idoc_status-msgno = it_stat-msgno.
    idoc_status-msgv1 = it_stat-msgv1.
    idoc_status-msgv2 = it_stat-msgv2.
    idoc_status-msgv3 = it_stat-msgv3.
    idoc_status-msgv4 = it_stat-msgv4.
    APPEND idoc_status.
  ENDLOOP.

ENDFORM.                    " ZAATPDET_result_set
*&---------------------------------------------------------------------*
*&      Form  FIELD_CHECK
*&---------------------------------------------------------------------*
FORM field_check USING field name.

  IF field IS INITIAL.
    PERFORM insert_message USING 'E' 'VL' '243' name idoc_data-segnum
                                 space space.
    atpdet_code = 2.
  ENDIF.

ENDFORM.                    " FIELD_CHECK
*&---------------------------------------------------------------------*
*&      Form  insert_message
*&---------------------------------------------------------------------*
FORM insert_message USING us_msgty
                          us_msgid
                          us_msgno
                          us_msgv1
                          us_msgv2
                          us_msgv3
                          us_msgv4.

  CLEAR it_stat.
  it_stat-msgty = us_msgty.
  it_stat-msgid = us_msgid.
  it_stat-msgno = us_msgno.
  it_stat-msgv1 = us_msgv1.
  it_stat-msgv2 = us_msgv2.
  it_stat-msgv3 = us_msgv3.
  it_stat-msgv4 = us_msgv4.
  APPEND it_stat.

ENDFORM.                    " insert_message
*&---------------------------------------------------------------------*
*&      Form  ZAREPBF_ADD_SERVICE_MATERIALS
*&---------------------------------------------------------------------*
FORM zarepbf_add_service_materials TABLES it_gr STRUCTURE it_zarmmts
                                          it_gi STRUCTURE it_zarmmts
                                    USING us_reversal.

  DATA: h_matnr      LIKE mara-matnr,   "Material number
        h_menge      LIKE rm61b-erfmg,  "Component Quantity
        h_bmein      LIKE mara-meins,   "Base unit
        h_bquan      LIKE it_zarmmts-backflquant,
        l_matnr      LIKE mara-matnr,
        l_mtart      LIKE mara-mtart,
        l_meins      LIKE mara-meins,
        rcode        TYPE i,            "Returncode
        h_plnt_excpt TYPE xfeld.

* check each header line for service materials
  LOOP AT it_gr.
    CLEAR: h_matnr.
*   convert materialnumber to internal format
    CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
      EXPORTING
        input        = it_gr-materialnr
      IMPORTING
        output       = h_matnr
      EXCEPTIONS
        length_error = 1
        OTHERS       = 2.
    IF sy-subrc <> 0.
      repbf_code = 4.
      PERFORM insert_status USING co_idoc_status_error
                                  sy-msgty sy-msgid sy-msgno
                                  sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
      EXIT.
    ENDIF.
*   create components in goods issue table for each service material
*   Table Y0PP_REM_SERVICE will not be used any more.
*   Instead corresponding Y0CS Material will be used
*   Check date - old or new part
    IF line_exists( gt_rem_srvplnt_buf[ werks = it_gr-prodplant ] ).
      h_plnt_excpt = 'X'.
    ELSE.
      CLEAR h_plnt_excpt.
    ENDIF.

    " y0pp_rem_active is pre-fetched in the main function
    IF y0pp_rem_active IS NOT INITIAL AND y0pp_rem_active-datum LE it_gr-postdate AND h_plnt_excpt IS INITIAL.
      DATA(ls_mara_srv_local) = VALUE #( gt_mara_buf[ KEY bismt bismt = h_matnr ] OPTIONAL ).
      l_matnr = ls_mara_srv_local-matnr.
      l_mtart = ls_mara_srv_local-mtart.
      l_meins = ls_mara_srv_local-meins.

      IF l_matnr IS NOT INITIAL.
        CLEAR: it_gi,
               h_menge,
               h_bmein,
               h_bquan.
*        set data for service material line
        it_gi-pdc_number    = it_gr-pdc_number.
        it_gi-y0_postype    = 'WA'.
*{   REPLACE        R9SK901046                                        1
*\        it_gi-materialnr    = l_matnr.
        it_gi-materialnr    = y0_ca_converter=>matnr_to_matnr18( l_matnr ).
*}   REPLACE
*{   INSERT         R9SK901046                                        2
        it_gi-material_long = l_matnr.
*}   INSERT
        it_gi-prodplant     = it_gr-prodplant.
        it_gi-storageloc    = it_gr-storageloc.
        h_bquan             = it_gr-backflquant.
        TRANSLATE h_bquan USING ',.'.
        h_menge             = h_bquan.
        it_gi-y0_hmat       = it_gr-materialnr.
        it_gi-y0_hcharg     = it_gr-batch.
*        check unit of measures for conversion
        IF it_gr-unitofmeasure NE l_meins.
*              call conversion WE-UNIT -> Base unit
          PERFORM cf_material_unit_conversion
                  USING h_menge 'X' h_matnr h_bmein
                        it_gr-unitofmeasure rcode.
          IF rcode NE 0.
            repbf_code = 4.
            EXIT.
          ENDIF.
        ENDIF.
*        invert sign in case of reversal
        IF NOT us_reversal IS INITIAL.
          h_menge = h_menge * -1.
        ENDIF.
        it_gi-backflquant = h_menge.
*        set unit of measure
        it_gi-unitofmeasure = l_meins.
        IF us_reversal = 'R'.
          it_gi-postdate   = it_gr-postdate.
          it_gi-docdate    = it_gr-docdate.
          it_gi-planorder  = it_gr-planorder.
          it_gi-y0_hmat    = it_gr-y0_hmat.
          it_gi-y0_hcharg  = it_gr-y0_hcharg.
        ENDIF.
        APPEND it_gi.

      ELSE.
        IF l_mtart = 'FERT'.
          repbf_code = 4.
          PERFORM insert_status USING co_idoc_status_error
                                      'E' 'M3' '304' it_wa-materialnr
                                      space space space.
        ENDIF.
      ENDIF.

    ELSE.
*     Old part
      DATA(lt_rem_service_filtered_local) = FILTER #( gt_rem_service_buf USING KEY hmatn_werks
                                                       WHERE hmatn = h_matnr
                                                         AND werks = it_gr-prodplant ).

      LOOP AT lt_rem_service_filtered_local INTO DATA(ls_rem_service_buf_local).
          CLEAR: it_gi,
                 h_menge,
                 h_bmein,
                 h_bquan.
*        set data for service material line
          it_gi-pdc_number    = it_gr-pdc_number.
          it_gi-y0_postype    = 'WA'.
*{   REPLACE        R9SK901046                                        3
*\          it_gi-materialnr    = y0pp_rem_service-smatn.
          it_gi-materialnr    = y0_ca_converter=>matnr_to_matnr18( ls_rem_service_buf_local-smatn ).
*}   REPLACE
*{   INSERT         R9SK901046                                        4
          it_gi-material_long = ls_rem_service_buf_local-smatn.
*}   INSERT
          it_gi-prodplant     = it_gr-prodplant.
          it_gi-storageloc    = it_gr-storageloc.
          h_bquan             = it_gr-backflquant.
          TRANSLATE h_bquan USING ',.'.
          h_menge             = h_bquan.
          it_gi-y0_hmat       = it_gr-materialnr.
          it_gi-y0_hcharg     = it_gr-batch.
*        check unit of measures for conversion
          IF it_gr-unitofmeasure NE ls_rem_service_buf_local-meins.
*         if it_gr-unitofmeasure ne l_meins.
*           get base unit of header material
            h_bmein = VALUE #( gt_mara_buf[ matnr = h_matnr ]-meins OPTIONAL ).
            IF h_bmein IS INITIAL.
              repbf_code = 4.
              PERFORM insert_status USING co_idoc_status_error
                                          'E' 'M3' '305' h_matnr
                                          space space space.
              EXIT.
            ENDIF.
            IF it_gr-unitofmeasure NE h_bmein.
*              call conversion WE-UNIT -> Base unit
              PERFORM cf_material_unit_conversion
                      USING h_menge 'X' h_matnr h_bmein
                            it_gr-unitofmeasure rcode.
              IF rcode NE 0.
                repbf_code = 4.
                EXIT.
              ENDIF.
            ENDIF.
            IF h_bmein NE ls_rem_service_buf_local-meins.
*              call conve  rsion Base-UNIT -> Unit in customizing table
              PERFORM cf_material_unit_conversion
                      USING h_menge space h_matnr h_bmein
                            ls_rem_service_buf_local-meins rcode.
              IF rcode NE 0.
                repbf_code = 4.
                EXIT.
              ENDIF.
            ENDIF.
          ENDIF.
*        Multiply quantity with factor
          h_menge = h_menge * ls_rem_service_buf_local-faktr.
*        check if negative posting required
          IF ls_rem_service_buf_local-repbf_neg = 'X'.
            h_menge = h_menge * -1.
          ENDIF.
*        invert sign in case of reversal
          IF NOT us_reversal IS INITIAL.
            h_menge = h_menge * -1.
          ENDIF.
          it_gi-backflquant = h_menge.
*        set unit of measure
*         it_gi-unitofmeasure = l_meins.
          it_gi-unitofmeasure = VALUE #( gt_mara_buf[ matnr = it_gi-material_long ]-meins OPTIONAL ).
*{   REPLACE        R9SK901046                                        5
*\                             WHERE matnr = it_gi-materialnr.
                             " WHERE matnr = it_gi-material_long. Lookup from buffer
*}   REPLACE
          IF it_gi-unitofmeasure IS INITIAL.
            repbf_code = 4.
            PERFORM insert_status USING co_idoc_status_error
*{   REPLACE        R9SK901046                                        6
*\                                        'E' 'M3' '305' it_wa-materialnr
                                        'E' 'M3' '305' it_gi-materialnr
*}   REPLACE
                                        space space space.
            EXIT.
          ENDIF.
*        add to components table
          APPEND it_gi.
      ENDLOOP.
    ENDIF.
    IF repbf_code NE 0.
      EXIT.
    ENDIF.
  ENDLOOP.


ENDFORM.                    " ZAREPBF_ADD_SERVICE_MATERIALS
*&---------------------------------------------------------------------*
*&      Form  cf_material_unit_conversion
*&---------------------------------------------------------------------*
FORM cf_material_unit_conversion USING us_menge LIKE rm61b-erfmg
                                       us_kzmeinh TYPE c
                                       us_matnr LIKE mara-matnr
                                       us_meins LIKE mara-meins
                                       us_meinh LIKE mara-meins
                                       us_rcode TYPE i.

  us_rcode = 0.

  CALL FUNCTION 'MATERIAL_UNIT_CONVERSION'
    EXPORTING
      input                = us_menge
      kzmeinh              = us_kzmeinh
      matnr                = us_matnr
      meinh                = us_meinh
      meins                = us_meins
    IMPORTING
      output               = us_menge
    EXCEPTIONS
      conversion_not_found = 1
      input_invalid        = 2
      material_not_found   = 3
      meinh_not_found      = 4
      meins_missing        = 5
      no_meinh             = 6
      output_invalid       = 7
      overflow             = 8
      OTHERS               = 9.
  IF sy-subrc <> 0.
    us_rcode = sy-subrc.
    PERFORM insert_status USING co_idoc_status_error
                                sy-msgty sy-msgid sy-msgno
                                sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
  ENDIF.


ENDFORM.                    " cf_material_unit_conversion
*&---------------------------------------------------------------------*
*&      Form  insert_status
*&---------------------------------------------------------------------*
FORM insert_status USING VALUE(us_status)
                         us_msgtyp
                         us_msgid
                         us_msgnr
                         us_msgv1
                         us_msgv2
                         us_msgv3
                         us_msgv4.

  CLEAR idoc_status.
  idoc_status-docnum = idoc_contrl-docnum.
  idoc_status-status = us_status.
  idoc_status-msgty  = us_msgtyp.
  idoc_status-msgid  = us_msgid.
  idoc_status-msgno  = us_msgnr.
  idoc_status-msgv1  = us_msgv1.
  idoc_status-msgv2  = us_msgv2.
  idoc_status-msgv3  = us_msgv3.
  idoc_status-msgv4  = us_msgv4.
  APPEND idoc_status.

ENDFORM.                    " insert_status
*&---------------------------------------------------------------------*
*&      Form  determine_po_delete
*&---------------------------------------------------------------------*
FORM determine_po_delete.

  CHECK atpdet_code = 0.

  REFRESH it_plnum.

  IF NOT it_y0sd_zatpde_werk[] IS INITIAL.
*    get relevant planned orders
    LOOP AT it_nrange INTO wa_nrange.
      SELECT plnum FROM plaf APPENDING TABLE it_plnum
                         FOR ALL ENTRIES IN it_y0sd_zatpde_werk
                       WHERE plnum BETWEEN wa_nrange-nrfrom AND
                                           wa_nrange-nrto
                         AND plwrk EQ it_y0sd_zatpde_werk-werks.
    ENDLOOP.
  ENDIF.

ENDFORM.                    " determine_po_delete
*&---------------------------------------------------------------------*
*&      Form  translate_quan_for_gui
*&---------------------------------------------------------------------*
FORM translate_quan_for_gui USING us_menge.

  IF wa_dcpfm = space OR wa_dcpfm = 'Y'.
    TRANSLATE us_menge USING '.,'.
  ELSEIF wa_dcpfm = 'X'.
    TRANSLATE us_menge USING ',.'.
  ENDIF.

ENDFORM.                    " translate_quan_for_gui
*&---------------------------------------------------------------------*
*&      Form  add_mkal
*&---------------------------------------------------------------------*
*{   REPLACE        R9SK901046                                        5
*\FORM add_mkal TABLES t_zarmmts STRUCTURE zarmmts
FORM add_mkal TABLES t_zarmmts STRUCTURE it_zarmmts
*}   REPLACE
               USING u_postype LIKE y0bapi_rm_datgen-y0_postype.

  CLEAR it_mkal.

  LOOP AT t_zarmmts.
    IF u_postype = co_postype_we.
*{   REPLACE        R9SK901046                                        3
*\                              WHERE matnr = t_zarmmts-materialnr
      DATA(ls_mkal_buf_local) = VALUE #( gt_mkal_buf[ matnr = t_zarmmts-material_long
                                                      werks = t_zarmmts-prodplant ] OPTIONAL ).
*}   REPLACE
      IF ls_mkal_buf_local IS NOT INITIAL.
        it_mkal-matnr = ls_mkal_buf_local-matnr.
        it_mkal-werks = ls_mkal_buf_local-werks.
        it_mkal-verid = ls_mkal_buf_local-verid.
        COLLECT it_mkal.
      ENDIF.
    ELSEIF u_postype = co_postype_wa.
*{   REPLACE        R9SK901046                                        4
*\                              WHERE matnr = t_zarmmts-y0_hmat
      ls_mkal_buf_local = VALUE #( gt_mkal_buf[ matnr = t_zarmmts-y0_hmat_long
                                                werks = t_zarmmts-prodplant ] OPTIONAL ).
*}   REPLACE
      IF ls_mkal_buf_local IS NOT INITIAL.
        it_mkal-matnr = ls_mkal_buf_local-matnr.
        it_mkal-werks = ls_mkal_buf_local-werks.
        it_mkal-verid = ls_mkal_buf_local-verid.
        COLLECT it_mkal.
      ENDIF.
    ENDIF.
  ENDLOOP.

ENDFORM.                    " add_mkal

*&---------------------------------------------------------------------*
*&      Form  zaatpdetn_idoc_parse
*&---------------------------------------------------------------------*
FORM zaatpdetn_idoc_parse.

  DATA: dup_ponumbers LIKE bapiplaf_i1-plannedorder_num
                           OCCURS 0 WITH HEADER LINE.

  CHECK atpdet_code = 0.

  REFRESH dup_ponumbers.
  LOOP AT idoc_data.
*   check segment
    CHECK idoc_data-segnam = co_zaatpdetn.

    CLEAR: wa_atpdetn, it_poheader.
    wa_atpdetn = idoc_data-sdata.
*   check constants
    CHECK wa_atpdetn-dttp = wa_fixval-zdttp AND
          wa_atpdetn-corp = wa_fixval-zcorp.
*   convert warehouse
    READ TABLE it_whplt WITH KEY zwhse = wa_atpdetn-whse.
    IF sy-subrc NE 0.
      PERFORM insert_message USING 'E' co_msgid '004' wa_atpdetn-whse
                                   space space space.
      atpdet_code = 2.
    ENDIF.
*   convert location
    CLEAR it_locn.
    READ TABLE it_locn WITH KEY zlocn = wa_atpdetn-locn
                                zwhse = wa_atpdetn-whse.

*   Check mandatory fields
    PERFORM field_check USING wa_atpdetn-schd 'SCHD'.
    PERFORM field_check USING wa_atpdetn-resc 'RESC'.
    PERFORM field_check USING wa_atpdetn-dued 'DUED'.
    PERFORM field_check USING wa_atpdetn-qyex 'QYEX'.
    PERFORM field_check USING wa_atpdetn-umsr 'UMSR'.
    CHECK atpdet_code = 0.

    it_poheader-material         = wa_atpdetn-resc.
*   Convert external materialnumber (BISMT) to materialnr.
    CALL FUNCTION 'Y_0CA_PARTNER_CONVERT_MATNR'
      EXPORTING
        matnr_in                = it_poheader-material
        direct                  = '2'
      IMPORTING
        matnr_out               = it_poheader-material
      EXCEPTIONS
        invalid_parameters      = 1
        material_does_not_exist = 2
        OTHERS                  = 3.
    IF sy-subrc NE 0 OR it_poheader-material IS INITIAL.
      PERFORM insert_message USING 'E' co_msgid '014'
                                   wa_atpdetn-resc space space space.
      atpdet_code = 2.
      CONTINUE.
    ENDIF.
*   Convert material number into internal format
    CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
      EXPORTING
        input        = it_poheader-material
      IMPORTING
        output       = it_poheader-material
      EXCEPTIONS
        length_error = 1
        OTHERS       = 2.

*   Check if material exists
    SELECT SINGLE matnr FROM marc INTO marc-matnr
                                 WHERE matnr = it_poheader-material
                                   AND werks = it_whplt-werks.
    IF sy-subrc NE 0.
      PERFORM insert_message USING 'E' co_msgid '005'
                                   it_poheader-material it_whplt-werks
                                   space space.
      atpdet_code = 2.
      CONTINUE.
    ENDIF.
*
    it_poheader-total_plord_qty  = wa_atpdetn-qyex - wa_atpdetn-qyrv.
*   Check Quantity ne 0
    IF it_poheader-total_plord_qty = 0.
      PERFORM insert_message USING 'I' co_msgid '006' wa_atpdetn-schd
                                       space space space.
      CONTINUE.
    ENDIF.

*---> Einbau Mengenconversion
*   not for new type
    CLEAR marm.
    SELECT SINGLE * FROM marm INTO marm
                   WHERE matnr EQ it_poheader-material
                     AND meinh EQ wa_atpdetn-umsr.
    IF sy-subrc IS INITIAL.
      it_poheader-total_plord_qty = it_poheader-total_plord_qty *
                  ( marm-umrez / marm-umren ).
    ENDIF.

    it_poheader-plannedorder_num = wa_atpdetn-schd.
*   check for duplicate plannedorders
    READ TABLE dup_ponumbers WITH KEY it_poheader-plannedorder_num.
    IF sy-subrc = 0.
      atpdet_code = 2.
      PERFORM insert_message USING 'E' co_msgid '013'
                                   it_poheader-plannedorder_num
                                   space space space.
      CONTINUE.
    ELSE.
      dup_ponumbers = it_poheader-plannedorder_num.
      APPEND dup_ponumbers.
    ENDIF.
    it_poheader-pldord_profile   = wa_fixval-pasch.
    it_poheader-plan_plant       = it_whplt-werks.
    it_poheader-prod_plant       = it_whplt-werks.
    it_poheader-order_fin_date   = wa_atpdetn-dued.
    it_poheader-base_uom         = wa_atpdetn-umsr.
    it_poheader-stge_loc         = it_locn-lgort.
    it_poheader-version          = it_locn-verid.
    it_poheader-firming_ind      = 'X'.
    it_poheader-det_schedule     = 'X'.

    APPEND it_poheader.
  ENDLOOP.
* if no valid atp details -> errorcode 2
  IF it_poheader[] IS INITIAL.
    PERFORM insert_message USING 'E' co_msgid '008' idoc_contrl-docnum
                                                    space space space.
    atpdet_code = 2.
  ENDIF.

ENDFORM.                    " zaatpdetn_idoc_parse

*&---------------------------------------------------------------------
*&      Form  Y0ATPDET_init_data
*&---------------------------------------------------------------------
FORM y0atpdet_init_data.

  CLEAR: it_stat,
         it_plnum,
         wa_fixvaln,
         wa_nrange,
         trans_called,
         trans_ok,
         gt_atpresb.

  REFRESH: it_stat,
           it_plnum,
           it_nrange,
           it_plntsloc,
           it_poheader,
           it_pocls,
           it_pldates.

* clear status_code
  atpdet_code = 0.
* get constants
  SELECT SINGLE * FROM y0pp_atp_fixvaln INTO wa_fixvaln
                 WHERE parnum = idoc_contrl-sndprn.
  IF sy-subrc NE 0.
    PERFORM insert_message USING 'E' co_msgid '030' idoc_contrl-sndprn
                                                    space space space.
    atpdet_code = 1.
  ENDIF.
* get number range
  IF wa_fixvaln-aende IS INITIAL.
    IF idoc_contrl-mestyp EQ 'ZATPDE_PR'.
      SELECT * FROM y0pp_po_pnrg INTO TABLE it_nrange
                                      WHERE parnum = idoc_contrl-sndprn.
    ELSE.
      SELECT * FROM y0pp_po_pnrg INTO TABLE it_nrange
                                      WHERE parnum = idoc_contrl-sndprn
                                        AND mestyp = idoc_contrl-mestyp.
    ENDIF.
    IF sy-subrc NE 0.
      PERFORM insert_message USING 'E' co_msgid '001' idoc_contrl-sndprn space space space.
      atpdet_code = 1.
    ENDIF.
  ENDIF.
* Check on Partner number for planned orders to be deleted
  REFRESH it_y0sd_zatpde_werk.
  SELECT werks FROM y0pp_zatpde_werk INTO TABLE it_y0sd_zatpde_werk
           WHERE sndprn EQ idoc_contrl-sndprn.
* get plant/storage location conversion
  SELECT * FROM y0pp_rf_plntsloc INTO TABLE it_plntsloc.

ENDFORM.                    " Y0ATPDET_init_data

*&---------------------------------------------------------------------
*&      Form  Y0ATPDET_CREATE_IDOC_PARSE
*&---------------------------------------------------------------------
FORM y0atpdet_create_idoc_parse.

  DATA: dup_ponumbers LIKE bapiplaf_i1-plannedorder_num OCCURS 0 WITH HEADER LINE,
        lk_plnum      TYPE plnum,
        l_webaz       LIKE marc-y0_webaz,
        l_fxhor       LIKE marc-y0_fxhor,
        l_date        LIKE sy-datum.

  REFRESH dup_ponumbers.


  CHECK atpdet_code = 0.

  LOOP AT idoc_data.
*   main segment - planned order
    CASE idoc_data-segnam.
      WHEN 'Y0ATPDET'.
        CLEAR: wa_y0atpdet, it_poheader, wa_y0atp_prod_vers, lk_plnum.
        wa_y0atpdet = idoc_data-sdata.
*      Check mandatory fields
        PERFORM field_check USING wa_y0atpdet-plnum 'PLNUM'.
        PERFORM field_check USING wa_y0atpdet-matnr 'MATNR'.
        PERFORM field_check USING wa_y0atpdet-gltrs 'GLTRS'.
        PERFORM field_check USING wa_y0atpdet-gsmng 'GSMNG'.
        PERFORM field_check USING wa_y0atpdet-meins 'MEINS'.
        CHECK atpdet_code = 0.

        "if delivery completed -> skip (received in case CFR demand is still open)
        CHECK wa_y0atpdet-elikz IS INITIAL.
        CHECK ( wa_y0atpdet-gsmng - wa_y0atpdet-rvmng ) > 0.

**     move fields
        it_poheader-plannedorder_num = wa_y0atpdet-plnum.
        it_poheader-material         = wa_y0atpdet-matnr.
        it_poheader-plan_plant       = wa_y0atpdet-werks.
        it_poheader-prod_plant       = wa_y0atpdet-werks.
        it_poheader-stge_loc         = wa_y0atpdet-lgort.
        it_poheader-total_plord_qty  = wa_y0atpdet-gsmng - wa_y0atpdet-rvmng.
        it_poheader-base_uom         = wa_y0atpdet-meins.
        it_poheader-order_fin_date   = wa_y0atpdet-gltrs.
        it_poheader-order_start_date = wa_y0atpdet-gstrs.
        it_poheader-gr_proc_time     = wa_y0atpdet-webaz.

        SELECT SINGLE * FROM y0atp_prod_vers INTO wa_y0atp_prod_vers
               WHERE werks = wa_y0atpdet-werks
                 AND arbpl = wa_y0atpdet-arbpl.
        IF sy-subrc IS INITIAL.
          it_poheader-version          = wa_y0atp_prod_vers-verid.
        ENDIF.

* Task 11-59036: Change calculation of GR processing time
****       if it_poheader-GR_PROC_TIME = 0 and
****          it_poheader-order_fin_date <= it_poheader-order_start_date.
****          it_poheader-GR_PROC_TIME = 1.
****       endif.
        it_poheader-gr_proc_time = wa_y0atpdet-webaz + wa_fixvaln-addgr.

*      Convert external materialnumber (BISMT) to materialnr.
        CALL FUNCTION 'Y_0CA_PARTNER_CONVERT_MATNR'
          EXPORTING
            matnr_in                = it_poheader-material
            direct                  = '2'
          IMPORTING
            matnr_out               = it_poheader-material
          EXCEPTIONS
            invalid_parameters      = 1
            material_does_not_exist = 2
            OTHERS                  = 3.
        IF sy-subrc NE 0 OR it_poheader-material IS INITIAL.
          PERFORM insert_message USING 'E' co_msgid '014'
                                       it_poheader-material
                                       space space space.
          atpdet_code = 2.
          CONTINUE.
        ENDIF.

*      Is there a special GR Time maintained for the material
        SELECT SINGLE * FROM y0pp_atp_gr_time INTO wa_gr_time
                        WHERE matnr = it_poheader-material.
        IF sy-subrc IS INITIAL.
          it_poheader-gr_proc_time = wa_y0atpdet-webaz + wa_gr_time-addgr.
        ENDIF.

        it_poheader-pldord_profile   = wa_fixvaln-pasch.
        it_poheader-firming_ind      = wa_fixvaln-plafx.
        it_poheader-det_schedule     = wa_fixvaln-termx.
**     convert fields

*      Convert planned order number number into internal format
        CALL FUNCTION 'CONVERSION_EXIT_ALPHA_INPUT'
          EXPORTING
            input        = it_poheader-plannedorder_num
          IMPORTING
            output       = it_poheader-plannedorder_num
          EXCEPTIONS
            length_error = 1
            OTHERS       = 2.
*      Convert material number into internal format
        CALL FUNCTION 'CONVERSION_EXIT_MATN1_INPUT'
          EXPORTING
            input        = it_poheader-material
          IMPORTING
            output       = it_poheader-material
          EXCEPTIONS
            length_error = 1
            OTHERS       = 2.


*     Check material master and calculate GR processing time
        CLEAR: l_webaz, l_fxhor, l_date.
        SELECT SINGLE y0_webaz y0_fxhor FROM marc INTO (l_webaz, l_fxhor)
               WHERE matnr = it_poheader-material
                 AND werks = it_poheader-prod_plant.
        IF sy-subrc IS INITIAL AND l_webaz IS NOT INITIAL AND l_fxhor IS NOT INITIAL.
          l_date = sy-datum + l_fxhor.
          IF l_date GT it_poheader-order_fin_date.
            it_poheader-gr_proc_time = wa_y0atpdet-webaz + l_webaz.
          ENDIF.
        ENDIF.


*      Plant/Storage location conversion
        READ TABLE it_plntsloc WITH KEY werks_rf = it_poheader-prod_plant
                                        lgort_rf = it_poheader-stge_loc.
        IF sy-subrc = 0.
          it_poheader-plan_plant = it_plntsloc-werks.
          it_poheader-prod_plant = it_plntsloc-werks.
          it_poheader-stge_loc   = it_plntsloc-lgort.
        ENDIF.
**     perform checks
*      check for duplicate plannedorders
        READ TABLE dup_ponumbers WITH KEY it_poheader-plannedorder_num.
        IF sy-subrc = 0.
          atpdet_code = 2.
          PERFORM insert_message USING 'E' co_msgid '013'
                                       it_poheader-plannedorder_num
                                       space space space.
          CONTINUE.
        ELSE.
          dup_ponumbers = it_poheader-plannedorder_num.
          APPEND dup_ponumbers.
        ENDIF.
*      Check Quantity ne 0
        IF it_poheader-total_plord_qty = 0.
          PERFORM insert_message USING 'I' co_msgid '006' wa_atpdet-schd
                                           space space space.
          CONTINUE.
        ENDIF.
*      Check if material exists
        SELECT SINGLE matnr FROM marc INTO marc-matnr
                           WHERE matnr = it_poheader-material
                             AND werks = it_poheader-prod_plant.
        IF sy-subrc NE 0.
          PERFORM insert_message USING 'E' co_msgid '005'
                                       it_poheader-material
                                       it_poheader-prod_plant
                                       space space.
          atpdet_code = 2.
          CONTINUE.
        ENDIF.
*      add to PO creation table
        APPEND it_poheader.
        lk_plnum = it_poheader-plannedorder_num. "planned order checks ok, remember number for classification
*      add to date/time table
        CLEAR it_pldates.
        it_pldates-plnum = it_poheader-plannedorder_num.
        it_pldates-gltrs = wa_y0atpdet-gltrs.
        it_pldates-gluzs = wa_y0atpdet-gluzs.
        it_pldates-gstrs = wa_y0atpdet-gstrs.
        it_pldates-gsuzs = wa_y0atpdet-gsuzs.
        APPEND it_pldates.

        "(CFR) reservation segments
      WHEN 'Y0ATPRESB'.
        IF lk_plnum IS NOT INITIAL. "planned order was ok.
          CLEAR: gs_atpresb, wa_y0atpresb.
          wa_y0atpresb = idoc_data-sdata.
          MOVE-CORRESPONDING wa_y0atpresb TO gs_atpresb.

          "only relevant if open quantity
          IF gs_atpresb-bdmng > gs_atpresb-enmng.
            gs_atpresb-plnum = lk_plnum.

            "plant + requirement date from header
            gs_atpresb-bdter = it_pldates-gstrs.
            gs_atpresb-werks = it_poheader-prod_plant.

            APPEND gs_atpresb TO gt_atpresb.
          ENDIF.
        ENDIF.

*   Classification Segments (per Planned Order)
      WHEN 'Y0ATPCLS'.
        IF lk_plnum IS NOT INITIAL. "planned order was ok.
          CLEAR it_pocls.
          CLEAR wa_y0atpcls.
          "
          wa_y0atpcls = idoc_data-sdata.
          it_pocls-mandt = sy-mandt.
          it_pocls-plnum = lk_plnum.
          it_pocls-atnam = wa_y0atpcls-id.
          it_pocls-atwrt = wa_y0atpcls-value.
          "check if id and value are populated
          IF it_pocls-atnam IS NOT INITIAL AND it_pocls-atwrt IS NOT INITIAL.
            "check the existance of the characterstic
            PERFORM check_characteristic_existance USING 'Y0_FINISHED_GOODS' '023' it_pocls-atnam
                                                CHANGING sy-subrc.
            IF sy-subrc = 0.
              "convert the value (old material number to RB material number)
              CALL FUNCTION 'Y_0CA_PARTNER_CONVERT_MATNR'
                EXPORTING
*{   REPLACE        R9SK901046                                        2
*\                matnr_in  = it_pocls-atwrt
                  matnr_in  = it_pocls-atwrt "#EC CI_FLDEXT_OK[2215424]
*}   REPLACE
                  direct    = idoc_contrl-direct
                IMPORTING
*{   REPLACE        R9SK901046                                        1
*\                matnr_out = it_pocls-atwrt
                  matnr_out = it_pocls-atwrt "#EC CI_FLDEXT_OK[2215424]
*}   REPLACE
                EXCEPTIONS
                  OTHERS    = 1.

              APPEND it_pocls.
            ELSE.
              PERFORM insert_message USING 'E' 'CL' '033' it_pocls-atnam space space space.
              atpdet_code = 2.
            ENDIF.
          ENDIF.
        ENDIF.
    ENDCASE.
  ENDLOOP.
* if no valid atp details -> errorcode 2
  IF it_poheader[] IS INITIAL.
    PERFORM insert_message USING 'E' co_msgid '008'
                           idoc_contrl-docnum space space space.
    atpdet_code = 2.
  ENDIF.

ENDFORM.                    " Y0ATPDET_CREATE_IDOC_PARSE

*&---------------------------------------------------------------------
*&      Form  Y0ATPDET_CHANGE_IDOC_PARSE
*&---------------------------------------------------------------------
FORM y0atpdet_change_idoc_parse.
  CHECK atpdet_code = 0.

  LOOP AT idoc_data WHERE segnam = 'Y0ATPDET'.
    CLEAR: wa_y0atpdet, it_poheader.
    wa_y0atpdet = idoc_data-sdata.
*   Check mandatory fields
    PERFORM field_check USING wa_y0atpdet-plnum 'PLNUM'.
    CHECK atpdet_code = 0.
*   move fields
    it_poheader-plannedorder_num = wa_y0atpdet-plnum.
    it_poheader-total_plord_qty  = wa_y0atpdet-gsmng - wa_y0atpdet-rvmng.
    it_poheader-order_fin_date   = wa_y0atpdet-gltrs.
    it_poheader-order_start_date = wa_y0atpdet-gstrs.
    it_poheader-firming_ind      = wa_fixvaln-plafx.
    it_poheader-det_schedule     = wa_fixvaln-termx.
*   add
    APPEND it_poheader.
*   add to date/time table
    CLEAR it_pldates.
    it_pldates-plnum = it_poheader-plannedorder_num.
    it_pldates-gltrs = wa_y0atpdet-gltrs.
    it_pldates-gluzs = wa_y0atpdet-gluzs.
    it_pldates-gstrs = wa_y0atpdet-gstrs.
    it_pldates-gsuzs = wa_y0atpdet-gsuzs.
    APPEND it_pldates.
  ENDLOOP.
* if no valid atp details -> errorcode 2
  IF sy-subrc NE 0.
    PERFORM insert_message USING 'E' co_msgid '008'
                           idoc_contrl-docnum space space space.
    atpdet_code = 2.
  ENDIF.

ENDFORM.                    " Y0ATPDET_CHANGE_IDOC_PARSE

*&---------------------------------------------------------------------*
*&      Form  y0atpdet_process_create
*&---------------------------------------------------------------------*
FORM y0atpdet_process_create.
* local data
  DATA: plannedorder LIKE bapi_pldord-pldord_num,
        hf_plnum     LIKE plaf-plnum,
        hf_tries     TYPE i.

  CHECK atpdet_code = 0.

* Commit must be carried out -> duplicate Plannedorder Numbers
  CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
    EXPORTING
      wait = 'X'.

* wait 1 more seconds -> there seem to be Problems that the orders
* aren't completely deleted before recreation starts in case a lot
* of orders have to be deleted
  WAIT UP TO 1 SECONDS.

  LOOP AT it_nrange INTO wa_nrange.
    PERFORM insert_message USING 'I' co_msgid '009' wa_nrange-nrfrom
                                                    wa_nrange-nrto
                                                    space space.
  ENDLOOP.

  LOOP AT it_poheader.
*   due to problems with the update task (too slow) check again if
*   planned order is allready deleted, if not delete again and commit
    SELECT SINGLE plnum FROM plaf
                        INTO hf_plnum
                       WHERE plnum = it_poheader-plannedorder_num.
    IF sy-subrc = 0.
*      delete dirty - do not check return values
      CALL FUNCTION 'BAPI_PLANNEDORDER_DELETE'
        EXPORTING
          plannedorder = it_poheader-plannedorder_num
        IMPORTING
          return       = wa_bapireturn.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = 'X'.
    ENDIF.
*   create
    PERFORM insert_message USING 'I' co_msgid '015'
                                 it_poheader-plannedorder_num
                                 it_poheader-material
                                 space space.

*   Step 1 - create planned order
*   try 3 times (locking / update process problems) -> planned order
*   might still exist or be locked
    CLEAR: plannedorder,
           wa_bapireturn.
    hf_tries = 0.

    WHILE plannedorder IS INITIAL.
      hf_tries = hf_tries + 1.

*{   REPLACE        R9SK901046                                        1
*\      CALL FUNCTION 'BAPI_PLANNEDORDER_CREATE'
      CALL FUNCTION 'BAPI_PLANNEDORDER_CREATE'                        "#EC CI_USAGE_OK[2438131]
*}   REPLACE
        EXPORTING
          headerdata   = it_poheader
        IMPORTING
          return       = wa_bapireturn
          plannedorder = plannedorder.
      PERFORM insert_message USING wa_bapireturn-type
                                   wa_bapireturn-id
                                   wa_bapireturn-number
                                   wa_bapireturn-message_v1
                                   wa_bapireturn-message_v2
                                   wa_bapireturn-message_v3
                                   wa_bapireturn-message_v4.

      IF plannedorder IS INITIAL.
        IF hf_tries = 3.
          atpdet_code = 4.
          ADD 1 TO trans_called.
          plannedorder = 'X'. "To exit the loop
        ELSE.
          WAIT UP TO 1 SECONDS. "Wait a bit til the next attempt
        ENDIF.
      ELSE.
        ADD 1 TO trans_called.
        ADD 1 TO trans_ok.
        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
          EXPORTING
            wait = 'X'.
*       Step 2 - change planned order - dates & times
        PERFORM y0atpdet_process_dates USING plannedorder.
*       Step 3 -Insert Customer Classification Data
        LOOP AT it_pocls WHERE plnum = it_poheader-plannedorder_num.
          it_pocls-plnum = plannedorder. "in case of internal numbering
          MODIFY y0pp_plaf_cls FROM it_pocls.
        ENDLOOP.
        IF sy-subrc = 0.
          COMMIT WORK AND WAIT.
        ENDIF.
      ENDIF.
    ENDWHILE.
  ENDLOOP.

ENDFORM.                    " y0atpdet_process_create
*&---------------------------------------------------------------------*
*&      Form  Y0ATPDET_PROCESS_CHANGE
*&---------------------------------------------------------------------*
FORM y0atpdet_process_change.
* local data
  DATA: ls_pochange LIKE bapiplaf_i2,
        ls_pochangx LIKE bapiplaf_i2x.

  LOOP AT it_poheader.
*   init
    CLEAR: ls_pochange,
           ls_pochangx,
           wa_bapireturn.
*   move data
    MOVE-CORRESPONDING it_poheader TO ls_pochange.
    ls_pochangx-total_plord_qty  = 'X'.
    ls_pochangx-order_fin_date   = 'X'.
    ls_pochangx-order_start_date = 'X'.
    ls_pochangx-firming_ind      = 'X'.
    ls_pochangx-det_schedule     = 'X'.
*   adjust planned opening date if necessary (greater than new order start date)
    SELECT SINGLE pertr FROM plaf INTO ls_pochange-plan_open_date WHERE plnum = it_poheader-plannedorder_num.
    IF ls_pochange-plan_open_date > ls_pochange-order_start_date.
      ls_pochange-plan_open_date = ls_pochange-order_start_date.
      ls_pochangx-plan_open_date = 'X'.
    ENDIF.
*   change the planned order
*{   REPLACE        R9SK901046                                        1
*\    CALL FUNCTION 'BAPI_PLANNEDORDER_CHANGE'
    CALL FUNCTION 'BAPI_PLANNEDORDER_CHANGE'                          "#EC CI_USAGE_OK[2438131]
*}   REPLACE
      EXPORTING
        plannedorder = it_poheader-plannedorder_num
        headerdata   = ls_pochange
        headerdatax  = ls_pochangx
      IMPORTING
        return       = wa_bapireturn.
    ADD 1 TO trans_called.
    PERFORM insert_message USING wa_bapireturn-type wa_bapireturn-id wa_bapireturn-number wa_bapireturn-message_v1 wa_bapireturn-message_v2 wa_bapireturn-message_v3 wa_bapireturn-message_v4.
*   check
    IF wa_bapireturn-id = '61' AND wa_bapireturn-number = '011'.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = 'X'.
      ADD 1 TO trans_ok.
*     Change dates
      PERFORM y0atpdet_process_dates USING it_poheader-plannedorder_num.
    ELSE.
      atpdet_code = 4.
    ENDIF.
  ENDLOOP.
ENDFORM.                    " Y0ATPDET_PROCESS_CHANGE
*&---------------------------------------------------------------------*
*&      Form  Y0ATPDET_PROCESS_DATES
*&---------------------------------------------------------------------*
FORM y0atpdet_process_dates USING us_plnum TYPE plnum.
* local data
*{   REPLACE        R9SK901046                                        1
*\  DATA: it_kbkoi LIKE kbko OCCURS 0 WITH HEADER LINE,
*\        it_kbkou LIKE kbko OCCURS 0 WITH HEADER LINE,
*\        it_kbkod LIKE kbko OCCURS 0 WITH HEADER LINE,
*\        it_kbedi LIKE kbed OCCURS 0 WITH HEADER LINE,
*\        it_kbedu LIKE kbed OCCURS 0 WITH HEADER LINE,
*\        it_kbedd LIKE kbed OCCURS 0 WITH HEADER LINE,
  DATA: it_kbkoi LIKE kbko OCCURS 0 WITH HEADER LINE, "#EC CI_USAGE_OK[2380568]
        it_kbkou LIKE kbko OCCURS 0 WITH HEADER LINE, "#EC CI_USAGE_OK[2380568]
        it_kbkod LIKE kbko OCCURS 0 WITH HEADER LINE, "#EC CI_USAGE_OK[2380568]
        it_kbedi LIKE kbed OCCURS 0 WITH HEADER LINE, "#EC CI_USAGE_OK[2380568]
        it_kbedu LIKE kbed OCCURS 0 WITH HEADER LINE, "#EC CI_USAGE_OK[2380568]
        it_kbedd LIKE kbed OCCURS 0 WITH HEADER LINE, "#EC CI_USAGE_OK[2380568]
*}   REPLACE
*{   REPLACE        R9SK901046                                        3
*\        it_kbezi LIKE kbez OCCURS 0 WITH HEADER LINE,
*\        it_kbezu LIKE kbez OCCURS 0 WITH HEADER LINE,
*\        it_kbezd LIKE kbez OCCURS 0 WITH HEADER LINE,
        it_kbezi LIKE kbez OCCURS 0 WITH HEADER LINE, "#EC CI_USAGE_OK[2380568]
        it_kbezu LIKE kbez OCCURS 0 WITH HEADER LINE, "#EC CI_USAGE_OK[2380568]
        it_kbezd LIKE kbez OCCURS 0 WITH HEADER LINE, "#EC CI_USAGE_OK[2380568]
*}   REPLACE
        it_obsta LIKE ionrb OCCURS 0 WITH HEADER LINE,
        it_kbsta LIKE ionrb OCCURS 0 WITH HEADER LINE,
        it_mdpmx LIKE mdpm OCCURS 0 WITH HEADER LINE,
        it_mdsbx LIKE mdsb OCCURS 0 WITH HEADER LINE.

  DATA: wa_plaf  LIKE plaf,
        wa_cm61w LIKE cm61w,
        wa_cm61m LIKE cm61m,
        wa_t024d LIKE t024d,
        wa_t399d LIKE t399d,
* ERPSD-80 - Change reuquirement dates of components - PAU-ASC - 25.01.2019 - START
        wa_mdpa  LIKE mdpa,
* ERPSD-80 - Change reuquirement dates of components - PAU-ASC - 25.01.2019 - END
        lv_idoc  TYPE c.
* init
  CLEAR: wa_plaf,
         it_pldates,
         wa_cm61w,
         wa_cm61m,
         wa_t024d,
         wa_t399d.

  REFRESH: it_kbkoi,
           it_kbkou,
           it_kbkod,
           it_kbedi,
           it_kbedu,
           it_kbedd,
           it_kbezi,
           it_kbezu,
           it_kbezd,
           it_obsta,
           it_kbsta,
           it_mdpmx,
           it_mdsbx.
*
  SELECT SINGLE * FROM plaf INTO wa_plaf WHERE plnum = us_plnum.
  READ TABLE it_pldates WITH KEY plnum = us_plnum.
* end time may not be earlier than current date/time
  IF it_pldates-gltrs < sy-datum.
    it_pldates-gltrs = sy-datum.
  ENDIF.
  IF it_pldates-gltrs = sy-datum AND it_pldates-gluzs < sy-uzeit.
    it_pldates-gluzs = sy-uzeit.
  ENDIF.
* get capacity header & records
*{   REPLACE        R9SK901046                                        2
*\  SELECT * FROM kbko INTO TABLE it_kbkou WHERE bedid = wa_plaf-bedid.
*\  SELECT * FROM kbed INTO TABLE it_kbedu WHERE bedid = wa_plaf-bedid.
  SELECT * FROM kbko INTO TABLE it_kbkou WHERE bedid = wa_plaf-bedid. "#EC CI_USAGE_OK[2380568]
  SELECT * FROM kbed INTO TABLE it_kbedu WHERE bedid = wa_plaf-bedid. "#EC CI_USAGE_OK[2380568]
*}   REPLACE

* ERPSD-80 - Change reuquirement dates of components - PAU-ASC - 25.01.2019 - START
  MOVE-CORRESPONDING wa_plaf TO wa_mdpa.
  CALL FUNCTION 'MD_LESEN_KOMPONENTEN'
    EXPORTING
      emdpa = wa_mdpa
    TABLES
      mdpmx = it_mdpmx.
  LOOP AT it_mdpmx.
    it_mdpmx-bdter = it_pldates-gstrs.
    it_mdpmx-sbter = it_pldates-gstrs.
    MODIFY it_mdpmx.
  ENDLOOP.
* ERPSD-80 - Change reuquirement dates of components - PAU-ASC - 25.01.2019 - END

  LOOP AT it_kbkou.
    it_kbkou-gluzs = it_pldates-gluzs.
    it_kbkou-gltrs = it_pldates-gltrs.
    it_kbkou-gsuzs = it_pldates-gsuzs.
    it_kbkou-gstrs = it_pldates-gstrs.
    MODIFY it_kbkou.
  ENDLOOP.
  LOOP AT it_kbedu.
    it_kbedu-fendu = it_pldates-gluzs.
    it_kbedu-sendu = it_pldates-gluzs.
    it_kbedu-fssaz = it_pldates-gluzs.
    it_kbedu-sssaz = it_pldates-gluzs.

    it_kbedu-fendd = it_pldates-gltrs.
    it_kbedu-sendd = it_pldates-gltrs.
    it_kbedu-fssad = it_pldates-gltrs.
    it_kbedu-sssad = it_pldates-gltrs.

    it_kbedu-fstau = it_pldates-gsuzs.
    it_kbedu-sstau = it_pldates-gsuzs.
    it_kbedu-fssbz = it_pldates-gsuzs.
    it_kbedu-sssbz = it_pldates-gsuzs.

    it_kbedu-fstad = it_pldates-gstrs.
    it_kbedu-sstad = it_pldates-gstrs.
    it_kbedu-fssad = it_pldates-gstrs.
    it_kbedu-sssad = it_pldates-gstrs.

    MODIFY it_kbedu.
  ENDLOOP.

  IF NOT it_kbkou[] IS INITIAL OR NOT it_kbedu[] IS INITIAL.
*   update
    lv_idoc = abap_true.
    EXPORT lv_idoc FROM lv_idoc TO MEMORY ID 'Y0PP_IDOC'.
    CALL FUNCTION 'VERAENDERN_PLANAUFTRAG'
      EXPORTING
        ecm61m    = wa_cm61m
        ecm61w    = wa_cm61w
        eplaf     = wa_plaf
        et024d    = wa_t024d
        et399d    = wa_t399d
* ERPSD-80 - Change reuquirement dates of components - PAU-ASC - 25.01.2019 - START
        bomch     = 'X'
* ERPSD-80 - Change reuquirement dates of components - PAU-ASC - 25.01.2019 - END
        schch     = 'X'
      TABLES
        kbezd     = it_kbezd
        kbezi     = it_kbezi
        kbezu     = it_kbezu
        kbedd     = it_kbedd
        kbedi     = it_kbedi
        kbedu     = it_kbedu
        kbkod     = it_kbkod
        kbkoi     = it_kbkoi
        kbkou     = it_kbkou
        mdpmx     = it_mdpmx
        mdsbx     = it_mdsbx
        t_obsta_d = it_obsta
        t_kbsta_d = it_kbsta.
    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.
    FREE MEMORY ID 'Y0PP_IDOC'.
  ELSE.
    PERFORM insert_message USING 'E' co_msgid '032' us_plnum space space space.
    SUBTRACT 1 FROM trans_ok.
    atpdet_code = 4.
  ENDIF.
ENDFORM.                    " Y0ATPDET_PROCESS_DATES
*&---------------------------------------------------------------------*
*&      Form  CHECK_CHARACTERISTIC_EXISTANCE
*&---------------------------------------------------------------------*
FORM check_characteristic_existance USING us_class TYPE klasse_d
                                          us_klart TYPE klassenart
                                          us_atnam TYPE atnam
                                 CHANGING ch_subrc.
* local data
  DATA: lt_char TYPE STANDARD TABLE OF bapi_char,
        lt_vals TYPE STANDARD TABLE OF bapi_char_values.
* get classes
*{   REPLACE        R9SK901046                                        1
*\  CALL FUNCTION 'BAPI_CLASS_GET_CHARACTERISTICS'
  CALL FUNCTION 'BAPI_CLASS_GET_CHARACTERISTICS'                      "#EC CI_USAGE_OK[2438131]
*}   REPLACE
    EXPORTING
      classnum        = us_class
      classtype       = us_klart
    TABLES
      characteristics = lt_char
      char_values     = lt_vals.
  READ TABLE lt_char TRANSPORTING NO FIELDS WITH KEY name_char = us_atnam.
  IF sy-subrc NE 0.
    "Characteristic does not exist!
    ch_subrc = sy-subrc.
  ELSE.
    ch_subrc = 0.
  ENDIF.

ENDFORM.                    " CHECK_CHARACTERISTIC_EXISTANC
*&---------------------------------------------------------------------*
*&      Form  ZAREPBF_CLS_POST
*&---------------------------------------------------------------------*
FORM zarepbf_cls_post .
* local data
  DATA: lt_mcha TYPE STANDARD TABLE OF mcha WITH HEADER LINE,
        ls_mcha TYPE mcha,

        BEGIN OF lt_atnam OCCURS 0,
          atnam TYPE atnam,
          atbew TYPE atbew,
        END OF lt_atnam,

        lk_objky     TYPE objnum,
        lk_chardt    TYPE bapicharactdetail,
        lt_vnum      TYPE STANDARD TABLE OF bapi1003_alloc_values_num WITH HEADER LINE,
        lt_vchar     TYPE STANDARD TABLE OF bapi1003_alloc_values_char WITH HEADER LINE,
        lt_vcurr     TYPE STANDARD TABLE OF bapi1003_alloc_values_curr WITH HEADER LINE,
        lt_return    TYPE STANDARD TABLE OF bapiret2 WITH HEADER LINE,

        lt_vchar_old TYPE STANDARD TABLE OF bapi1003_alloc_values_char WITH HEADER LINE.

  CHECK trans_ok > 0 OR idoc_contrl-mescod = co_mescod_cls. "only do if MFBF postings were ok (or if we do classification update only)
  CHECK it_zarmcls[] IS NOT INITIAL.

* determine materials & batches; determine characterstics for checks
  LOOP AT it_zarmcls.
    lt_mcha-matnr = it_zarmcls-y0_hmat.
    lt_mcha-charg = it_zarmcls-y0_hcharg.
    lt_mcha-werks = it_zarmcls-prodplant.
    lt_mcha-vfdat = it_zarmcls-y0_seldate.
    lt_mcha-hsdat = it_zarmcls-y0_proddate.

    "Batch data maint. (not if we only update classifications)
    IF idoc_contrl-mescod <> co_mescod_cls.
      "field substitution (same as user-exit for batch creation during MFBF posting)
      CALL FUNCTION 'Y0MM_BATCH_DATA_MAINTENANCE'
        EXPORTING
          i_charg       = lt_mcha-charg
          i_charg_matnr = lt_mcha-matnr
          i_charg_werks = lt_mcha-werks
          i_charg_vfdat = lt_mcha-vfdat
          i_docum_werks = it_zarmcls-prodplant
          i_docum_lgort = it_zarmcls-storageloc
        IMPORTING
          e_herkl       = lt_mcha-herkl
          e_fvdt1       = lt_mcha-fvdt1
          e_fvdt2       = lt_mcha-fvdt2.
    ENDIF.
    "
    COLLECT lt_mcha.
    "
    lt_atnam = it_zarmcls-id.
    COLLECT lt_atnam.
  ENDLOOP.

  SORT lt_mcha.
  DELETE ADJACENT DUPLICATES FROM lt_mcha COMPARING matnr werks charg.

* determine characteristic assignment possiblities (single/multi) - characteristic existance already checked before
  LOOP AT lt_atnam.
*{   REPLACE        R9SK901046                                        1
*\    CALL FUNCTION 'BAPI_CHARACT_GETDETAIL'
    lt_atnam-atbew = VALUE #( gt_char_detail_buf[ atnam = lt_atnam-atnam ]-atbew OPTIONAL ).
*}   REPLACE
    MODIFY lt_atnam.
  ENDLOOP.

* process per batch
  LOOP AT lt_mcha.
*   check if batch exists (on header level), if not create (on plant level because of date fields)
    IF NOT line_exists( gt_mch1_buf[ matnr = lt_mcha-matnr charg = lt_mcha-charg ] ).

      IF idoc_contrl-mescod = co_mescod_cls. "Classification Update? -> ignore if no batch exists
        PERFORM insert_status USING co_idoc_status_ok 'E' 'Y0PP_IDOCS' '037' lt_mcha-matnr lt_mcha-charg space space.
        CONTINUE.

      ELSE. "otherwise create batch
        ADD 1 TO trans_called.
        CLEAR ls_mcha.
        ls_mcha = lt_mcha.
        CALL FUNCTION 'VB_CREATE_BATCH'
          EXPORTING
            ymcha          = ls_mcha
            check_customer = space
          IMPORTING
            ymcha          = ls_mcha
          EXCEPTIONS
            OTHERS         = 1.
        IF sy-subrc = 0 AND ls_mcha IS NOT INITIAL.
          COMMIT WORK AND WAIT.
          ADD 1 TO trans_ok.
          PERFORM insert_status USING co_idoc_status_ok 'S' '12' '128' lt_mcha-charg space space space.
        ELSE.
          repbf_code = 4.
          PERFORM insert_status USING co_idoc_status_error 'E' sy-msgid sy-msgno sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
          CONTINUE.
        ENDIF.
      ENDIF.
    ENDIF.

*   get current assignments
    CLEAR lk_objky.

    lk_objky(18) = lt_mcha-matnr.
    lk_objky+18  = lt_mcha-charg.
    REFRESH: lt_vnum,
             lt_vchar,
             lt_vcurr,
             lt_return.
*{   REPLACE        R9SK901046                                        3
*\    CALL FUNCTION 'BAPI_OBJCL_GETDETAIL'
    CALL FUNCTION 'BAPI_OBJCL_GETDETAIL'                              "#EC CI_USAGE_OK[2438131]
*}   REPLACE
      EXPORTING
        objectkey       = lk_objky
        objecttable     = 'MCH1'
        classnum        = 'Y0_FINISHED_GOODS'
        classtype       = '023'
      TABLES
        allocvaluesnum  = lt_vnum
        allocvalueschar = lt_vchar
        allocvaluescurr = lt_vcurr
        return          = lt_return.
    lt_vchar_old[] = lt_vchar[].
*   get new assignments
    LOOP AT it_zarmcls WHERE y0_hmat   = lt_mcha-matnr
                         AND y0_hcharg = lt_mcha-charg
                         AND prodplant = lt_mcha-werks.
*     determine characteritic type (single/multi)
      CLEAR lt_atnam.
      READ TABLE lt_atnam WITH KEY atnam = it_zarmcls-id.
*     add assignment to batch classification
*     -> add if multi assignment and if the same value doesn't already exist
*     -> change if single assignment and if the same value doesn't already exist
      READ TABLE lt_vchar WITH KEY charact = it_zarmcls-id.
      IF sy-subrc = 0.
        READ TABLE lt_vchar WITH KEY charact = it_zarmcls-id
                                     value_char = it_zarmcls-value.
        IF sy-subrc NE 0.
          IF lt_atnam-atbew = 'M'. "multi assignment possible
            CLEAR lt_vchar.
            lt_vchar-charact       = it_zarmcls-id.
            lt_vchar-value_char  = lt_vchar-value_char_long  = it_zarmcls-value.
            lt_vchar-value_neutral = lt_vchar-value_neutral_long = it_zarmcls-value.
            APPEND lt_vchar.
          ELSE. "single assignment, replace value
            lt_vchar-value_char  = lt_vchar-value_char_long  = it_zarmcls-value.
            lt_vchar-value_neutral = lt_vchar-value_neutral_long = it_zarmcls-value.
            MODIFY lt_vchar TRANSPORTING value_char value_char_long value_neutral value_neutral_long WHERE charact = it_zarmcls-id.
          ENDIF.
        ENDIF.
      ELSE.
        CLEAR lt_vchar.
        lt_vchar-charact       = it_zarmcls-id.
        lt_vchar-value_char = lt_vchar-value_char_long  = it_zarmcls-value.
        lt_vchar-value_neutral = lt_vchar-value_neutral_long = it_zarmcls-value.
        APPEND lt_vchar.
      ENDIF.
    ENDLOOP.
*   post new batch classification assignment if values changed
    CHECK lt_vchar[] NE lt_vchar_old[].

    ADD 1 TO trans_called.
*{   REPLACE        R9SK901046                                        2
*\    CALL FUNCTION 'BAPI_OBJCL_CHANGE'
    CALL FUNCTION 'BAPI_OBJCL_CHANGE'                                 "#EC CI_USAGE_OK[2438131]
*}   REPLACE
      EXPORTING
        objectkey          = lk_objky
        objecttable        = 'MCH1'
        classnum           = 'Y0_FINISHED_GOODS'
        classtype          = '023'
      TABLES
        allocvaluesnumnew  = lt_vnum
        allocvaluescharnew = lt_vchar
        allocvaluescurrnew = lt_vcurr
        return             = lt_return.
*   check if ok
    LOOP AT lt_return TRANSPORTING NO FIELDS WHERE type CA 'EAX'.
      EXIT.
    ENDLOOP.
    IF sy-subrc NE 0. "no errors
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = 'X'.
      ADD 1 TO trans_ok.
*      Make sure entries are shown in BMBC
*      Without this part, there is a display bug, when using BMBC
      PERFORM bmbc_fix USING lt_mcha-matnr lt_mcha-charg.
*      Insert status
      PERFORM insert_status USING co_idoc_status_ok 'S' 'Y0PP_IDOCS' '025' lt_mcha-matnr lt_mcha-charg space space.
    ELSE.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
      LOOP AT lt_return WHERE type CA 'EAX'.
        PERFORM insert_status USING co_idoc_status_error lt_return-type lt_return-id lt_return-number
                                                         lt_return-message_v1 lt_return-message_v2 lt_return-message_v3 lt_return-message_v4.
      ENDLOOP.
      PERFORM insert_status USING co_idoc_status_error 'E' 'Y0PP_IDOCS' '026' lt_mcha-matnr lt_mcha-charg space space.
    ENDIF.
  ENDLOOP.
ENDFORM.                    " ZAREPBF_CLS_POST
*&---------------------------------------------------------------------*
*&      Form  Y0ATPDET_MAP_DD_MAT_PLT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM y0atpdet_map_dd_mat_plt.
  " Map DD materials and plant if necessary

  DATA: lv_index TYPE sy-index.
  " First check if logic must be applied
  SELECT SINGLE @abap_true FROM y0bc_idoc_dd_plt WHERE partyp = @idoc_contrl-rcvprt
                                                   AND parnum = @idoc_contrl-sndprn
                                                   AND mestyp = @idoc_contrl-mestyp
                                                 INTO @DATA(lv_map).

  " Message + Partner is relevant -> check/map iDoc content
  IF sy-subrc = 0.
    LOOP AT idoc_data.
      CASE idoc_data-segnam.
          " main segment - planned order
        WHEN 'Y0ATPDET'.
          wa_y0atpdet = idoc_data-sdata.

          " Material might be relevant for mapping (RB to DD)
*{   REPLACE        R9SK901046                                        1
*\          wa_y0atpdet-matnr = ycl_bc_idoc_functions=>map_material_rb_dd( EXPORTING iv_partyp = idoc_contrl-rcvprt
          wa_y0atpdet-matnr = ycl_bc_idoc_functions=>map_material18_rb_dd( EXPORTING iv_partyp = idoc_contrl-rcvprt
*}   REPLACE
                                                                                      iv_parnum = idoc_contrl-sndprn
                                                                                      iv_mestyp = idoc_contrl-mestyp
                                                                                      iv_date = CONV datum( wa_y0atpdet-gstrs )
                                                                                      iv_matnr_in = wa_y0atpdet-matnr ).
          " Plants might be relevant for mapping
          wa_y0atpdet-werks = ycl_bc_idoc_functions=>map_plant_in( EXPORTING iv_partyp = idoc_contrl-rcvprt
                                                                             iv_parnum = idoc_contrl-sndprn
                                                                             iv_mestyp = idoc_contrl-mestyp
                                                                             iv_date = CONV datum( wa_y0atpdet-gstrs )
                                                                             iv_werks_idoc = wa_y0atpdet-werks ).

          idoc_data-sdata = wa_y0atpdet.

          "update iDoc table
          MODIFY idoc_data.
      ENDCASE.
    ENDLOOP.
  ENDIF.
ENDFORM.

*&---------------------------------------------------------------------*
*& Form handle_bapi_return
*&---------------------------------------------------------------------*
FORM handle_bapi_return USING is_return TYPE bapiret2
                              iv_type   TYPE char2
                              iv_matnr  TYPE matnr
                              iv_v2     TYPE any
                              iv_v3     TYPE any.

  IF is_return-type CA 'EA'. "Error or Abort
    idoc_status-status = co_idoc_status_error.
    PERFORM insert_status USING idoc_status-status
                                is_return-type
                                is_return-id
                                is_return-number
                                is_return-message_v1
                                is_return-message_v2
                                is_return-message_v3
                                is_return-message_v4.
    CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
  ELSE.
    idoc_status-status = co_idoc_status_ok.
    ADD 1 TO trans_ok.

    DATA(lv_msgno) = COND #( WHEN iv_type = 'WA' THEN '021' ELSE '020' ).

    PERFORM insert_status USING idoc_status-status
                                'I' co_msgid lv_msgno
                                iv_matnr
                                iv_v2
                                iv_v3
                                space.

    PERFORM insert_status USING idoc_status-status
                                is_return-type
                                is_return-id
                                is_return-number
                                is_return-message_v1
                                is_return-message_v2
                                is_return-message_v3
                                is_return-message_v4.

    CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
      EXPORTING
        wait = 'X'.

    PERFORM create_link USING is_return-type is_return-id
                              is_return-number
                              idoc_contrl-docnum idoc_contrl-sndprn.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form map_header_text_bapi
*&---------------------------------------------------------------------*
FORM map_header_text_bapi USING us_zarmmts TYPE zarmmts
                                us_type    TYPE char2
                          CHANGING cv_bktxt TYPE bapi_rm_datgen-header_txt.

  DATA: h_bktxt TYPE rm61b-bktxt.

  IF us_type = 'WE'.
    IF gs_zatpde_cust-plo_2_htext_gr EQ abap_true.
      h_bktxt = |{ us_zarmmts-planorder }|.
    ELSE.
      h_bktxt = us_zarmmts-batch.
    ENDIF.

    " header text special logic for STI (planned order number)
    DATA(ls_svpo_buf) = VALUE #( gt_svpo_buf[ matnr = us_zarmmts-material_long
                                              werks = us_zarmmts-prodplant
                                              ponum = 'P' ] OPTIONAL ).
    IF ls_svpo_buf IS NOT INITIAL.
      h_bktxt = us_zarmmts-planorder.
    ENDIF.

    IF gs_zatpde_cust-pdc_2_grgi_slip EQ abap_true
      AND us_zarmmts-pdc_number IS NOT INITIAL
      AND us_zarmmts-docheadertxt IS INITIAL.
      h_bktxt = |{ h_bktxt } { '/PD' } { us_zarmmts-pdc_number(10) }|.
      CONDENSE h_bktxt NO-GAPS.
    ELSE.
      IF us_zarmmts-docheadertxt IS NOT INITIAL.
        h_bktxt = |{ h_bktxt } { us_zarmmts-docheadertxt }|.
      ENDIF.
    ENDIF.
  ENDIF.

  IF us_type = 'WA'.
    IF us_zarmmts-docheadertxt IS NOT INITIAL.
      h_bktxt = |{ us_zarmmts-y0_hcharg } { us_zarmmts-docheadertxt }|.
    ELSE.
      IF gs_zatpde_cust-plo_2_htext_gi EQ abap_true.
        h_bktxt = |{ us_zarmmts-planorder }|.
      ELSE.
        h_bktxt = |{ us_zarmmts-y0_hcharg }|.
      ENDIF.
      IF gs_zatpde_cust-pdc_2_grgi_slip EQ abap_true
        AND us_zarmmts-pdc_number IS NOT INITIAL.
        h_bktxt = |{ h_bktxt } { '/PD' } { us_zarmmts-pdc_number(10) }|.
        CONDENSE h_bktxt NO-GAPS.
      ENDIF.
    ENDIF.
  ENDIF.

  cv_bktxt = h_bktxt.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form map_prod_version_bapi
*&---------------------------------------------------------------------*
FORM map_prod_version_bapi USING us_zarmmts TYPE zarmmts
                           CHANGING cv_verid TYPE verid
                                    cv_plnum TYPE bapi_rm_datgen-planned_or.

  IF line_exists( gt_plaf_buf[ plnum = us_zarmmts-planorder ] ).
    cv_plnum = us_zarmmts-planorder.
  ELSE.
    DATA(lt_mkal_filtered) = FILTER #( gt_mkal_buf USING KEY matnr_werks
                                       WHERE matnr = us_zarmmts-y0_hmat_long
                                         AND werks = us_zarmmts-prodplant ).
    DELETE lt_mkal_filtered WHERE adatu > us_zarmmts-postdate.

    IF lines( lt_mkal_filtered ) EQ 1.
       "OK, will be determined by BAPI based on matnr/plant if single version
    ELSEIF lines( lt_mkal_filtered ) > 1.
      DATA(ls_mseg_buf) = VALUE #( gt_mseg_buf[ matnr = us_zarmmts-y0_hmat_long
                                                werks = us_zarmmts-prodplant
                                                charg = us_zarmmts-planorder+2 ] OPTIONAL ).
      IF ls_mseg_buf IS NOT INITIAL.
        cv_verid = VALUE #( gt_ckmlmv013_buf[ aufnr = ls_mseg_buf-aufnr ]-verid OPTIONAL ).
      ENDIF.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  ZAREPBF_ADD_FILLING_PLANT
*&---------------------------------------------------------------------*
*       Add Filling Plant to assigned class
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM zarepbf_add_filling_plant .

  DATA: ls_zarmmts LIKE wa_zarmmts.

*  Check if y0_posttype = WE, if so, it_we is not initial
*  also check if it_zarmcls is not empty
  IF  it_we IS NOT INITIAL AND it_zarmcls IS NOT INITIAL.

*    Validate if to be added  characteristic Y0_FILL_PLANT is actually really part of the class
    PERFORM check_characteristic_existance USING 'Y0_FINISHED_GOODS' '023' 'Y0_FILLING_PLANT'
                                            CHANGING sy-subrc.

    IF sy-subrc = 0 AND line_exists( idoc_data[ segnam = co_zarmmts ] ).
      ls_zarmmts = idoc_data[ segnam = co_zarmmts ]-sdata.
*      Determine correct filling plant

      DATA(ls_fill_p_local) = VALUE #( gt_fill_plant_buf[ werks_prod = ls_zarmmts-prodplant ] OPTIONAL ).

      IF ls_fill_p_local IS NOT INITIAL AND line_exists( it_zarmcls[ 1 ] ).
        APPEND INITIAL LINE TO it_zarmcls ASSIGNING FIELD-SYMBOL(<fs_zarmcls>).
        MOVE-CORRESPONDING it_zarmcls[ 1 ] TO <fs_zarmcls>.
        <fs_zarmcls>-id = 'Y0_FILLING_PLANT'.
        <fs_zarmcls>-value = ls_fill_p_local-werks_fill.
      ENDIF.

    ENDIF.

  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  BMBC_FIX
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LT_MCHA_MATNR  text
*      -->P_LT_MCHA_CHARG  text
*----------------------------------------------------------------------*
FORM bmbc_fix  USING    p_mcha_matnr
                        p_mcha_charg.

  DATA: lt_bdc_data TYPE TABLE OF bdcdata,
        lv_modus(1),
        lt_msg      TYPE TABLE OF bdcmsgcoll.

  lt_bdc_data = VALUE #( BASE lt_bdc_data ( program = 'SAPLCHRG' dynpro = '1000' dynbegin = 'X' ) ).
  lt_bdc_data = VALUE #( BASE lt_bdc_data ( fnam = 'DFBATCH-MATNR' fval = p_mcha_matnr ) ).
  lt_bdc_data = VALUE #( BASE lt_bdc_data ( fnam = 'DFBATCH-CHARG' fval = p_mcha_charg ) ).
  lt_bdc_data = VALUE #( BASE lt_bdc_data ( fnam = 'BDC_OKCODE' fval = '=ENTR' ) ).
  lt_bdc_data = VALUE #( BASE lt_bdc_data ( program = 'SAPLCHRG' dynpro = '1000' dynbegin = 'X' ) ).
  lt_bdc_data = VALUE #( BASE lt_bdc_data ( fnam = 'BDC_OKCODE' fval = '=SAVE' ) ).

  lv_modus = 'N'.

  CALL TRANSACTION 'MSC2N'
      USING lt_bdc_data
      MODE lv_modus
      MESSAGES INTO lt_msg.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form check_posting_plant
*&---------------------------------------------------------------------*
*& text
*&---------------------------------------------------------------------*
*&      --> IT_WE
*&      --> IT_RE
*&      --> IT_WA
*&---------------------------------------------------------------------*
FORM check_posting_plant  TABLES p_it_we STRUCTURE it_zarmmts
                                 p_it_re STRUCTURE it_zarmmts
                                 p_it_wa STRUCTURE it_zarmmts.

  DATA: lt_plaf TYPE TABLE OF plaf,
        lt_mseg TYPE TABLE OF mseg.
  CLEAR: lt_plaf, lt_mseg.

  " Get the planned order infos + already posted GRs if existing
  IF p_it_we IS NOT INITIAL.
    SELECT plnum, pwwrk FROM plaf
                        FOR ALL ENTRIES IN @p_it_we
                        WHERE plnum = @p_it_we-planorder
                        APPENDING CORRESPONDING FIELDS OF TABLE @lt_plaf.

    SELECT matnr, werks, charg FROM mseg
                               FOR ALL ENTRIES IN @p_it_we
                               WHERE matnr = @p_it_we-y0_hmat_long
                                 AND charg = @p_it_we-y0_hcharg
                                 AND bwart = '131' "GR for production
                               APPENDING CORRESPONDING FIELDS OF TABLE @lt_mseg.
  ENDIF.
  IF p_it_re IS NOT INITIAL.
    SELECT plnum, pwwrk FROM plaf
                        FOR ALL ENTRIES IN @p_it_re
                        WHERE plnum = @p_it_re-planorder
                        APPENDING CORRESPONDING FIELDS OF TABLE @lt_plaf.

    SELECT matnr, werks, charg FROM mseg
                         FOR ALL ENTRIES IN @p_it_re
                         WHERE matnr = @p_it_re-y0_hmat_long
                           AND charg = @p_it_re-y0_hcharg
                           AND bwart = '131' "GR for production
                         APPENDING CORRESPONDING FIELDS OF TABLE @lt_mseg.
  ENDIF.
  IF p_it_wa IS NOT INITIAL.
    SELECT plnum, pwwrk FROM plaf
                        FOR ALL ENTRIES IN @p_it_wa
                        WHERE plnum = @p_it_wa-planorder
                        APPENDING CORRESPONDING FIELDS OF TABLE @lt_plaf.

    SELECT matnr, werks, charg FROM mseg
                               FOR ALL ENTRIES IN @p_it_wa
                               WHERE matnr = @p_it_wa-y0_hmat_long
                                 AND charg = @p_it_wa-y0_hcharg
                                 AND bwart = '131' "GR for production
                               APPENDING CORRESPONDING FIELDS OF TABLE @lt_mseg.
  ENDIF.

  " Now compare plants for all postings
  LOOP AT p_it_we INTO DATA(wa_zarmmts).
    "first check on planned order
    READ TABLE lt_plaf INTO DATA(wa_plaf) WITH KEY plnum = wa_zarmmts-planorder.
    IF sy-subrc = 0.
      IF wa_plaf-pwwrk <> wa_zarmmts-prodplant.
        repbf_code = 4.
        PERFORM insert_status USING co_idoc_status_error 'E' 'Y0PP_IDOCS' '028' wa_zarmmts-prodplant wa_plaf-pwwrk wa_plaf-plnum space.
      ENDIF.
    ELSE.
      "if no planned order exists (anymore) check on header GR doc.
      READ TABLE lt_mseg INTO DATA(wa_mseg) WITH KEY matnr = wa_zarmmts-y0_hmat_long
                                                     charg = wa_zarmmts-y0_hcharg.
      IF sy-subrc = 0.
        IF wa_mseg-werks <> wa_zarmmts-prodplant.
          repbf_code = 4.
          PERFORM insert_status USING co_idoc_status_error 'E' 'Y0PP_IDOCS' '029' wa_zarmmts-prodplant wa_mseg-werks space space.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDLOOP.
  LOOP AT p_it_re INTO wa_zarmmts.
    "first check on planned order
    READ TABLE lt_plaf INTO wa_plaf WITH KEY plnum = wa_zarmmts-planorder.
    IF sy-subrc = 0.
      IF wa_plaf-pwwrk <> wa_zarmmts-prodplant.
        repbf_code = 4.
        PERFORM insert_status USING co_idoc_status_error 'E' 'Y0PP_IDOCS' '028' wa_zarmmts-prodplant wa_plaf-pwwrk wa_plaf-plnum space.
      ENDIF.
    ELSE.
      "if no planned order exists (anymore) check on header GR doc.
      READ TABLE lt_mseg INTO wa_mseg WITH KEY matnr = wa_zarmmts-y0_hmat_long
                                               charg = wa_zarmmts-y0_hcharg.
      IF sy-subrc = 0.
        IF wa_mseg-werks <> wa_zarmmts-prodplant.
          repbf_code = 4.
          PERFORM insert_status USING co_idoc_status_error 'E' 'Y0PP_IDOCS' '029' wa_zarmmts-prodplant wa_mseg-werks space space.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDLOOP.
  LOOP AT p_it_wa INTO wa_zarmmts.
    "first check on planned order
    READ TABLE lt_plaf INTO wa_plaf WITH KEY plnum = wa_zarmmts-planorder.
    IF sy-subrc = 0.
      IF wa_plaf-pwwrk <> wa_zarmmts-prodplant.
        repbf_code = 4.
        PERFORM insert_status USING co_idoc_status_error 'E' 'Y0PP_IDOCS' '028' wa_zarmmts-prodplant wa_plaf-pwwrk wa_plaf-plnum space.
      ENDIF.
    ELSE.
      "if no planned order exists (anymore) check on header GR doc.
      READ TABLE lt_mseg INTO wa_mseg WITH KEY matnr = wa_zarmmts-y0_hmat_long
                                               charg = wa_zarmmts-y0_hcharg.
      IF sy-subrc = 0.
        IF wa_mseg-werks <> wa_zarmmts-prodplant.
          repbf_code = 4.
          PERFORM insert_status USING co_idoc_status_error 'E' 'Y0PP_IDOCS' '029' wa_zarmmts-prodplant wa_mseg-werks space space.
        ENDIF.
      ENDIF.
    ENDIF.
  ENDLOOP.


ENDFORM.
*&---------------------------------------------------------------------*
*& Form y0atpdet_reservation_delete
*&---------------------------------------------------------------------*
FORM y0atpdet_reservation_delete.
  DATA: lt_return TYPE TABLE OF bapiret2.
  CLEAR: lt_return.

  CHECK atpdet_code = 0.

  IF NOT it_y0sd_zatpde_werk[] IS INITIAL.
*    get relevant reservations for deletion
    LOOP AT it_nrange INTO wa_nrange.
      SELECT rsnum FROM resb
                   FOR ALL ENTRIES IN @it_y0sd_zatpde_werk
                   WHERE wempf BETWEEN @wa_nrange-nrfrom AND @wa_nrange-nrto
                     AND werks = @it_y0sd_zatpde_werk-werks
                   INTO TABLE @DATA(lt_resb_del).
    ENDLOOP.
  ENDIF.

  LOOP AT lt_resb_del INTO DATA(ls_resb_del).
    CALL FUNCTION 'BAPI_RESERVATION_DELETE'
      EXPORTING
        reservation = ls_resb_del-rsnum
*       TESTRUN     =
      TABLES
        return      = lt_return.

    READ TABLE lt_return INTO DATA(ls_return) WITH KEY type = 'E'.
    IF sy-subrc = 0.
      PERFORM insert_message USING ls_return-type
                                   ls_return-id
                                   ls_return-number
                                   ls_return-message_v1
                                   ls_return-message_v2
                                   ls_return-message_v3
                                   ls_return-message_v4.

      atpdet_code = 3.
      EXIT.
    ENDIF.
  ENDLOOP.

  "at least one reservation was deleted
  IF sy-subrc = 0.
    IF atpdet_code = 0.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
        EXPORTING
          wait = 'X'.

    ELSE. "error -> rollback
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*& Form y0atpdet_reservation_create
*&---------------------------------------------------------------------*
FORM y0atpdet_reservation_create.
  DATA: ls_resb_header TYPE  bapi2093_res_head,
        lt_resb_items  TYPE TABLE OF  bapi2093_res_item,
        lt_prof_seg    TYPE TABLE OF bapi_profitability_segment,
        lv_reservation TYPE bapi2093_res_key-reserv_no,
        lt_return      TYPE TABLE OF bapiret2.

  DATA: lv_requ_qty TYPE bdmng.

  "Sometimes the planned orders are already reduced as FERT already received
  "-> this reduced the CFR requirement accordingly causes missing requirements for the not-yet received consumption postings
  "therefore we create reservation for the difference between our current planned order requ. and the actual open requ. received from Rauch

  "do we have open requirements?
  CHECK gt_atpresb IS NOT INITIAL.

  "1. get all relevant CFR demands for planned order
  SELECT rsnum, plnum, bdter, matnr, bdmng, enmng, meins
         FROM resb
         FOR ALL ENTRIES IN @gt_atpresb
         WHERE plnum = @gt_atpresb-plnum
           AND matnr = @gt_atpresb-matnr
           AND xloek = ''
         INTO TABLE @DATA(lt_resb_plaf).

  "2. now go through open demands from Rauch
  " -> the difference between RB demand and RF demand must be created as reservation
  LOOP AT gt_atpresb INTO DATA(ls_atpresb).
    CLEAR: ls_resb_header, lt_resb_items, lv_requ_qty.

    "total open requirement (based on RF data)
    lv_requ_qty = ls_atpresb-bdmng - ls_atpresb-enmng. "required - already withdrawn qty

    "current requirement based on planned order
    READ TABLE lt_resb_plaf INTO DATA(ls_resb_plaf) WITH KEY plnum = ls_atpresb-plnum.

    "deduct the total requ. by the planned order requ. -> this quantity needs to be entered as reservation
    lv_requ_qty = lv_requ_qty - ( ls_resb_plaf-bdmng - ls_resb_plaf-enmng ). "there shouldn't be a withdrawn qty but better consider

    CHECK lv_requ_qty > 0.

    ls_resb_header-move_plant = ls_atpresb-werks.
    ls_resb_header-move_type = '261'. "prod. consumption

    APPEND VALUE bapi2093_res_item( material_long = ls_atpresb-matnr
                                    plant = ls_atpresb-werks
                                    entry_qnt = lv_requ_qty
                                    entry_uom = ls_atpresb-meins
                                    req_date = SWITCH bdter( ls_resb_plaf-bdter WHEN '00000000' THEN ls_atpresb-bdter
                                                                                WHEN '' THEN ls_atpresb-bdter
                                                                                ELSE ls_resb_plaf-bdter )
                                    gr_rcpt = ls_atpresb-plnum ) TO lt_resb_items.
    CLEAR: lt_return, lv_reservation.
    CALL FUNCTION 'BAPI_RESERVATION_CREATE1'
      EXPORTING
        reservationheader    = ls_resb_header
*       TESTRUN              =
      IMPORTING
        reservation          = lv_reservation
      TABLES
        reservationitems     = lt_resb_items
        profitabilitysegment = lt_prof_seg
        return               = lt_return.

    READ TABLE lt_return INTO DATA(ls_return) WITH KEY type = 'E'.
    IF sy-subrc = 0.
      PERFORM insert_message USING ls_return-type
                                   ls_return-id
                                   ls_return-number
                                   ls_return-message_v1
                                   ls_return-message_v2
                                   ls_return-message_v3
                                   ls_return-message_v4.

      atpdet_code = 3.
      CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.
    ELSE.
      CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'.
    ENDIF.

  ENDLOOP.


ENDFORM.
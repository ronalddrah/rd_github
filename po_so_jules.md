*&---------------------------------------------------------------------*
*& Report YUSCA_PO_SO_MAINTAIN
*&---------------------------------------------------------------------*
*& Custom mass update report for Sales Orders and Purchase Orders
*&---------------------------------------------------------------------*
REPORT yusca_po_so_maintain.

TABLES: ekko, ekpo, vbak, vbap, eket, sscrfields.

" --- Selection Screen ---
SELECTION-SCREEN BEGIN OF BLOCK b_po WITH FRAME TITLE TEXT-b01.
  PARAMETERS pa_po RADIOBUTTON GROUP opt DEFAULT 'X'.
  SELECT-OPTIONS:
    s_ebeln FOR ekko-ebeln,          "
    s_aedat FOR ekko-aedat,          "
    s_pwerk FOR ekpo-werks,          "
    s_lifnr FOR ekko-lifnr,          "
    s_pmatn FOR ekpo-matnr,          "
    s_lprio FOR ekpo-lprio,          "
    s_ekorg FOR ekko-ekorg,
    s_eindt FOR eket-eindt.          "

  SELECTION-SCREEN SKIP.

  PARAMETERS: pa_so RADIOBUTTON GROUP opt.
  SELECT-OPTIONS:
    s_vbeln FOR vbak-vbeln,          "
    s_vkorg FOR vbak-vkorg,          "
    s_erdat FOR vbak-erdat,          "
    s_kunnr FOR vbak-kunnr,          "
    s_kunwe FOR vbap-kunwe_ana,      "
    s_swerk FOR vbap-werks,          "
    s_smatn FOR vbap-matnr,
    s_vdatu FOR vbak-vdatu.          "

SELECTION-SCREEN END OF BLOCK b_po.

SELECTION-SCREEN BEGIN OF BLOCK b_gen WITH FRAME TITLE TEXT-b03.
  PARAMETERS: pa_prio RADIOBUTTON GROUP sel DEFAULT 'X',
              pa_deld RADIOBUTTON GROUP sel,
              pa_dele RADIOBUTTON GROUP sel,
              pa_roll RADIOBUTTON GROUP sel.
  PARAMETERS  pa_user LIKE sy-uname.
  SELECTION-SCREEN SKIP.
  PARAMETERS: pa_sim AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b_gen.

SELECTION-SCREEN FUNCTION KEY 1. " For Rollback feature

"INITIALIZATION.
"  sscrfields-functxt_01 = 'Rollback prior run'.

" --- Data Types ---
TYPES: BEGIN OF ty_alv_data,
         ebeln      TYPE ekko-ebeln,
         ebelp      TYPE ekpo-ebelp,
         vbeln      TYPE vbak-vbeln,
         posnr      TYPE vbap-posnr,
         lprio      TYPE vbap-lprio,      " Delivery Priority (used for both)
         eindt      TYPE eket-eindt,      " PO Delivery Date
         vdatu      TYPE vbak-vdatu,      " SO Delivery Date
         abgru      TYPE vbap-abgru,      " Reason for Rejection (SO)
         loekz      TYPE ekpo-loekz,      " Deletion Indicator (PO)
         lprio_old  TYPE vbap-lprio,
         eindt_old  TYPE eket-eindt,
         vdatu_old  TYPE vbak-vdatu,
         abgru_old  TYPE vbap-abgru,
         loekz_old  TYPE ekpo-loekz,
         matnr      TYPE matnr,
         werks      TYPE werks_d,
         vkorg      TYPE vkorg,
         status     TYPE icon_d,
         message    TYPE string,
         cell_style TYPE lvc_t_styl,
         upd_type   TYPE yus_ca_upd_type,
       END OF ty_alv_data.

DATA: g_upd_date TYPE sy-datum,
      g_upd_time TYPE sy-uzeit.

" --- Local Class Definition ---
CLASS lcl_mass_update DEFINITION.
  PUBLIC SECTION.
    METHODS:
      main,
      select_data,
      init_alv,
      handle_toolbar FOR EVENT toolbar OF cl_gui_alv_grid
        IMPORTING e_object e_interactive,
      handle_user_command FOR EVENT user_command OF cl_gui_alv_grid
        IMPORTING e_ucomm,
      handle_data_changed FOR EVENT data_changed OF cl_gui_alv_grid
        IMPORTING er_data_changed,
      execute_updates,
      rollback.

  PRIVATE SECTION.
    DATA: gt_alv_data  TYPE TABLE OF ty_alv_data,
          go_alv       TYPE REF TO cl_gui_alv_grid,
          go_container TYPE REF TO cl_gui_custom_container.

    METHODS:
      prepare_fieldcatalog CHANGING ct_fcat TYPE lvc_t_fcat,
      mass_copy_down,
      save_log IMPORTING is_data TYPE yusca_po_so_log.  "table.

ENDCLASS.

" --- Local Class Implementation ---
CLASS lcl_mass_update IMPLEMENTATION.
  METHOD main.
    IF pa_roll IS INITIAL.
      select_data( ).
    ELSE.
      rollback( ).
    ENDIF.


    IF gt_alv_data IS INITIAL.
      MESSAGE 'No data found' TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    " create Screen 100 in SE51
    " and call it here to host the ALV grid and handle the lifecycle.
    " Currently only simulate the call.
    init_alv( ).

    " To keep the ALV active in a report without a custom screen:
    IF sy-batch IS INITIAL.
      WRITE: / 'ALV Displayed. Process complete.'.
    ENDIF.
  ENDMETHOD.

  METHOD select_data.

    IF pa_po = abap_true.
      IF pa_dele IS INITIAL.
        SELECT ebeln, ebelp, lprio, matnr, werks, loekz,
               lprio AS lprio_old, loekz AS loekz_old, eindt AS eindt_old
          FROM y0sd_v_po_data
          INTO CORRESPONDING FIELDS OF TABLE @gt_alv_data
          WHERE ebeln IN @s_ebeln
            AND aedat IN @s_aedat
            AND werks IN @s_pwerk
            AND lifnr IN @s_lifnr
            AND matnr IN @s_pmatn
            AND lprio IN @s_lprio
            AND ekorg IN @s_ekorg
            AND eindt IN @s_eindt
            AND loekz EQ @abap_false.
      ELSE.
        SELECT ebeln, ebelp, lprio, matnr, werks, loekz,
               lprio AS lprio_old, loekz AS loekz_old, eindt AS eindt_old
          FROM y0sd_v_po_data
          INTO CORRESPONDING FIELDS OF TABLE @gt_alv_data
          WHERE ebeln IN @s_ebeln
            AND aedat IN @s_aedat
            AND werks IN @s_pwerk
            AND lifnr IN @s_lifnr
            AND matnr IN @s_pmatn
            AND lprio IN @s_lprio
            AND ekorg IN @s_ekorg
            AND eindt IN @s_eindt.
      ENDIF.

    ELSEIF pa_so = abap_true.
      SELECT vbeln, posnr, lprio, matnr, werks, abgru, vdatu,
             lprio AS lprio_old, abgru AS abgru_old, vdatu AS vdatu_old
        FROM y0sd_sales_order_data
        INTO CORRESPONDING FIELDS OF TABLE @gt_alv_data
        WHERE vbeln IN @s_vbeln
          AND vkorg IN @s_vkorg
          AND erdat IN @s_erdat
          AND kunnr IN @s_kunnr
          AND kunwe_ana IN @s_kunwe
          AND werks IN @s_swerk
          AND matnr IN @s_smatn
          AND vdatu IN @s_vdatu.

    ENDIF.
  ENDMETHOD.

  METHOD init_alv.
    DATA: lt_fcat   TYPE lvc_t_fcat,
          ls_layout TYPE lvc_s_layo.

    IF go_alv IS INITIAL.
      " Using generic display if no container specified by environment
      " we might use a custom container on a screen
      " For this report, we can use the full screen
      CREATE OBJECT go_alv
        EXPORTING
          i_parent = cl_gui_container=>screen0.

      prepare_fieldcatalog( CHANGING ct_fcat = lt_fcat ).
      ls_layout-stylefname = 'CELL_STYLE'.
      ls_layout-sel_mode = 'A'.

      SET HANDLER handle_toolbar FOR go_alv.
      SET HANDLER handle_user_command FOR go_alv.
      SET HANDLER handle_data_changed FOR go_alv.

      go_alv->set_table_for_first_display(
        EXPORTING
          is_layout       = ls_layout
        CHANGING
          it_outtab       = gt_alv_data
          it_fieldcatalog = lt_fcat ).
    ELSE.
      go_alv->refresh_table_display( ).
    ENDIF.

    WRITE: 'ALV Initialized'. " Dummy for background execution if needed
  ENDMETHOD.

  METHOD handle_toolbar.
    DATA ls_button TYPE stb_button.

    IF pa_roll IS INITIAL.
      CLEAR ls_button.
      ls_button-function  = 'COPY_DOWN'.
      ls_button-icon      = icon_copy_object.
      ls_button-text      = 'Mass Copy-Down'.
      ls_button-quickinfo = 'Copy first row value to all other rows'.
      INSERT ls_button INTO TABLE e_object->mt_toolbar.
    ENDIF.

    CLEAR ls_button.
    ls_button-function = 'EXEC_UPDATE'.
    ls_button-icon     = icon_execute_object.
    ls_button-text     = 'Execute Update'.
    INSERT ls_button INTO TABLE e_object->mt_toolbar.
  ENDMETHOD.

  METHOD handle_user_command.
    CASE e_ucomm.
      WHEN 'COPY_DOWN'.
        mass_copy_down( ).
      WHEN 'EXEC_UPDATE'.
        execute_updates( ).
    ENDCASE.
  ENDMETHOD.

  METHOD handle_data_changed.
    " Implementation of inline validation
    LOOP AT er_data_changed->mt_good_cells INTO DATA(ls_cell).
      CASE ls_cell-fieldname.
        WHEN 'LPRIO'.
          " Example: Check if priority is within range
          IF ls_cell-value < '00' OR ls_cell-value > '99'.
            er_data_changed->add_protocol_entry(
              i_fieldname = ls_cell-fieldname
              i_row_id    = ls_cell-row_id
              i_msgid     = '00'
              i_msgno     = '001'
              i_msgty     = 'E'
              i_msgv1     = 'Invalid Priority' ).
          ENDIF.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

  METHOD execute_updates.
    DATA lt_return    TYPE TABLE OF bapiret2.
    DATA ls_header    TYPE bapisdh1.
    DATA ls_headerx   TYPE bapisdh1x.
    DATA lt_item      TYPE TABLE OF bapisditm.
    DATA lt_itemx     TYPE TABLE OF bapisditmx.
    DATA lt_so_sched  TYPE TABLE OF bapischdl.
    DATA lt_so_schedx TYPE TABLE OF bapischdlx.
    DATA lt_po_item   TYPE TABLE OF bapimepoitem.
    DATA lt_po_itemx  TYPE TABLE OF bapimepoitemx.
    DATA lt_po_sched  TYPE TABLE OF bapimeposchedule.
    DATA lt_po_schedx TYPE TABLE OF bapimeposchedulx.
    DATA lt_po_ship   TYPE TABLE OF bapiitemship.
    DATA lt_po_shipx  TYPE TABLE OF bapiitemshipx.
    DATA ls_save      TYPE yusca_po_so_log.

    IF pa_roll = abap_true.
      IF gt_alv_data[ 1 ]-vbeln IS NOT INITIAL.
        pa_so = abap_true.
        pa_po = abap_false.
      ELSE.
        pa_so = abap_false.
        pa_po = abap_true.
      ENDIF.

      IF gt_alv_data[ 1 ]-upd_type = space.
        "regular run
      ELSEIF gt_alv_data[ 1 ]-upd_type = '1'.
        pa_prio = abap_true.
        pa_deld = pa_dele = abap_false.
      ELSEIF gt_alv_data[ 1 ]-upd_type = '2'.
        pa_deld = abap_true.
        pa_prio = pa_dele = abap_false.
      ELSE.
        pa_dele = abap_true.
        pa_prio = pa_deld = abap_false.
      ENDIF.
    ENDIF.

    g_upd_date = sy-datum. g_upd_time = sy-uzeit.


    LOOP AT gt_alv_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      REFRESH lt_return.
      IF pa_so = abap_true.
        " Sales Order Update
        CLEAR: ls_header,
               ls_headerx.
        REFRESH: lt_item, lt_itemx, lt_so_sched, lt_so_schedx.

        IF pa_prio = abap_true.
          ls_headerx-updateflag = 'U'.
          APPEND VALUE #( itm_number = <ls_data>-posnr
                          dlv_prio   = <ls_data>-lprio ) TO lt_item.
          APPEND VALUE #( itm_number = <ls_data>-posnr
                          updateflag   = 'U'
                          dlv_prio   = 'X' ) TO lt_itemx.
          ls_headerx-updateflag = 'U'.
        ELSEIF pa_deld = abap_true.
          ls_header-req_date_h = <ls_data>-vdatu.
          ls_headerx-req_date_h = 'X'.
          ls_headerx-updateflag = 'U'.

          APPEND VALUE #( itm_number = <ls_data>-posnr
                          sched_line = '0001'         "always first line
                          REQ_DATE   = <ls_data>-vdatu ) TO lt_so_sched.
*"                          delv_date  = <ls_data>-vdatu ) TO lt_so_sched.
          APPEND VALUE #( itm_number = <ls_data>-posnr
                          sched_line = '0001'
                          updateflag   = 'U'
                          REQ_DATE   = 'X' ) TO lt_so_schedx.

        ELSEIF pa_dele = abap_true.
          ls_headerx-updateflag = 'U'.
          APPEND VALUE #( itm_number = <ls_data>-posnr
                          reason_rej = <ls_data>-abgru ) TO lt_item.
          APPEND VALUE #( itm_number = <ls_data>-posnr
                          updateflag   = 'U'
                          reason_rej = 'X' ) TO lt_itemx.
        ENDIF.

        CALL FUNCTION 'BAPI_SALESORDER_CHANGE'
          EXPORTING
            salesdocument    = <ls_data>-vbeln
            order_header_in  = ls_header
            order_header_inx = ls_headerx
          TABLES
            return           = lt_return
            order_item_in    = lt_item
            order_item_inx   = lt_itemx
            schedule_lines   = lt_so_sched
            schedule_linesx  = lt_so_schedx.

      ELSEIF pa_po = abap_true.
        " Purchase Order Update
        REFRESH: lt_po_item, lt_po_itemx, lt_po_sched, lt_po_schedx, lt_po_ship, lt_po_shipx.

        IF pa_prio = abap_true.
          APPEND VALUE #( po_item = <ls_data>-ebelp ) TO lt_po_item.
          APPEND VALUE #( po_item = <ls_data>-ebelp ) TO lt_po_itemx.
          APPEND VALUE #( po_item  = <ls_data>-ebelp
                          dlv_prio = <ls_data>-lprio ) TO lt_po_ship.
          APPEND VALUE #( po_item  = <ls_data>-ebelp
                          dlv_prio = 'X' ) TO lt_po_shipx.
        ELSEIF pa_deld = abap_true.
          " Fetch all schedule lines for the item to ensure full coverage
          SELECT etenr FROM eket
            WHERE ebeln = @<ls_data>-ebeln
              AND ebelp = @<ls_data>-ebelp
            INTO TABLE @DATA(lt_eket_lines).

          LOOP AT lt_eket_lines INTO DATA(ls_eket).
            APPEND VALUE #( po_item       = <ls_data>-ebelp
                            sched_line    = ls_eket-etenr
                            delivery_date = <ls_data>-eindt ) TO lt_po_sched.
            APPEND VALUE #( po_item       = <ls_data>-ebelp
                            sched_line    = ls_eket-etenr
                            delivery_date = 'X' ) TO lt_po_schedx.
          ENDLOOP.

          IF lt_eket_lines IS INITIAL. " Fallback to first line
            APPEND VALUE #( po_item       = <ls_data>-ebelp
                            sched_line    = '0001'
                            delivery_date = <ls_data>-eindt ) TO lt_po_sched.
          ENDIF.
        ELSEIF pa_dele = abap_true.
          APPEND VALUE #( po_item    = <ls_data>-ebelp
                          delete_ind = <ls_data>-loekz ) TO lt_po_item.
          APPEND VALUE #( po_item    = <ls_data>-ebelp
                          delete_ind = 'X' ) TO lt_po_itemx.
        ENDIF.

        CALL FUNCTION 'BAPI_PO_CHANGE'
          EXPORTING
            purchaseorder = <ls_data>-ebeln
          TABLES
            return        = lt_return
            poitem        = lt_po_item
            poitemx       = lt_po_itemx
            poschedule    = lt_po_sched
            poschedulex   = lt_po_schedx
            poshipping    = lt_po_ship
            poshippingx   = lt_po_shipx.
      ENDIF.

      " Handle results
      IF line_exists( lt_return[ type = 'E' ] ).
        <ls_data>-status = icon_led_red.
        LOOP AT lt_return INTO DATA(ls_ret) WHERE type = 'E'.
          <ls_data>-message = <ls_data>-message && ls_ret-message.
        ENDLOOP.
      ELSE.
        IF pa_sim = abap_false.
          CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
            EXPORTING
              wait = abap_true.
          <ls_data>-status  = icon_led_green.
          <ls_data>-message = 'Success'.

          ls_save = CORRESPONDING #( <ls_data> ).
          save_log( is_data = ls_save ).
          " save_log( VALUE #( ( <ls_data> ) ) ).
        ELSE.
          <ls_data>-status  = icon_led_yellow.
          <ls_data>-message = 'Simulation successful'.
        ENDIF.
      ENDIF.
    ENDLOOP.

    go_alv->refresh_table_display( ).
  ENDMETHOD.

  METHOD rollback.
    " Implementation for functional revert capability
    SELECT * FROM yusca_po_so_log INTO TABLE @DATA(lt_log_entries)
             WHERE upd_user = @pa_user
             ORDER BY upd_date DESCENDING, upd_time DESCENDING.

    IF sy-subrc IS INITIAL.

      "only last run can be restored.
      DATA(l_last_date) = lt_log_entries[ 1 ]-upd_date.
      DATA(l_last_time) = lt_log_entries[ 1 ]-upd_time.
      DELETE lt_log_entries WHERE upd_date NE l_last_date.
      DELETE lt_log_entries WHERE upd_time NE l_last_time.

      LOOP AT lt_log_entries INTO DATA(ls_log_entry).
        APPEND INITIAL LINE TO gt_alv_data ASSIGNING FIELD-SYMBOL(<fs_alv_data>).
        <fs_alv_data> = CORRESPONDING #( ls_log_entry ).
        <fs_alv_data>-lprio = ls_log_entry-lprio_old.
        <fs_alv_data>-eindt = ls_log_entry-eindt_old.
        <fs_alv_data>-vdatu = ls_log_entry-vdatu_old.
        <fs_alv_data>-abgru = ls_log_entry-abgru_old.
        <fs_alv_data>-loekz = ls_log_entry-loekz_old.
        <fs_alv_data>-lprio_old = ls_log_entry-lprio.
        <fs_alv_data>-eindt_old = ls_log_entry-eindt.
        <fs_alv_data>-vdatu_old = ls_log_entry-vdatu.
        <fs_alv_data>-abgru_old = ls_log_entry-abgru.
        <fs_alv_data>-loekz_old = ls_log_entry-loekz.
      ENDLOOP.

      "      IF gt_alv_data IS INITIAL.
      "        MESSAGE 'Select records first to perform rollback on' TYPE 'E'.
      "        RETURN.
      "      ENDIF.

      "      LOOP AT gt_alv_data ASSIGNING FIELD-SYMBOL(<ls_data>).
      "        <ls_data>-lprio = <ls_data>-lprio_old.
      "        <ls_data>-vdatu = <ls_data>-vdatu_old.
      "        <ls_data>-abgru = <ls_data>-abgru_old.
      "        <ls_data>-loekz = <ls_data>-loekz_old.
      "        <ls_data>-eindt = <ls_data>-eindt_old.
      "      ENDLOOP.

      "      execute_updates( ).
      "      MESSAGE 'Rollback executed using persistent old values' TYPE 'S'.
    ELSE.
      MESSAGE 'No runs found for user.' TYPE 'I'.
    ENDIF.
  ENDMETHOD.

  METHOD prepare_fieldcatalog.
    DATA: ls_fcat      TYPE lvc_s_fcat,
          lv_structure TYPE dd02l-tabname.

    " LVC_FIELDCATALOG_MERGE is avoided for local types to prevent runtime errors.
    REFRESH ct_fcat.
    IF pa_po = abap_true.
      lv_structure = 'YUSSD_PO_OUTPUT_MASS'.
    ELSE.
      lv_structure = 'YUSSD_SO_OUTPUT_MASS'.
    ENDIF.

    CALL FUNCTION 'LVC_FIELDCATALOG_MERGE'
      EXPORTING
        i_structure_name       = lv_structure
      CHANGING
        ct_fieldcat            = ct_fcat
      EXCEPTIONS
        incomplete             = 1
        no_struct_name         = 2
        no_fieldcat_col_names  = 3
        register_interface_err = 4
        OTHERS                 = 5.

    " If merge failed (e.g. structure not created yet), manually define
    IF ct_fcat IS INITIAL.
      CLEAR ls_fcat.
      ls_fcat-fieldname = 'STATUS'. ls_fcat-scrtext_s = 'Status'. APPEND ls_fcat TO ct_fcat.

      IF pa_po = abap_true.
        CLEAR ls_fcat. ls_fcat-fieldname = 'EBELN'. ls_fcat-scrtext_s = 'PO No'. APPEND ls_fcat TO ct_fcat.
        CLEAR ls_fcat. ls_fcat-fieldname = 'EBELP'. ls_fcat-scrtext_s = 'Item'. APPEND ls_fcat TO ct_fcat.
      ELSE.
        CLEAR ls_fcat. ls_fcat-fieldname = 'VBELN'. ls_fcat-scrtext_s = 'SO No'. APPEND ls_fcat TO ct_fcat.
        CLEAR ls_fcat. ls_fcat-fieldname = 'POSNR'. ls_fcat-scrtext_s = 'Item'. APPEND ls_fcat TO ct_fcat.
      ENDIF.

      CLEAR ls_fcat. ls_fcat-fieldname = 'MATNR'. ls_fcat-scrtext_s = 'Material'. APPEND ls_fcat TO ct_fcat.
      CLEAR ls_fcat. ls_fcat-fieldname = 'WERKS'. ls_fcat-scrtext_s = 'Plant'. APPEND ls_fcat TO ct_fcat.

      " Editable fields based on update type
      CLEAR ls_fcat.
      CASE abap_true.
        WHEN pa_prio.
          ls_fcat-fieldname = 'LPRIO'. ls_fcat-scrtext_s = 'Priority'. ls_fcat-edit = abap_true.
          ls_fcat-f4availabl = abap_true.
        WHEN pa_deld.
          IF pa_po = abap_true.
            ls_fcat-fieldname = 'EINDT'. ls_fcat-scrtext_s = 'Deliv.Date'. ls_fcat-edit = abap_true.
          ELSE.
            ls_fcat-fieldname = 'VDATU'. ls_fcat-scrtext_s = 'Deliv.Date'. ls_fcat-edit = abap_true.
          ENDIF.
        WHEN pa_dele.
          IF pa_po = abap_true.
            ls_fcat-fieldname = 'LOEKZ'. ls_fcat-scrtext_s = 'Delete'. ls_fcat-edit = abap_true.
          ELSE.
            ls_fcat-fieldname = 'ABGRU'. ls_fcat-scrtext_s = 'Rejection'. ls_fcat-edit = abap_true.
          ENDIF.
      ENDCASE.
      APPEND ls_fcat TO ct_fcat.

      CLEAR ls_fcat. ls_fcat-fieldname = 'MESSAGE'. ls_fcat-scrtext_s = 'Message'. APPEND ls_fcat TO ct_fcat.
    ENDIF.

    " Enhance field catalog with F4 help and editability
    LOOP AT ct_fcat ASSIGNING FIELD-SYMBOL(<ls_fcat>).
      CASE <ls_fcat>-fieldname.
        WHEN 'LPRIO'.
          <ls_fcat>-edit = pa_prio.
          <ls_fcat>-ref_table = 'VBAP'.
          <ls_fcat>-ref_field = 'LPRIO'.
        WHEN 'ABGRU'.
          <ls_fcat>-edit = pa_dele.
          <ls_fcat>-ref_table = 'VBAP'.
          <ls_fcat>-ref_field = 'ABGRU'.
        WHEN 'VDATU'.
          <ls_fcat>-edit = pa_deld.
          <ls_fcat>-ref_table = 'VBAK'.
          <ls_fcat>-ref_field = 'VDATU'.
        WHEN 'EINDT'.
          <ls_fcat>-edit = pa_deld.
          <ls_fcat>-ref_table = 'EKET'.
          <ls_fcat>-ref_field = 'EINDT'.
        WHEN 'LOEKZ'.
          <ls_fcat>-edit = pa_dele.
      ENDCASE.
    ENDLOOP.

  ENDMETHOD.

  METHOD mass_copy_down.
    DATA: ls_first_row TYPE ty_alv_data.

    READ TABLE gt_alv_data INTO ls_first_row INDEX 1.
    IF sy-subrc <> 0. RETURN. ENDIF.

    LOOP AT gt_alv_data ASSIGNING FIELD-SYMBOL(<ls_data>) FROM 2.
      IF pa_prio = abap_true.
        <ls_data>-lprio = ls_first_row-lprio.
      ELSEIF pa_deld = abap_true.
        IF pa_po = abap_true.
          <ls_data>-eindt = ls_first_row-eindt.
        ELSE.
          <ls_data>-vdatu = ls_first_row-vdatu.
        ENDIF.
      ELSEIF pa_dele = abap_true.
        IF pa_po = abap_true.
          <ls_data>-loekz = ls_first_row-loekz.
        ELSE.
          <ls_data>-abgru = ls_first_row-abgru.
        ENDIF.
      ENDIF.
    ENDLOOP.

    go_alv->refresh_table_display( ).
  ENDMETHOD.

  METHOD save_log.
    " Persistent audit logging simulation
    DATA: ls_log TYPE yusca_po_so_log.
*    DATA: BEGIN OF ls_log,
*            doc_no     TYPE vbeln,
*            item_no    TYPE posnr,
*            field_name TYPE fieldname,
*            old_value  TYPE string,
*            new_value  TYPE string,
*            upd_date   TYPE dats,
*            upd_time   TYPE tims,
*            upd_user   TYPE sy-uname,
*          END OF ls_log.
    DATA: lt_log LIKE TABLE OF ls_log.

    ls_log = CORRESPONDING #( is_data ).

    IF pa_prio EQ abap_true.
      CLEAR: ls_log-abgru, ls_log-abgru_old,
             ls_log-eindt, ls_log-eindt_old,
             ls_log-loekz, ls_log-loekz_old,
             ls_log-vdatu, ls_log-vdatu_old.
    ELSEIF pa_deld EQ abap_true.
      CLEAR: ls_log-abgru, ls_log-abgru_old,
             ls_log-lprio, ls_log-lprio_old,
             ls_log-loekz, ls_log-loekz_old.

    ELSEIF pa_dele EQ abap_true.
      CLEAR: ls_log-lprio, ls_log-lprio_old,
             ls_log-eindt, ls_log-eindt_old,
             ls_log-vdatu, ls_log-vdatu_old.
    ENDIF.

    ls_log-upd_date  = g_upd_date.
    ls_log-upd_time  = g_upd_time.
    ls_log-upd_user  = sy-uname.

    IF pa_prio = abap_true.
      ls_log-upd_type = '1'.
    ELSEIF pa_deld = abap_true.
      ls_log-upd_type = '2'.
    ELSE.
      ls_log-upd_type = '3'.
    ENDIF.

    INSERT yusca_po_so_log FROM ls_log.

    " MESSAGE 'Audit log updated persistently' TYPE 'S'.
  ENDMETHOD.

ENDCLASS.

" --- Events ---

AT SELECTION-SCREEN.
  IF ( pa_prio IS NOT INITIAL OR pa_deld IS NOT INITIAL OR pa_deld IS NOT INITIAL ) AND
       pa_po IS NOT INITIAL.
    IF s_ebeln[] IS INITIAL AND
       s_aedat[] IS INITIAL AND
       s_pwerk[] IS INITIAL AND
       s_lifnr[] IS INITIAL AND
       s_pmatn[] IS INITIAL AND
       s_lprio[] IS INITIAL AND
       s_ekorg[] IS INITIAL AND
       s_eindt[] IS INITIAL.
      MESSAGE w208(00) WITH TEXT-w01.
    ENDIF.
  ELSEIF ( pa_prio IS NOT INITIAL OR pa_deld IS NOT INITIAL OR pa_deld IS NOT INITIAL ) AND
       pa_so IS NOT INITIAL.
    IF s_vbeln[] IS INITIAL AND
       s_vkorg[] IS INITIAL AND
       s_erdat[] IS INITIAL AND
       s_kunnr[] IS INITIAL AND
       s_kunwe[] IS INITIAL AND
       s_swerk[] IS INITIAL AND
       s_smatn[] IS INITIAL AND
       s_vdatu[] IS INITIAL.
      MESSAGE w208(00) WITH TEXT-w01.
    ENDIF.
  ENDIF.

  "  CASE sy-ucomm.
  "    WHEN 'FC01'.
  "      MESSAGE 'Rollback Mode: Please select a Run ID (Simulated)' TYPE 'I'.
  "      NEW lcl_mass_update( )->rollback( ).
  "  ENDCASE.

  " --- Start-of-Selection ---

START-OF-SELECTION.
  NEW lcl_mass_update( )->main( ).

  " --- Screen Modules ---
MODULE status_0100 OUTPUT.
  SET PF-STATUS 'STATUS_100'.
  SET TITLEBAR 'TITLE_100'.
  NEW lcl_mass_update( )->init_alv( ).
ENDMODULE.

MODULE user_command_0100 INPUT.
  CASE sy-ucomm.
    WHEN 'BACK' OR 'EXIT' OR 'CANCEL'.
      LEAVE TO SCREEN 0.
  ENDCASE.
ENDMODULE.
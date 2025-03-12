<DModal
  @title={{i18n "fullscreen_table.view_table"}}
  @closeModal={{@closeModal}}
  class="fullscreen-table-modal -max"
>
  <:body>
    {{@model.tableHtml}}
  </:body>
</DModal>
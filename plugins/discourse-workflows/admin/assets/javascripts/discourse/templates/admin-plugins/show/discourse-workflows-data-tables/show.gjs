import DataTableViewer from "discourse/plugins/discourse-workflows/admin/components/workflows/data-table/viewer";

export default <template>
  <div class="admin-config-page__main-area">
    <DataTableViewer @dataTableId={{@controller.model}} />
  </div>
</template>

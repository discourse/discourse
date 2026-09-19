import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import DataTableViewer from "discourse/plugins/discourse-workflows/admin/components/workflows/data-table/viewer";

export default <template>
  <div class="admin-config-page__main-area">
    <DBreadcrumbsItem
      @label={{i18n "discourse_workflows.tabs.data_tables"}}
      @path="/admin/plugins/discourse-workflows/data-tables"
    />
    <DataTableViewer @dataTableId={{@controller.model}} />
  </div>
</template>

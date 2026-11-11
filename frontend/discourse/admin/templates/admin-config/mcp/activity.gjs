import AdminMcp from "discourse/admin/components/admin-mcp";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "admin.config.mcp.tabs.activity"}}
    @path="/admin/config/mcp/activity"
  />
  <AdminMcp @model={{@model}} @section="activity" />
</template>

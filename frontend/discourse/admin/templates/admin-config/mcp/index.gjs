import AdminMcp from "discourse/admin/components/admin-mcp";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "admin.config.mcp.tabs.overview"}}
    @path="/admin/config/mcp"
  />
  <AdminMcp @model={{@model}} @section="overview" />
</template>

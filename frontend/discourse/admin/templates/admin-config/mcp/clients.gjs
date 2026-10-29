import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "admin.config.mcp.tabs.clients"}}
    @path="/admin/config/mcp/clients"
  />

  {{outlet}}
</template>

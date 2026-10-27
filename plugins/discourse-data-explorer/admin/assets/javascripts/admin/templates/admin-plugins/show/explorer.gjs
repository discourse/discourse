import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "explorer.queries"}}
    @path="/admin/plugins/discourse-data-explorer/queries"
  />
  {{outlet}}
</template>

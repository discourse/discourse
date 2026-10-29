import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "chat_integration.nav.providers"}}
    @path="/admin/plugins/discourse-chat-integration/providers"
  />

  <div id="admin-plugin-chat-integration">
    {{outlet}}
  </div>
</template>

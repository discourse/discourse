import htmlClass from "discourse/helpers/html-class";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import CredentialsManager from "discourse/plugins/discourse-workflows/admin/components/workflows/credential/manager";

export default <template>
  {{htmlClass "workflows-page"}}
  <div class="admin-config-page__main-area">
    <DBreadcrumbsItem @label={{i18n "discourse_workflows.tabs.credentials"}} />
    <CredentialsManager />
  </div>
</template>

import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import VersionsManager from "discourse/plugins/discourse-workflows/admin/components/workflows/version/manager";

export default <template>
  <DBreadcrumbsItem @label={{i18n "discourse_workflows.tabs.versions"}} />
  <VersionsManager @workflow={{@controller.model.workflow}} />
</template>

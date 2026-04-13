import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import WorkflowSettings from "discourse/plugins/discourse-workflows/admin/components/workflows/settings";

export default <template>
  <DBreadcrumbsItem @label={{i18n "discourse_workflows.tabs.settings"}} />
  <WorkflowSettings @workflow={{@controller.model.workflow}} />
</template>

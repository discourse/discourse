import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import ExecutionsManager from "discourse/plugins/discourse-workflows/admin/components/workflows/execution/manager";

export default <template>
  <DBreadcrumbsItem @label={{i18n "discourse_workflows.tabs.executions"}} />
  <ExecutionsManager @workflowId={{@controller.model.workflow.id}} />
</template>

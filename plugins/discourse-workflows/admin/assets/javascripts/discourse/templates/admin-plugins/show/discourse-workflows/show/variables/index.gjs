import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import WorkflowVariables from "discourse/plugins/discourse-workflows/admin/components/workflows/variables";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "discourse_workflows.tabs.workflow_variables"}}
  />
  <WorkflowVariables @workflow={{@controller.model.workflow}} />
</template>

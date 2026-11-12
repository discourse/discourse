import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import ExecutionDetail from "discourse/plugins/discourse-workflows/admin/components/workflows/executions/detail";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "discourse_workflows.tabs.executions"}}
    @path="/admin/plugins/discourse-workflows/workflows/{{@controller.model.workflow_id}}/executions"
  />
  <DBreadcrumbsItem @label="#{{@controller.model.id}}" />
  <ExecutionDetail @execution={{@controller.model}} />
</template>

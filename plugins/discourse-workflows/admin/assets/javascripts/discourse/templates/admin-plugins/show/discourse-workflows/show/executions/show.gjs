import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import ExecutionDetail from "discourse/plugins/discourse-workflows/admin/components/workflows/executions/detail";

export default <template>
  <DBreadcrumbsItem
    @path="/admin/plugins/discourse-workflows/{{@controller.model.workflow_id}}/executions"
    @label={{i18n "discourse_workflows.tabs.executions"}}
  />
  <DBreadcrumbsItem @label="#{{@controller.model.id}}" />
  <ExecutionDetail @execution={{@controller.model}} />
</template>

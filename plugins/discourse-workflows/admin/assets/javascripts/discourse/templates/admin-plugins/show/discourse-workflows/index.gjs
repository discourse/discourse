import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import WorkflowsIndex from "discourse/plugins/discourse-workflows/admin/components/workflows/index";

export default <template>
  <div class="admin-config-page__main-area">
    <DBreadcrumbsItem
      @label={{i18n "discourse_workflows.tabs.all_workflows"}}
    />
    <WorkflowsIndex
      @workflows={{@controller.model.workflows}}
      @stats={{@controller.model.stats}}
    />
  </div>
</template>

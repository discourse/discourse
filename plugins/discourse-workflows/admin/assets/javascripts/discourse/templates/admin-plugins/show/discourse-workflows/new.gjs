import htmlClass from "discourse/helpers/html-class";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import WorkflowsEditor from "discourse/plugins/discourse-workflows/admin/components/workflows/editor";

export default <template>
  {{htmlClass "workflows-page"}}
  <DBreadcrumbsItem @label={{i18n "discourse_workflows.new_workflow"}} />

  <div class="admin-config-page__main-area">
    <WorkflowsEditor @workflow={{@controller.model}} @isNew={{true}} />
  </div>
</template>

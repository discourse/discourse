import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import TestsManager from "discourse/plugins/discourse-workflows/admin/components/workflows/workflow-tests/manager";

export default <template>
  <DBreadcrumbsItem @label={{i18n "discourse_workflows.tabs.tests"}} />
  <TestsManager @workflow={{@controller.model.workflow}} />
</template>

import BackButton from "discourse/components/back-button";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";
import TestEditor from "discourse/plugins/discourse-workflows/admin/components/workflows/workflow-tests/editor";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "discourse_workflows.tabs.tests"}}
    @path="/admin/plugins/discourse-workflows/workflows/{{@controller.model.workflow.id}}/tests"
  />

  <BackButton
    @label="discourse_workflows.tests.back_to_tests"
    @route="adminPlugins.show.discourse-workflows.show.workflow-tests.index"
  />

  <TestEditor
    @testId={{@controller.model.testId}}
    @workflow={{@controller.model.workflow}}
  />
</template>

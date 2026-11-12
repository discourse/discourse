import BackButton from "discourse/components/back-button";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import WorkflowVariableDefinitions from "discourse/plugins/discourse-workflows/admin/components/workflows/variable-definitions";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "discourse_workflows.tabs.workflow_variables"}}
    @path="/admin/plugins/discourse-workflows/workflows/{{@controller.model.workflow.id}}/variables"
  />
  <DBreadcrumbsItem
    @label={{i18n "discourse_workflows.workflow_variables.manage_variables"}}
  />

  <BackButton
    @label="discourse_workflows.workflow_variables.back"
    @route="adminPlugins.show.discourse-workflows.show.variables"
  />

  <DPageSubheader
    @descriptionLabel={{i18n
      "discourse_workflows.workflow_variables.definitions_description"
    }}
    @titleLabel={{i18n
      "discourse_workflows.workflow_variables.manage_variables"
    }}
  />

  <WorkflowVariableDefinitions @workflow={{@controller.model.workflow}} />
</template>

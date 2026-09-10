import BackButton from "discourse/components/back-button";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import { i18n } from "discourse-i18n";
import WorkflowSettingFieldDefinitions from "discourse/plugins/discourse-workflows/admin/components/workflows/setting-field-definitions";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "discourse_workflows.tabs.settings"}}
    @path="/admin/plugins/discourse-workflows/workflows/{{@controller.model.workflow.id}}/settings"
  />
  <DBreadcrumbsItem
    @label={{i18n "discourse_workflows.settings.fields.manage_fields"}}
  />

  <BackButton
    @label="discourse_workflows.settings.fields.back"
    @route="adminPlugins.show.discourse-workflows.show.settings"
  />

  <DPageSubheader
    @descriptionLabel={{i18n
      "discourse_workflows.settings.fields.definitions_description"
    }}
    @titleLabel={{i18n "discourse_workflows.settings.fields.manage_fields"}}
  />

  <WorkflowSettingFieldDefinitions @workflow={{@controller.model.workflow}} />
</template>

import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import WorkflowSettingFieldForm from "discourse/plugins/discourse-workflows/admin/components/workflows/setting-field-edit-form";

export default <template>
  <BackButton
    @label="discourse_workflows.settings.fields.back_to_fields"
    @route="adminPlugins.show.discourse-workflows.show.settings.fields"
  />

  <AdminConfigAreaCard
    @heading="discourse_workflows.settings.fields.edit_field"
  >
    <:content>
      <WorkflowSettingFieldForm
        @fieldId={{@controller.model.settingFieldId}}
        @workflow={{@controller.model.workflow}}
      />
    </:content>
  </AdminConfigAreaCard>
</template>

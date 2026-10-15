import AdminConfigAreaCard from "discourse/admin/components/admin-config-area-card";
import BackButton from "discourse/components/back-button";
import WorkflowVariableForm from "discourse/plugins/discourse-workflows/admin/components/workflows/variable-edit-form";

export default <template>
  <BackButton
    @label="discourse_workflows.workflow_variables.back_to_manage"
    @route="adminPlugins.show.discourse-workflows.show.variables.manage"
  />

  <AdminConfigAreaCard
    @heading="discourse_workflows.workflow_variables.edit_variable"
  >
    <:content>
      <WorkflowVariableForm
        @variableId={{@controller.model.variableId}}
        @workflow={{@controller.model.workflow}}
      />
    </:content>
  </AdminConfigAreaCard>
</template>

import WorkflowsEditor from "discourse/plugins/discourse-workflows/admin/components/workflows/editor";

export default <template>
  <WorkflowsEditor
    @initialNodeId={{@controller.model.initialNodeId}}
    @workflow={{@controller.model.workflow}}
  />
</template>

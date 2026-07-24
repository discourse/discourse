import WorkflowsEditor from "discourse/plugins/discourse-workflows/admin/components/workflows/editor";

export default <template>
  <WorkflowsEditor @workflow={{@controller.model.workflow}} />
</template>

import WorkflowsChatLaunch from "../components/workflows-chat-launch.gjs";

export default <template>
  <WorkflowsChatLaunch
    @nodeId={{@model.nodeId}}
    @workflowId={{@model.workflowId}}
  />
</template>

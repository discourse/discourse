import AiAgentListEditor from "../../../../components/ai-agent-list-editor.gjs";

export default <template>
  <AiAgentListEditor
    @agents={{@controller.allAgents}}
    @currentAgent={{@controller.model}}
  />
</template>

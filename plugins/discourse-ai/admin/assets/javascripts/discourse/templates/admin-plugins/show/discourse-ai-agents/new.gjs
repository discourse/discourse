import AiAgentListEditor from "../../../../components/ai-agent-list-editor";

export default <template>
  <AiAgentListEditor
    @agents={{@controller.allAgents}}
    @currentAgent={{@controller.model}}
  />
</template>

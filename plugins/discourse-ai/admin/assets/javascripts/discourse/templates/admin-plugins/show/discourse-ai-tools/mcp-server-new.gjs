import AiMcpServerEditor from "../../../../../discourse/components/ai-mcp-server-editor";

export default <template>
  <section class="ai-agent-tool-editor__current admin-detail pull-left">
    <AiMcpServerEditor
      @mcpServers={{@controller.allMcpServers}}
      @model={{@controller.model}}
      @secrets={{@controller.secrets}}
    />
  </section>
</template>

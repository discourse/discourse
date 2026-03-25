import BackButton from "discourse/components/back-button";
import AiMcpServerEditorForm from "./ai-mcp-server-editor-form";

const AiMcpServerEditor = <template>
  <BackButton
    @route="adminPlugins.show.discourse-ai-tools"
    @label="discourse_ai.mcp_servers.back"
  />

  <AiMcpServerEditorForm
    @model={{@model}}
    @mcpServers={{@mcpServers}}
    @secrets={{@secrets}}
  />
</template>;

export default AiMcpServerEditor;

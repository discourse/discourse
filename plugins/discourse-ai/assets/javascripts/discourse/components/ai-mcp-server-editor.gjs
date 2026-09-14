import BackButton from "discourse/components/back-button";
import AiMcpServerEditorForm from "./ai-mcp-server-editor-form";

const AiMcpServerEditor = <template>
  <BackButton
    @label="discourse_ai.mcp_servers.back"
    @route="adminPlugins.show.discourse-ai-tools"
  />

  <AiMcpServerEditorForm
    @mcpServers={{@mcpServers}}
    @model={{@model}}
    @secrets={{@secrets}}
  />
</template>;

export default AiMcpServerEditor;

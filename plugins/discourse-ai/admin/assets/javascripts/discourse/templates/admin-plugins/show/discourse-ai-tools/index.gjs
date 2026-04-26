import AiToolListEditor from "../../../../components/ai-tool-list-editor";

export default <template>
  <AiToolListEditor
    @tools={{@controller.model.tools}}
    @mcpServers={{@controller.model.mcpServers}}
  />
</template>

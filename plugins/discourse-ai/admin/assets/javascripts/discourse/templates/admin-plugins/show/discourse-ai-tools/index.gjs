import AiToolListEditor from "../../../../components/ai-tool-list-editor";

export default <template>
  <AiToolListEditor
    @mcpServers={{@controller.model.mcpServers}}
    @tools={{@controller.model.tools}}
  />
</template>

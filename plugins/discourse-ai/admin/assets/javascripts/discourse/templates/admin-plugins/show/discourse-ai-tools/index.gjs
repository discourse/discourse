import AiToolListEditor from "discourse/plugins/discourse-ai/discourse/components/ai-tool-list-editor";

export default <template>
  <AiToolListEditor @tools={{@controller.model}} />
</template>

import AiLlmsListEditor from "discourse/plugins/discourse-ai/discourse/components/ai-llms-list-editor";

export default <template>
  <AiLlmsListEditor @llms={{@controller.model}} />
</template>

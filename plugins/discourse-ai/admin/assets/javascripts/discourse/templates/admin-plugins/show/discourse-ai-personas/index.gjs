import AiPersonaListEditor from "discourse/plugins/discourse-ai/discourse/components/ai-persona-list-editor";

export default <template>
  <AiPersonaListEditor @personas={{@controller.model}} />
</template>

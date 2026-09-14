import BackButton from "discourse/components/back-button";
import AiLlmEditorForm from "./ai-llm-editor-form";

const AiLlmEditor = <template>
  <BackButton
    @label="discourse_ai.llms.back"
    @route="adminPlugins.show.discourse-ai-llms"
  />
  <AiLlmEditorForm
    @llms={{@llms}}
    @llmTemplate={{@llmTemplate}}
    @model={{@model}}
  />
</template>;

export default AiLlmEditor;

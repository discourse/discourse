import BackButton from "discourse/components/back-button";
import AiLlmEditorForm from "./ai-llm-editor-form";

const AiLlmEditor = <template>
  <BackButton
    @route="adminPlugins.show.discourse-ai-llms"
    @label="discourse_ai.llms.back"
  />
  <AiLlmEditorForm
    @model={{@model}}
    @llmTemplate={{@llmTemplate}}
    @llms={{@llms}}
  />
</template>;

export default AiLlmEditor;

import BackButton from "discourse/components/back-button";
import AiLlmEditorForm from "./ai-llm-editor-form.gjs";

const AiLlmEditor = <template>
  <BackButton
    @label="discourse_ai.models.back"
    @route="adminPlugins.show.discourse-ai-models"
  />
  <AiLlmEditorForm
    @llms={{@llms}}
    @llmTemplate={{@llmTemplate}}
    @model={{@model}}
  />
</template>;

export default AiLlmEditor;

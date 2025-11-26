import DPageSubheader from "discourse/components/d-page-subheader";
import { i18n } from "discourse-i18n";
import AiLlmEditorForm from "./ai-llm-editor-form";

const AiLlmEditor = <template>
  <DPageSubheader @titleLabel={{i18n "discourse_ai.llms.edit_llm"}} />
  <AiLlmEditorForm
    @model={{@model}}
    @llmTemplate={{@llmTemplate}}
    @llms={{@llms}}
  />
</template>;

export default AiLlmEditor;

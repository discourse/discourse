import RouteTemplate from "ember-route-template";
import AiLlmsListEditor from "../../../../../discourse/components/ai-llms-list-editor";

export default RouteTemplate(
  <template>
    <AiLlmsListEditor
      @llms={{@controller.allLlms}}
      @currentLlm={{@controller.model}}
      @llmTemplate={{@controller.llmTemplate}}
    />
  </template>
);

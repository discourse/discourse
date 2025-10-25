import RouteTemplate from "ember-route-template";
import AiToolListEditor from "discourse/plugins/discourse-ai/discourse/components/ai-tool-list-editor";

export default RouteTemplate(
  <template><AiToolListEditor @tools={{@controller.model}} /></template>
);

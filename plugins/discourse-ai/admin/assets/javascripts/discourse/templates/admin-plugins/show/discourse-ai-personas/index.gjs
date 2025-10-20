import RouteTemplate from "ember-route-template";
import AiPersonaListEditor from "discourse/plugins/discourse-ai/discourse/components/ai-persona-list-editor";

export default RouteTemplate(
  <template><AiPersonaListEditor @personas={{@controller.model}} /></template>
);

import RouteTemplate from "ember-route-template";
import AiSpam from "discourse/plugins/discourse-ai/discourse/components/ai-spam";

export default RouteTemplate(
  <template><AiSpam @model={{@controller.model}} /></template>
);

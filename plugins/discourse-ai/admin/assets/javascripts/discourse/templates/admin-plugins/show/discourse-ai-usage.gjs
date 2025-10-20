import RouteTemplate from "ember-route-template";
import AiUsage from "discourse/plugins/discourse-ai/discourse/components/ai-usage";

export default RouteTemplate(
  <template><AiUsage @model={{@controller.model}} /></template>
);

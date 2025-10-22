import RouteTemplate from "ember-route-template";
import AiSpam from "../../../../discourse/components/ai-spam";

export default RouteTemplate(
  <template><AiSpam @model={{@controller.model}} /></template>
);

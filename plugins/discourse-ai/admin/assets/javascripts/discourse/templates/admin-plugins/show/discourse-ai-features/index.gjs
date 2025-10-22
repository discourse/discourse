import RouteTemplate from "ember-route-template";
import AiFeatures from "../../../../../discourse/components/ai-features";

export default RouteTemplate(
  <template><AiFeatures @features={{@controller.model}} /></template>
);

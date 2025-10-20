import RouteTemplate from "ember-route-template";
import AiTranslations from "discourse/plugins/discourse-ai/discourse/components/ai-translations";

export default RouteTemplate(
  <template><AiTranslations @model={{@controller.model}} /></template>
);

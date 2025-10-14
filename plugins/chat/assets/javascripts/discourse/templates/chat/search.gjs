import RouteTemplate from "ember-route-template";
import Search from "discourse/plugins/chat/discourse/components/chat/routes/search";

export default RouteTemplate(
  <template><Search @query={{@controller.q}} /></template>
);

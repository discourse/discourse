import RouteTemplate from "ember-route-template";
import UserStream from "discourse/components/user-stream";

export default RouteTemplate(
  <template><UserStream @stream={{@controller.model}} /></template>
);

import RouteTemplate from "ember-route-template";
import ApiKeysShow from "admin/components/admin-config-areas/api-keys-show";

export default RouteTemplate(
  <template><ApiKeysShow @apiKey={{@controller.model}} /></template>
);

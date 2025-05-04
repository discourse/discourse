import RouteTemplate from "ember-route-template";
import ApiKeysList from "admin/components/admin-config-areas/api-keys-list";

export default RouteTemplate(
  <template><ApiKeysList @apiKeys={{@controller.model}} /></template>
);

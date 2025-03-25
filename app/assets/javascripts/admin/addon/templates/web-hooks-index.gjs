import RouteTemplate from "ember-route-template";
import WebhooksList from "admin/components/admin-config-areas/webhooks-list";

export default RouteTemplate(
  <template><WebhooksList @webhooks={{@controller.model}} /></template>
);

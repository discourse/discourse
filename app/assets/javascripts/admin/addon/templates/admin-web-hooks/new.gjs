import RouteTemplate from "ember-route-template";
import WebhooksForm from "admin/components/admin-config-areas/webhooks-form";

export default RouteTemplate(
  <template><WebhooksForm @webhook={{@controller.model}} /></template>
);

import RouteTemplate from "ember-route-template";
import UserFieldsList from "admin/components/admin-config-areas/user-fields-list";

export default RouteTemplate(
  <template><UserFieldsList @userFields={{@controller.model}} /></template>
);

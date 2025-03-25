import RouteTemplate from "ember-route-template";
import AdminPermalinkForm from "admin/components/admin-permalink-form";

export default RouteTemplate(
  <template><AdminPermalinkForm @permalink={{@controller.model}} /></template>
);

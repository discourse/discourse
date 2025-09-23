import RouteTemplate from "ember-route-template";
import AdminFlagsForm from "admin/components/admin-flags-form";

export default RouteTemplate(
  <template><AdminFlagsForm @flag={{@model}} /></template>
);

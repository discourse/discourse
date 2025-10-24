import RouteTemplate from "ember-route-template";
import AdminBadgesShow from "admin/components/admin-badges-show";

export default RouteTemplate(
  <template>
    <AdminBadgesShow @controller={{@controller}} @badge={{@model}} />
  </template>
);

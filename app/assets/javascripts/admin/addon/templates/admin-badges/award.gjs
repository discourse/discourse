import RouteTemplate from "ember-route-template";
import AdminBadgesAward from "admin/components/admin-badges-award";

export default RouteTemplate(
  <template>
    <AdminBadgesAward @controller={{@controller}} @badge={{@model}} />
  </template>
);

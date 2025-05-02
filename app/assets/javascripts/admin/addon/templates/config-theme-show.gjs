import RouteTemplate from "ember-route-template";
import AdminConfigAreasTheme from "admin/components/admin-config-areas/theme";

export default RouteTemplate(
  <template><AdminConfigAreasTheme @theme={{@model}} /></template>
);

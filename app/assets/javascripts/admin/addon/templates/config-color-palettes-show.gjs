import RouteTemplate from "ember-route-template";
import ColorPalette from "admin/components/admin-config-areas/color-palette";

export default RouteTemplate(
  <template><ColorPalette @colorPalette={{@model}} /></template>
);

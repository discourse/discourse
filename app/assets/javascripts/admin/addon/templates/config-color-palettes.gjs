import RouteTemplate from "ember-route-template";
import ColorPalettes from "admin/components/admin-config-areas/color-palettes";

export default RouteTemplate(
  <template><ColorPalettes @palettes={{@model.content}} /></template>
);

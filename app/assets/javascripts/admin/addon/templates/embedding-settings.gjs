import RouteTemplate from "ember-route-template";
import AdminAreaSettings from "admin/components/admin-area-settings";

export default RouteTemplate(
  <template>
    <AdminAreaSettings
      @area="embedding"
      @path="/admin/customize/embedding/settings"
      @filter={{@controller.filter}}
      @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    />
  </template>
);

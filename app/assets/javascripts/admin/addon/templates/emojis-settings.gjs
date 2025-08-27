import RouteTemplate from "ember-route-template";
import AdminAreaSettings from "admin/components/admin-area-settings";

export default RouteTemplate(
  <template>
    <AdminAreaSettings
      @area="emojis"
      @path="/admin/config/emoji/settings"
      @filter={{@controller.filter}}
      @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
    />
  </template>
);

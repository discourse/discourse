import RouteTemplate from "ember-route-template";
import AdminAreaSettings from "admin/components/admin-area-settings";

export default RouteTemplate(
  <template>
    <div
      class="content-body admin-plugin-config-area__settings admin-detail pull-left"
    >
      <AdminAreaSettings
        @plugin={{@model.plugin.id}}
        @path="/admin/plugins/{{@model.plugin.name}}/settings"
        @filter={{@controller.filter}}
        @adminSettingsFilterChangedCallback={{@controller.adminSettingsFilterChangedCallback}}
      />
    </div>
  </template>
);
